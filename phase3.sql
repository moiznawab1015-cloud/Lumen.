-- Phase 3 migration: tag security + @mention notifications
alter table hashtags enable row level security; alter table post_hashtags enable row level security;
create policy "read tags" on hashtags for select using (true);
create policy "add tags" on hashtags for insert to authenticated with check (true);
create policy "read post tags" on post_hashtags for select using (true);
create policy "tag own posts" on post_hashtags for insert
  with check (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));

create function notify_mentions() returns trigger language plpgsql security definer as $$
declare txt text; pid uuid; cid uuid;
begin
  if tg_table_name = 'posts' then txt := new.caption; pid := new.id; cid := null;
  else txt := new.body; pid := new.post_id; cid := new.id; end if;
  insert into notifications (recipient_id, actor_id, kind, post_id, comment_id)
  select distinct p.id, new.author_id, 'mention', pid, cid
  from regexp_matches(coalesce(txt,''), '@([a-z0-9_.]{3,30})', 'g') as m(g)
  join profiles p on p.username = m.g[1] where p.id <> new.author_id;
  return new;
end $$;
create trigger t_mention_post after insert on posts for each row execute function notify_mentions();
create trigger t_mention_comment after insert on comments for each row execute function notify_mentions();
