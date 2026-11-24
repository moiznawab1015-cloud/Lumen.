-- Phase 5: trending views, start_conversation RPC, message notifications
create view trending_posts with (security_invoker = true) as
  select p.*, (s.like_count*3 + s.comment_count*2 + s.view_count) as score
  from posts p join post_stats s on s.post_id = p.id
  where not p.removed and p.created_at > now() - interval '14 days';
create view trending_tags with (security_invoker = true) as
  select h.tag, count(*) as uses from hashtags h
  join post_hashtags ph on ph.hashtag_id = h.id join posts p on p.id = ph.post_id
  where not p.removed and p.created_at > now() - interval '14 days' group by h.tag;

create function start_conversation(other uuid) returns uuid language plpgsql security definer as $$
declare cid uuid; me uuid := auth.uid();
begin
  if me is null or other = me then raise exception 'invalid'; end if;
  if exists (select 1 from blocks where (blocker_id = me and blocked_id = other) or (blocker_id = other and blocked_id = me)) then raise exception 'blocked'; end if;
  select a.conversation_id into cid from conversation_members a join conversation_members b on a.conversation_id = b.conversation_id
    where a.user_id = me and b.user_id = other limit 1;
  if cid is null then
    insert into conversations default values returning id into cid;
    insert into conversation_members (conversation_id, user_id) values (cid, me), (cid, other);
  end if;
  return cid;
end $$;

create function notify_message() returns trigger language plpgsql security definer as $$
begin
  insert into notifications (recipient_id, actor_id, kind)
  select m.user_id, new.sender_id, 'message' from conversation_members m
  where m.conversation_id = new.conversation_id and m.user_id <> new.sender_id
    and not exists (select 1 from notifications n where n.recipient_id = m.user_id and n.actor_id = new.sender_id and n.kind = 'message' and not n.read);
  return new;
end $$;
create trigger t_message after insert on messages for each row execute function notify_message();
