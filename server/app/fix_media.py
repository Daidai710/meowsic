from __future__ import annotations

import logging
import shutil
import subprocess
from pathlib import Path
from typing import Optional

from .config import Settings, resolve_ffmpeg

log = logging.getLogger("music_hub.fix")


def fix_to_mp3(src: Path, settings: Settings, bitrate: Optional[str] = None) -> Path:
    """
    Transcode broken/unsupported file to sibling .fixed.mp3 (or replace .mp3).
    Returns path to the fixed file.
    """
    ffmpeg = resolve_ffmpeg(settings)
    if not ffmpeg:
        raise RuntimeError("FFmpeg not available")
    if not src.is_file():
        raise FileNotFoundError(str(src))

    br = bitrate or settings.transcode_bitrate
    if src.suffix.lower() == ".mp3":
        out = src.with_name(src.stem + ".fixed.mp3")
    else:
        out = src.with_suffix(".fixed.mp3")

    # avoid overwrite loop
    n = 1
    while out.exists() and out.resolve() != src.resolve():
        out = src.with_name(f"{src.stem}.fixed{n}.mp3")
        n += 1

    args = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(src),
        "-vn",
        "-c:a",
        "libmp3lame",
        "-b:a",
        br,
        str(out),
    ]
    log.info("fix-transcode: %s -> %s", src, out)
    proc = subprocess.run(args, capture_output=True, text=True, timeout=600)
    if proc.returncode != 0 or not out.is_file() or out.stat().st_size < 1000:
        err = (proc.stderr or proc.stdout or "ffmpeg failed")[:500]
        if out.is_file():
            try:
                out.unlink()
            except OSError:
                pass
        raise RuntimeError(err)

    # If original was bad mp3, optionally replace: keep original as .bak
    if src.suffix.lower() == ".mp3":
        bak = src.with_suffix(".mp3.bak")
        try:
            if not bak.exists():
                shutil.move(str(src), str(bak))
            else:
                # leave original, use fixed path
                return out
            shutil.move(str(out), str(src))
            return src
        except OSError:
            return out
    return out
