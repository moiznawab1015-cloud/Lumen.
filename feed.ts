import type { SupabaseClient } from "@supabase/supabase-js";
export async function enrich(db: SupabaseClient, posts: any[], me: string) {
  const ids = posts.map(p => p.id); if (!ids.length) return [];
  const [st, li, sa] = await Promise.all([
    db.from("post_stats").select("*").in("post_id", ids),
    db.from("likes").select("post_id").eq("user_id", me).in("post_id", ids),
    db.from("saves").select("post_id").eq("user_id", me).in("post_id", ids)]);
  const stats = new Map((st.data ?? []).map((s: any) => [s.post_id, s]));
  const liked = new Set((li.data ?? []).map((l: any) => l.post_id)), saved = new Set((sa.data ?? []).map((l: any) => l.post_id));
  return posts.map(p => ({ post: p, stats: stats.get(p.id) ?? { like_count: 0, comment_count: 0, view_count: 0 }, liked: liked.has(p.id), saved: saved.has(p.id) }));
}
