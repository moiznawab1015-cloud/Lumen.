import Link from "next/link"; import { createClient } from "@/lib/supabase/server"; import { enrich } from "@/lib/feed"; import PostCard from "@/components/PostCard"; import StoriesBar from "@/components/StoriesBar"; import Logo from "@/components/Logo"; import HeaderActions from "@/components/HeaderActions"; import { loadConversations } from "@/lib/dm";
export default async function Home() {
  const db = await createClient(); const { data: { user } } = await db.auth.getUser(); const me = user!.id;
  const { data: f } = await db.from("follows").select("followee_id").eq("follower_id", me).eq("status", "accepted");
  const ids = [me, ...(f ?? []).map(x => x.followee_id)];
  const [{ data: posts }, { data: st }] = await Promise.all([
    db.from("posts").select("*, profiles(username,avatar_url)").in("author_id", ids).eq("removed", false).order("created_at", { ascending: false }).limit(20),
    db.from("stories").select("id,kind,media_url,author_id,created_at, profiles(username,avatar_url)").in("author_id", ids).gt("expires_at", new Date().toISOString()).order("created_at")]);
  const map = new Map<string, any>(); (st ?? []).forEach((s: any) => { const g = map.get(s.author_id) ?? { id: s.author_id, ...s.profiles, items: [] }; g.items.push(s); map.set(s.author_id, g); });
  const cards = await enrich(db, posts ?? [], me);
  const [{ count: nn }, convs] = await Promise.all([db.from("notifications").select("id", { count: "exact", head: true }).eq("recipient_id", me).eq("read", false), loadConversations(db, me)]);
  return <main><header className="flex items-center gap-2 px-4 pt-6"><Logo size={32} /><span className="font-display text-2xl font-extrabold tracking-tight">Lumen</span><HeaderActions me={me} notifs={nn ?? 0} dms={convs.reduce((a, c) => a + c.unread, 0)} /></header>
    <StoriesBar me={me} groups={[...map.values()]} />
    {cards.length === 0 ? <div className="px-8 py-16 text-center text-mute"><p>Your feed is quiet.</p><p className="mt-1">Follow people on <Link href="/explore" className="font-semibold text-glow">Explore</Link> or share your first post.</p></div>
      : cards.map(c => <PostCard key={c.post.id} me={me} {...c} />)}</main>;
}
