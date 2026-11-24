import { FFmpeg } from "@ffmpeg/ffmpeg"; import { fetchFile, toBlobURL } from "@ffmpeg/util";
export type ExportOpts = { file: File; start: number; dur: number; vf: string; vol: number; music: File | null; musicVol: number; onProgress: (p: number) => void };
export async function exportReel(o: ExportOpts): Promise<{ video: Blob; thumb: Blob }> {
  const ff = new FFmpeg(); ff.on("progress", ({ progress }) => o.onProgress(Math.min(1, Math.max(0, progress))));
  const base = "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd";
  await ff.load({ coreURL: await toBlobURL(`${base}/ffmpeg-core.js`, "text/javascript"), wasmURL: await toBlobURL(`${base}/ffmpeg-core.wasm`, "application/wasm") });
  await ff.writeFile("in", await fetchFile(o.file)); if (o.music) await ff.writeFile("aud", await fetchFile(o.music));
  const fit = "scale=540:960:force_original_aspect_ratio=decrease,pad=540:960:(ow-iw)/2:(oh-ih)/2:black,setsar=1";
  const run = async (srcAudio: boolean) => {
    const a = ["-ss", String(o.start), "-t", String(o.dur), "-i", "in"]; if (o.music) a.push("-i", "aud");
    let g = `[0:v]${o.vf},${fit}[v]`; const map = ["-map", "[v]"];
    if (srcAudio && o.music) g += `;[0:a]volume=${o.vol}[a0];[1:a]volume=${o.musicVol},atrim=0:${o.dur}[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]`;
    else if (srcAudio) g += `;[0:a]volume=${o.vol}[a]`;
    else if (o.music) g += `;[1:a]volume=${o.musicVol},atrim=0:${o.dur}[a]`;
    if (srcAudio || o.music) map.push("-map", "[a]");
    const code = await ff.exec([...a, "-filter_complex", g, ...map, "-c:v", "libx264", "-preset", "ultrafast", "-crf", "28", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", "out.mp4"]);
    if (code !== 0) throw new Error("encode failed");
  };
  try { await run(true); } catch { await run(false); } // retry for clips with no audio track
  await ff.exec(["-i", "out.mp4", "-frames:v", "1", "-q:v", "4", "thumb.jpg"]);
  const v = (await ff.readFile("out.mp4")) as Uint8Array, t = (await ff.readFile("thumb.jpg")) as Uint8Array;
  ff.terminate();
  return { video: new Blob([v as unknown as BlobPart], { type: "video/mp4" }), thumb: new Blob([t as unknown as BlobPart], { type: "image/jpeg" }) };
}
