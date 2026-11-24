-- Phase 6: moderation enforcement. Run last.
create function is_active() returns boolean language sql stable security definer as $$
  select not exists (select 1 from profiles where id = auth.uid() and (banned or (suspended_until is not null and suspended_until > now())))
$$;
drop policy "create own posts" on posts;
create policy "create own posts" on posts for insert with check (author_id = auth.uid() and is_active());
drop policy "comment as self" on comments;
create policy "comment as self" on comments for insert with check (author_id = auth.uid() and is_active());
drop policy "send messages" on messages;
create policy "send messages" on messages for insert with check (sender_id = auth.uid() and is_active() and exists
  (select 1 from conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = auth.uid()));

-- Only admins may change moderation fields
create function guard_profile_update() returns trigger language plpgsql security definer as $$
begin
  if not is_admin() then new.role := old.role; new.banned := old.banned; new.suspended_until := old.suspended_until; end if;
  return new;
end $$;
create trigger t_guard_profile before update on profiles for each row execute function guard_profile_update();
create function guard_post_update() returns trigger language plpgsql security definer as $$
begin if not is_admin() then new.removed := old.removed; end if; return new; end $$;
create trigger t_guard_post before update on posts for each row execute function guard_post_update();

-- Make yourself admin (replace the username):
-- update profiles set role = 'admin' where username = 'yourname';
