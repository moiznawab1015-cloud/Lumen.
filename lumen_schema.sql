-- LUMEN: Phase 1 database schema (Supabase / PostgreSQL)
-- Run in the Supabase SQL editor. Counters are computed from real rows via views.

create extension if not exists pg_trgm;

create type user_role as enum ('user','admin');
create type media_kind as enum ('photo','video');
create type notif_kind as enum ('like','comment','reply','follow','mention','message');
create type report_status as enum ('open','reviewed','dismissed','actioned');

-- PROFILES (1:1 with auth.users; passwords are hashed by Supabase Auth)
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_.]{3,30}$'),
  full_name text, bio text check (char_length(bio) <= 150),
  website text, avatar_url text,
  is_private boolean not null default false,
  role user_role not null default 'user',
  suspended_until timestamptz, banned boolean not null default false,
  created_at timestamptz not null default now()
);
create index on profiles using gin (username gin_trgm_ops);

-- POSTS (photo posts and reels share a table; reels are video with duration <= 60s)
create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles on delete cascade,
  kind media_kind not null,
  is_reel boolean not null default false,
  media_url text not null, thumb_url text,
  duration_s numeric check (duration_s is null or duration_s <= 60),
  filter_preset text, trim_start numeric, trim_end numeric,
  audio_url text, audio_volume numeric default 1,
  caption text, removed boolean not null default false,
  created_at timestamptz not null default now(),
  check (not is_reel or (kind = 'video' and duration_s is not null))
);
create index on posts (author_id, created_at desc);
create index on posts (is_reel, created_at desc);

create table hashtags (id serial primary key, tag text unique not null);
create table post_hashtags (
  post_id uuid references posts on delete cascade,
  hashtag_id int references hashtags on delete cascade,
  primary key (post_id, hashtag_id)
);

-- SOCIAL GRAPH
create table follows (
  follower_id uuid references profiles on delete cascade,
  followee_id uuid references profiles on delete cascade,
  status text not null default 'accepted' check (status in ('pending','accepted')),
  created_at timestamptz default now(),
  primary key (follower_id, followee_id), check (follower_id <> followee_id)
);
create table blocks (
  blocker_id uuid references profiles on delete cascade,
  blocked_id uuid references profiles on delete cascade,
  primary key (blocker_id, blocked_id)
);
create table likes (
  user_id uuid references profiles on delete cascade,
  post_id uuid references posts on delete cascade,
  created_at timestamptz default now(), primary key (user_id, post_id)
);
create table saves (
  user_id uuid references profiles on delete cascade,
  post_id uuid references posts on delete cascade,
  collection text not null default 'All',
  created_at timestamptz default now(), primary key (user_id, post_id)
);
create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts on delete cascade,
  author_id uuid not null references profiles on delete cascade,
  parent_id uuid references comments on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz default now()
);
create table comment_likes (
  user_id uuid references profiles on delete cascade,
  comment_id uuid references comments on delete cascade,
  primary key (user_id, comment_id)
);
create table post_views (
  id bigserial primary key,
  post_id uuid not null references posts on delete cascade,
  viewer_id uuid references profiles on delete set null,
  watched_s numeric, created_at timestamptz default now()
);
create index on post_views (post_id);

-- STORIES (24h)
create table stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles on delete cascade,
  kind media_kind not null, media_url text not null,
  created_at timestamptz default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);

-- MESSAGING
create table conversations (id uuid primary key default gen_random_uuid(), created_at timestamptz default now());
create table conversation_members (
  conversation_id uuid references conversations on delete cascade,
  user_id uuid references profiles on delete cascade,
  last_read_at timestamptz default now(),
  primary key (conversation_id, user_id)
);
create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations on delete cascade,
  sender_id uuid not null references profiles on delete cascade,
  body text, image_url text, shared_post_id uuid references posts,
  created_at timestamptz default now(),
  check (body is not null or image_url is not null or shared_post_id is not null)
);
create index on messages (conversation_id, created_at);

-- NOTIFICATIONS and REPORTS
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles on delete cascade,
  actor_id uuid not null references profiles on delete cascade,
  kind notif_kind not null,
  post_id uuid references posts on delete cascade,
  comment_id uuid references comments on delete cascade,
  read boolean not null default false, created_at timestamptz default now()
);
create index on notifications (recipient_id, created_at desc);
create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles on delete cascade,
  post_id uuid references posts on delete cascade,
  comment_id uuid references comments on delete cascade,
  reported_user_id uuid references profiles on delete cascade,
  reason text not null, status report_status not null default 'open',
  created_at timestamptz default now()
);

-- COUNTER VIEWS (always derived from real rows)
create view post_stats as
select p.id as post_id,
  (select count(*) from likes l where l.post_id = p.id) as like_count,
  (select count(*) from comments c where c.post_id = p.id) as comment_count,
  (select count(*) from post_views v where v.post_id = p.id) as view_count
from posts p;

create view profile_stats as
select pr.id as user_id,
  (select count(*) from follows f where f.followee_id = pr.id and f.status='accepted') as followers,
  (select count(*) from follows f where f.follower_id = pr.id and f.status='accepted') as following,
  (select count(*) from posts p where p.author_id = pr.id and not p.removed) as posts,
  (select count(*) from likes l join posts p on p.id = l.post_id where p.author_id = pr.id) as likes_received
from profiles pr;

-- HELPERS
create function is_admin() returns boolean language sql stable security definer as
$$ select exists (select 1 from profiles where id = auth.uid() and role = 'admin') $$;

