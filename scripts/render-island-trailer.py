"""Render an illustrated 18-second promotional trailer and original soundtrack.

Requires Pillow, NumPy and imageio-ffmpeg in .tools/video-runtime.
"""

from pathlib import Path
import json
import math
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools" / "video-runtime"))
import imageio_ffmpeg

OUT = ROOT / "artwork" / "video"
WIDTH, HEIGHT, FPS, SECONDS = 1280, 720, 30, 18
RATE = 44100
FONT_PATH = "C:/Windows/Fonts/arialbd.ttf"


def ease(value):
    value = max(0, min(1, value))
    return value * value * (3 - 2 * value)


def soundtrack():
    rng = np.random.default_rng(714)
    audio = np.zeros((RATE * SECONDS, 2), dtype=np.float64)
    beat = SECONDS / 32
    chords = [(60, 64, 67), (55, 59, 62), (57, 60, 64), (53, 57, 60),
              (60, 64, 67), (55, 59, 62), (53, 57, 60), (60, 64, 67)]

    def add(signal, at, volume, pan=0.5):
        start = int(at * RATE)
        count = min(len(signal), len(audio) - start)
        if count > 0:
            audio[start:start + count, 0] += signal[:count] * volume * math.sqrt(1 - pan)
            audio[start:start + count, 1] += signal[:count] * volume * math.sqrt(pan)

    def pluck(note, duration, decay):
        t = np.arange(int(duration * RATE)) / RATE
        frequency = 440 * 2 ** ((note - 69) / 12)
        signal = sum(np.sin(2 * np.pi * frequency * harmonic * t) * weight
                     * np.exp(-t * harmonic / decay)
                     for harmonic, weight in [(1, 1), (2, 0.32), (3, 0.12), (4, 0.045)])
        return signal * (1 - np.exp(-t / 0.006)) * np.clip((duration - t) / 0.08, 0, 1)

    for bar, chord in enumerate(chords):
        for step in range(8):
            note = chord[[0, 1, 2, 1, 0, 2, 1, 2][step]] + 12
            add(pluck(note, 0.8, 0.26), (bar * 4 + step / 2) * beat,
                0.105 if step % 2 == 0 else 0.075, 0.3 + 0.4 * (step % 3) / 2)
        for pulse in range(4):
            at = (bar * 4 + pulse) * beat
            add(pluck(chord[0] - 12, 0.7, 0.3), at, 0.13)
            t = np.arange(int(0.12 * RATE)) / RATE
            kick = np.sin(2 * np.pi * (65 * t + 35 * 0.018 * (1 - np.exp(-t / 0.018))))
            add(kick * np.exp(-t / 0.035) * np.minimum(t / 0.003, 1), at, 0.055)
            if pulse % 2:
                tap = rng.normal(size=len(t)) * np.exp(-t / 0.011) * np.minimum(t / 0.002, 1)
                add(tap, at, 0.019, 0.6)
    t = np.arange(len(audio)) / RATE
    audio *= np.minimum(t / 0.5, 1)[:, None]
    audio *= np.clip((SECONDS - t) / 1.1, 0, 1)[:, None]
    audio *= min(1.5, 0.65 / np.max(np.abs(audio)))
    path = OUT / "island-farm-tycoon-music.wav"
    with wave.open(str(path), "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(np.rint(audio * 32767).astype("<i2").tobytes())
    return path


def camera(source, zoom, cx, cy):
    sw, sh = source.size
    crop_width = sw / zoom
    crop_height = crop_width * HEIGHT / WIDTH
    left = max(0, min(sw - crop_width, cx * sw - crop_width / 2))
    top = max(0, min(sh - crop_height, cy * sh - crop_height / 2))
    return source.resize((WIDTH, HEIGHT), Image.Resampling.BICUBIC,
                         box=(left, top, left + crop_width, top + crop_height)).convert("RGBA")


def caption(frame, title, detail, opacity, offset):
    layer = Image.new("RGBA", frame.size)
    draw = ImageDraw.Draw(layer)
    # A soft lower scrim maintains contrast without covering the scene.
    for y in range(HEIGHT - 210, HEIGHT):
        alpha = int(120 * ((y - HEIGHT + 210) / 210) ** 1.4 * opacity)
        draw.line((0, y, WIDTH, y), fill=(8, 25, 24, alpha))
    headline = ImageFont.truetype(FONT_PATH, 42)
    small = ImageFont.truetype(FONT_PATH, 23)
    y = HEIGHT - 120 + offset
    draw.text((WIDTH / 2, y), title, font=headline, anchor="mm",
              fill=(255, 224, 122, int(255 * opacity)), stroke_width=2,
              stroke_fill=(31, 42, 22, int(200 * opacity)))
    draw.text((WIDTH / 2, y + 48), detail, font=small, anchor="mm",
              fill=(255, 255, 247, int(255 * opacity)))
    return Image.alpha_composite(frame, layer)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scene = Image.open(ROOT / "artwork" / "island-farm-tycoon-trailer-scene.png")
    cover = Image.open(ROOT / "artwork" / "island-farm-tycoon-cover.png")
    music = soundtrack()
    shots = [
        (0, 4.5, scene, (1.06, 0.51, 0.5), (1.48, 0.52, 0.47),
         "Build your farm.", "A small island. A big dream."),
        (4.5, 9, scene, (1.8, 0.28, 0.76), (1.52, 0.39, 0.7),
         "Raise your animals.", "Bring your farm to life."),
        (9, 13.5, scene, (1.65, 0.76, 0.34), (1.28, 0.65, 0.42),
         "Discover new islands.", "Build bridges. Grow your farm."),
        (13.5, 18, cover, (1.06, 0.5, 0.5), (1, 0.5, 0.5),
         "Create your island story.", "ISLAND FARM TYCOON"),
    ]

    def shot_frame(index, now):
        start, end, source, before, after, title, detail = shots[index]
        progress = ease((now - start) / (end - start))
        zoom, cx, cy = [a + (b - a) * progress for a, b in zip(before, after)]
        frame = camera(source, zoom, cx, cy)
        elapsed = now - start
        opacity = ease((elapsed - 0.45) / 0.45)
        if index < 3:
            opacity *= ease((end - now - 0.1) / 0.45)
        return caption(frame, title, detail, opacity, int(18 * (1 - opacity)))

    video = OUT / "island-farm-tycoon-trailer-en.mp4"
    command = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo",
               "-vcodec", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{WIDTH}x{HEIGHT}",
               "-r", str(FPS), "-i", "pipe:0", "-i", str(music),
               "-c:v", "libx264", "-preset", "fast", "-crf", "19", "-pix_fmt", "yuv420p",
               "-c:a", "aac", "-b:a", "192k", "-t", str(SECONDS),
               "-movflags", "+faststart", str(video)]
    log = OUT / "render-en.log"
    previews = []
    with log.open("w", encoding="utf-8") as diagnostics:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stderr=diagnostics)
        try:
            for frame_number in range(SECONDS * FPS):
                now = frame_number / FPS
                index = min(int(now / 4.5), 3)
                frame = shot_frame(index, now)
                if index > 0 and now - shots[index][0] < 0.5:
                    previous = shot_frame(index - 1, shots[index][0] - 0.01)
                    frame = Image.blend(previous, frame, ease((now - shots[index][0]) / 0.5))
                fade = min(ease(now / 0.55), ease((SECONDS - now) / 0.65))
                if fade < 1:
                    frame = Image.blend(Image.new("RGBA", frame.size, (9, 29, 29, 255)), frame, fade)
                rgb = frame.convert("RGB")
                if frame_number in [75, 210, 345, 480]:
                    previews.append(rgb.copy())
                process.stdin.write(rgb.tobytes())
            process.stdin.close()
            assert process.wait() == 0, log.read_text(encoding="utf-8")[-2000:]
        finally:
            if process.poll() is None:
                process.kill()
    contact = Image.new("RGB", (WIDTH, HEIGHT))
    for index, preview in enumerate(previews):
        contact.paste(preview.resize((WIDTH // 2, HEIGHT // 2)),
                      ((index % 2) * WIDTH // 2, (index // 2) * HEIGHT // 2))
    contact.save(OUT / "trailer-preview-en.jpg", quality=92)
    # Decode the delivered MP4 to verify frame count and dimensions.
    reader = imageio_ffmpeg.read_frames(str(video), pix_fmt="rgb24")
    metadata = next(reader)
    count = sum(1 for _ in reader)
    assert count == SECONDS * FPS, count
    assert metadata["size"] == (WIDTH, HEIGHT), metadata
    print(json.dumps({"video": str(video), "frames": count, "seconds": SECONDS,
                      "size": metadata["size"], "fps": metadata["fps"],
                      "bytes": video.stat().st_size, "verified": True}, indent=2))


if __name__ == "__main__":
    main()
