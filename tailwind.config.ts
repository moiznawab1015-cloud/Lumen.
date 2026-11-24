import type { Config } from "tailwindcss";
export default { content:["./src/**/*.{ts,tsx}"], theme:{ extend:{
  colors:{ bg:"var(--bg)", surface:"var(--surface)", ink:"var(--ink)", mute:"var(--mute)", line:"var(--line)", glow:"var(--glow)", "glow-ink":"var(--glow-ink)" },
  fontFamily:{ display:["var(--font-display)"], sans:["var(--font-body)"] },
  borderRadius:{ xl2:"1.25rem" } } }, plugins:[] } satisfies Config;
