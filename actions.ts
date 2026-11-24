"use server";
import { revalidatePath } from "next/cache"; import { createClient } from "@/lib/supabase/server";
async function admin() {
  const db = await createClient(); const { data: { user } } = await db.auth.getUser(); if (!user) throw new Error("Not signed in");
  const { data: me } = await db.from("profiles").select("role").eq("id", user.id).single(); if (me?.role !== "admin") throw new Error("Forbidden"); return { db, uid: user.id };
}
const WEEK = () => new Date(Date.now() + 7 * 864e5).toISOString();
async function punish(db: any, uid: string, target: string | null, act: string) {
  if (!target || target === uid) return; const { data: t } = await db.from("profiles").select("role").eq("id", target).single(); if (t?.role === "admin") return;
  if (act === "suspend") await db.from("profiles").update({ suspended_until: WEEK() }).eq("id", target);
  if (act === "ban") await db.from("profiles").update({ banned: true }).eq("id", target);
  if (act === "restore") await db.from("profiles").update({ banned: false, suspended_until: null }).eq("id", target);
}
export async function reportAction(fd: FormData) {
  const { db, uid } = await admin(); const id = String(fd.get("id")), act = String(fd.get("act"));
  const { data: r } = await db.from("reports").select("*, post:posts(author_id), comment:comments(author_id)").eq("id", id).single(); if (!r) return;
  if (act === "remove") { if (r.post_id) await db.from("posts").update({ removed: true }).eq("id", r.post_id); if (r.comment_id) await db.from("comments").delete().eq("id", r.comment_id); }
  await punish(db, uid, r.reported_user_id ?? r.post?.author_id ?? r.comment?.author_id ?? null, act);
  await db.from("reports").update({ status: act === "dismiss" ? "dismissed" : "actioned" }).eq("id", id); revalidatePath("/admin");
}
export async function userAction(fd: FormData) { const { db, uid } = await admin(); await punish(db, uid, String(fd.get("id")), String(fd.get("act"))); revalidatePath("/admin"); }
export async function postAction(fd: FormData) { const { db } = await admin(); await db.from("posts").update({ removed: String(fd.get("act")) === "remove" }).eq("id", String(fd.get("id"))); revalidatePath("/admin"); }
