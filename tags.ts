import type { SupabaseClient } from "@supabase/supabase-js";
export async function saveTags(db: SupabaseClient, postId: string, caption: string) {
  const tags = [...new Set((caption.match(/#([\p{L}\p{N}_]{1,40})/gu) ?? []).map(t => t.slice(1).toLowerCase()))]; if (!tags.length) return;
  const { data } = await db.from("hashtags").upsert(tags.map(tag => ({ tag })), { onConflict: "tag" }).select("id");
  if (data?.length) await db.from("post_hashtags").insert(data.map(h => ({ post_id: postId, hashtag_id: h.id })));
}
