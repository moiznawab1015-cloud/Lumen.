export function ago(iso: string) {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  for (const [n, u] of [[604800, "w"], [86400, "d"], [3600, "h"], [60, "m"]] as const) if (s >= n) return `${Math.floor(s / n)}${u}`;
  return "now";
}
