// One preset definition drives BOTH the live CSS preview and the ffmpeg export, so they match.
export type FP = { name: string; b: number; c: number; s: number; sepia?: number; hue?: number; gray?: number };
export type Adj = { b: number; c: number; s: number };
export const PRESETS: FP[] = [
  { name: "Natural", b: 1, c: 1.03, s: 1.08 },
  { name: "Vintage", b: 1.05, c: 0.9, s: 0.8, sepia: 0.45 },
  { name: "Cinematic", b: 0.95, c: 1.25, s: 0.9, hue: -8 },
  { name: "Warm", b: 1.05, c: 1.05, s: 1.2, sepia: 0.2, hue: -10 },
  { name: "Cool", b: 1, c: 1.05, s: 1.1, hue: 12 },
  { name: "Retro", b: 1.1, c: 0.85, s: 1.4, sepia: 0.3, hue: -20 },
  { name: "Black & White", b: 1, c: 1.15, s: 1, gray: 1 },
  { name: "Golden", b: 1.1, c: 1.05, s: 1.35, sepia: 0.55, hue: -12 }];
const eff = (p: FP, a: Adj) => ({ b: p.b * a.b, c: p.c * a.c, s: p.s * a.s });
export function cssFilter(p: FP, a: Adj) {
  const e = eff(p, a);
  return [`brightness(${e.b})`, `contrast(${e.c})`, `saturate(${e.s})`, p.sepia ? `sepia(${p.sepia})` : "", p.hue ? `hue-rotate(${p.hue}deg)` : "", p.gray ? `grayscale(${p.gray})` : ""].filter(Boolean).join(" ");
}
export function ffmpegFilter(p: FP, a: Adj) {
  const e = eff(p, a);
  const f = [`eq=brightness=${((e.b - 1) * 0.4).toFixed(3)}:contrast=${e.c.toFixed(3)}:saturation=${e.s.toFixed(3)}`];
  if (p.sepia) { const k = p.sepia, m = [[.393, .769, .189], [.349, .686, .168], [.272, .534, .131]];
    const n = m.map((r, i) => r.map((v, j) => ((i === j ? 1 - k : 0) + k * v).toFixed(4)));
    f.push(`colorchannelmixer=${n[0].join(":")}:0:${n[1].join(":")}:0:${n[2].join(":")}:0`); }
  if (p.hue) f.push(`hue=h=${p.hue}`);
  if (p.gray) f.push(`hue=s=${(1 - p.gray).toFixed(2)}`);
  return f.join(",");
}
