import "./globals.css";
import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque, Figtree } from "next/font/google";
const display = Bricolage_Grotesque({ subsets:["latin"], variable:"--font-display" });
const body = Figtree({ subsets:["latin"], variable:"--font-body" });
export const metadata: Metadata = { title:"Lumen", description:"Share what lights you up." };
export const viewport: Viewport = { width:"device-width", initialScale:1, viewportFit:"cover" };
export default function Root({ children }:{ children: React.ReactNode }) {
  return <html lang="en" className={`${display.variable} ${body.variable}`}><body>{children}</body></html>;
}
