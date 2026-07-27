from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

from mutagen import File as MutagenFile
from mutagen.id3 import USLT


def _parse_lrc(text: str) -> list[dict]:
    """Parse LRC into [{t: seconds, line: str}, ...]."""
    lines_out: list[dict] = []
    # [mm:ss.xx] or [mm:ss]
    pat = re.compile(r"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)")
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        m = pat.match(raw)
        if not m:
            # plain line without timestamp
            if raw and not raw.startswith("["):
                lines_out.append({"t": None, "line": raw})
            continue
        mm, ss, ms, line = m.groups()
        sec = int(mm) * 60 + int(ss)
        if ms:
            sec += int(ms.ljust(3, "0")[:3]) / 1000.0
        lines_out.append({"t": sec, "line": line.strip()})
    return lines_out


def load_lyrics_for_path(audio_path: Path) -> dict:
    """
    Returns {source, text, lines}.
    Tries: same-name .lrc, .txt, embedded USLT / lyrics tags.
    """
    audio_path = Path(audio_path)
    # 1) sibling lrc
    for ext in (".lrc", ".LRC", ".txt"):
        cand = audio_path.with_suffix(ext)
        if cand.is_file():
            try:
                text = cand.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if text.strip():
                return {
                    "source": cand.name,
                    "text": text,
                    "lines": _parse_lrc(text) if ext.lower() == ".lrc" or "[" in text[:200] else [
                        {"t": None, "line": ln} for ln in text.splitlines() if ln.strip()
                    ],
                }

    # 2) embedded
    try:
        audio = MutagenFile(audio_path)
        if audio is None:
            return {"source": None, "text": "", "lines": []}
        # ID3 USLT
        tags = getattr(audio, "tags", None)
        if tags is not None:
            for key in list(tags.keys()) if hasattr(tags, "keys") else []:
                if str(key).startswith("USLT") or str(key).startswith("\xa9lyr"):
                    val = tags[key]
                    if isinstance(val, USLT):
                        text = str(val.text or "")
                    elif isinstance(val, list) and val:
                        text = str(val[0])
                    else:
                        text = str(val)
                    if text.strip():
                        return {
                            "source": "embedded",
                            "text": text,
                            "lines": _parse_lrc(text) if "[" in text[:200] else [
                                {"t": None, "line": ln} for ln in text.splitlines() if ln.strip()
                            ],
                        }
            # common keys
            for k in ("lyrics", "LYRICS", "©lyr"):
                if k in tags:
                    text = str(tags[k] if not isinstance(tags[k], list) else tags[k][0])
                    if text.strip():
                        return {
                            "source": "embedded",
                            "text": text,
                            "lines": [{"t": None, "line": ln} for ln in text.splitlines() if ln.strip()],
                        }
    except Exception:
        pass

    return {"source": None, "text": "", "lines": []}