create function can_view_author(a uuid) returns boolean language sql stable security definer as $$
  select not exists (select 1 from blocks b where (b.blocker_id = a and b.blocked_id = auth.uid())
                                              or (b.blocker_id = auth.uid() and b.blocked_id = a))
  and ( a = auth.uid()
     or not (select is_private from profiles where id = a)
     or exists (select 1 from follows f where f.follower_id = auth.uid() and f.followee_id = a and f.status='accepted'))
$$;

-- Auto-create profile on signup
create function handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, username, full_name)
  values (new.id, lower(coalesce(new.raw_user_meta_data->>'username', 'user'||substr(new.id::text,1,8))),
          new.raw_user_meta_data->>'full_name');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Notification triggers
create function notify_like() returns trigger language plpgsql security definer as $$
begin
  insert into notifications (recipient_id, actor_id, kind, post_id)
  select author_id, new.user_id, 'like', new.post_id from posts
  where id = new.post_id and author_id <> new.user_id;
  return new;
end $$;
create trigger t_like after insert on likes for each row execute function notify_like();

create function notify_comment() returns trigger language plpgsql security definer as $$
begin
  insert into notifications (recipient_id, actor_id, kind, post_id, comment_id)
  select p.author_id, new.author_id, case when new.parent_id is null then 'comment' else 'reply' end::notif_kind,
         new.post_id, new.id
  from posts p where p.id = new.post_id and p.author_id <> new.author_id;
  return new;
end $$;
create trigger t_comment after insert on comments for each row execute function notify_comment();

create function notify_follow() returns trigger language plpgsql security definer as $$
begin
  insert into notifications (recipient_id, actor_id, kind) values (new.followee_id, new.follower_id, 'follow');
  return new;
end $$;
create trigger t_follow after insert on follows for each row execute function notify_follow();

-- Private accounts: follows start as pending
create function set_follow_status() returns trigger language plpgsql security definer as $$
begin
  if (select is_private from profiles where id = new.followee_id) then new.status := 'pending';
  else new.status := 'accepted'; end if;
  return new;
end $$;
create trigger t_follow_status before insert on follows for each row execute function set_follow_status();

-- ROW LEVEL SECURITY
alter table profiles enable row level security;
alter table posts enable row level security;
alter table follows enable row level security;
alter table blocks enable row level security;
alter table likes enable row level security;
alter table saves enable row level security;
alter table comments enable row level security;
alter table comment_likes enable row level security;
alter table post_views enable row level security;
alter table stories enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
alter table reports enable row level security;

create policy "profiles readable" on profiles for select using (true);
create policy "edit own profile" on profiles for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid()));
create policy "admin manages profiles" on profiles for update using (is_admin());

create policy "view posts" on posts for select
  using ((not removed and can_view_author(author_id)) or is_admin());
create policy "create own posts" on posts for insert with check (author_id = auth.uid());
create policy "edit own posts" on posts for update using (author_id = auth.uid() or is_admin());
create policy "delete own posts" on posts for delete using (author_id = auth.uid() or is_admin());

create policy "see own follows" on follows for select
  using (follower_id = auth.uid() or followee_id = auth.uid() or
         (status = 'accepted' and can_view_author(followee_id)));
create policy "follow as self" on follows for insert with check (follower_id = auth.uid());
create policy "unfollow or manage requests" on follows for delete
  using (follower_id = auth.uid() or followee_id = auth.uid());
create policy "approve requests" on follows for update using (followee_id = auth.uid());

create policy "own blocks" on blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy "read likes" on likes for select using (true);
create policy "like as self" on likes for insert with check (user_id = auth.uid());
create policy "unlike" on likes for delete using (user_id = auth.uid());

create policy "own saves (private)" on saves for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "read comments" on comments for select
  using (exists (select 1 from posts p where p.id = post_id));  -- inherits post visibility via posts RLS
create policy "comment as self" on comments for insert with check (author_id = auth.uid());
create policy "delete comment" on comments for delete
  using (author_id = auth.uid() or is_admin()
         or exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));

create policy "own comment likes" on comment_likes for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "record view" on post_views for insert with check (viewer_id = auth.uid());
create policy "admin reads views" on post_views for select using (is_admin());

create policy "view live stories" on stories for select using (expires_at > now() and can_view_author(author_id));
create policy "own stories" on stories for insert with check (author_id = auth.uid());
create policy "delete own stories" on stories for delete using (author_id = auth.uid());

create policy "members see conversations" on conversations for select
  using (exists (select 1 from conversation_members m where m.conversation_id = id and m.user_id = auth.uid()));
create policy "members see members" on conversation_members for select
  using (user_id = auth.uid() or exists (select 1 from conversation_members m
         where m.conversation_id = conversation_members.conversation_id and m.user_id = auth.uid()));
create policy "update own read marker" on conversation_members for update using (user_id = auth.uid());
create policy "read messages" on messages for select
  using (exists (select 1 from conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = auth.uid()));
create policy "send messages" on messages for insert
  with check (sender_id = auth.uid() and exists (select 1 from conversation_members m
              where m.conversation_id = messages.conversation_id and m.user_id = auth.uid()));

create policy "own notifications" on notifications for select using (recipient_id = auth.uid());
create policy "mark read" on notifications for update using (recipient_id = auth.uid());

create policy "file report" on reports for insert with check (reporter_id = auth.uid());
create policy "admin reads reports" on reports for select using (is_admin());
create policy "admin updates reports" on reports for update using (is_admin());

-- STORAGE (public-read buckets; users write only into their own folder)
insert into storage.buckets (id, name, public) values
  ('avatars','avatars',true), ('media','media',true), ('dm-images','dm-images',false)
on conflict do nothing;
create policy "upload to own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','media','dm-images') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "public read media" on storage.objects for select using (bucket_id in ('avatars','media'));

-- REALTIME (live notifications, messages, counters)
alter publication supabase_realtime add table notifications, messages, likes, comments;
