import type { SupabaseClient } from "@supabase/supabase-js";
export async function loadConversations(db: SupabaseClient, me: string) {
  const { data: mem } = await db.from("conversation_members").select("conversation_id,last_read_at").eq("user_id", me);
  const ids = (mem ?? []).map(m => m.conversation_id); if (!ids.length) return [];
  const [{ data: others }, { data: msgs }] = await Promise.all([
    db.from("conversation_members").select("conversation_id, profiles(id,username,avatar_url)").in("conversation_id", ids).neq("user_id", me),
    db.from("messages").select("conversation_id,sender_id,body,image_url,shared_post_id,created_at").in("conversation_id", ids).order("created_at", { ascending: false }).limit(300)]);
  const read = new Map((mem ?? []).map(m => [m.conversation_id, m.last_read_at]));
  return ids.map(id => { const m = (msgs ?? []).filter(x => x.conversation_id === id);
    return { id, other: (others ?? []).find(o => o.conversation_id === id)?.profiles as any, last: m[0] as any, unread: m.filter(x => x.sender_id !== me && x.created_at > read.get(id)).length }; })
    .sort((a, b) => (b.last?.created_at ?? "").localeCompare(a.last?.created_at ?? ""));
}
