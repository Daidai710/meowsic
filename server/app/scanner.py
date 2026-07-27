from __future__ import annotations

import hashlib
import logging
import mimetypes
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from mutagen import File as MutagenFile
from mutagen.flac import FLAC, Picture
from mutagen.id3 import APIC, ID3, ID3NoHeaderError
from mutagen.mp3 import HeaderNotFoundError, MP3
from mutagen.mp4 import MP4

from .config import COVERS_DIR, ensure_dirs
from .db import get_db

log = logging.getLogger("music_hub.scanner")

AUDIO_EXTENSIONS = {
    ".mp3",
    ".flac",
    ".m4a",
    ".aac",
    ".ogg",
    ".opus",
    ".wav",
    ".wma",
    ".aiff",
    ".aif",
    ".ape",
    ".wv",
    ".alac",
}

# Browsers can usually play these without server-side transcode.
BROWSER_NATIVE = {".mp3", ".m4a", ".aac", ".ogg", ".opus", ".wav", ".flac"}

# Errors that mean "tags/headers messy" not "skip file"
_SOFT_MPEG_MARKERS = (
    "can't sync to mpeg frame",
    "can't sync to MPEG frame",
    "header not found",
    "can't find end of frame",
)


@dataclass
class ScanResult:
    scanned: int = 0
    added: int = 0
    updated: int = 0
    removed: int = 0
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    formats: dict[str, int] = field(default_factory=dict)


def _first(val: Any, default: str = "") -> str:
    if val is None:
        return default
    if isinstance(val, list):
        return str(val[0]).strip() if val else default
    return str(val).strip() or default


def _as_int(val: Any) -> Optional[int]:
    if val is None:
        return None
    try:
        if isinstance(val, list) and val:
            val = val[0]
        s = str(val)
        if "/" in s:
            s = s.split("/", 1)[0]
        return int(float(s))
    except (TypeError, ValueError):
        return None


def _is_soft_mpeg_error(exc: BaseException) -> bool:
    msg = str(exc).lower()
    return any(m.lower() in msg for m in _SOFT_MPEG_MARKERS) or isinstance(
        exc, (HeaderNotFoundError, ID3NoHeaderError)
    )


def probe_real_format(path: Path) -> Optional[str]:
    """Guess container from magic bytes (helps mis-named downloads)."""
    try:
        with path.open("rb") as f:
            head = f.read(16)
    except OSError:
        return None
    if len(head) < 12:
        return None
    if head.startswith(b"ID3") or head[:2] in (b"\xff\xfb", b"\xff\xfa", b"\xff\xf3", b"\xff\xf2"):
        return "mp3"
    if head[4:8] == b"ftyp":
        # mp4 / m4a / aac in mp4
        brand = head[8:12]
        if brand in (b"M4A ", b"M4B ", b"mp42", b"isom", b"iso2", b"dash"):
            return "m4a"
        return "m4a"
    if head.startswith(b"fLaC"):
        return "flac"
    if head.startswith(b"OggS"):
        return "ogg"
    if head.startswith(b"RIFF") and head[8:12] == b"WAVE":
        return "wav"
    if head.startswith(b"\x30\x26\xb2\x75"):  # ASF/WMA
        return "wma"
    # Some broken "mp3" from video extractors start with other containers
    if head.startswith(b"\x1aE\xdf\xa3"):  # EBML / webm / mkv
        return "webm"
    return None


def _base_meta(path: Path) -> dict[str, Any]:
    fmt = path.suffix.lower().lstrip(".")
    probed = probe_real_format(path)
    if probed and probed != fmt:
        # Prefer real container for streaming MIME / transcode decisions
        log.info("format mismatch %s: extension=.%s probe=%s", path.name, fmt, probed)
        fmt = probed
    return {
        "path": str(path.resolve()),
        "title": path.stem,
        "artist": "Unknown Artist",
        "album": "Unknown Album",
        "album_artist": None,
        "track": None,
        "disc": None,
        "year": None,
        "genre": None,
        "duration": None,
        "bitrate": None,
        "sample_rate": None,
        "format": fmt,
        "file_size": path.stat().st_size,
        "mtime": path.stat().st_mtime,
        "cover_path": None,
        "tag_ok": 1,
        "replaygain_db": None,
    }


def _parse_replaygain_db(val: Any) -> Optional[float]:
    s = _first(val, "")
    if not s:
        return None
    s = s.lower().replace("db", "").replace("lu", "").strip()
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def _apply_easy_tags(meta: dict[str, Any], tags: Any, path: Path) -> None:
    if not tags:
        return
    meta["title"] = _first(tags.get("title") or tags.get("TITLE"), path.stem)
    meta["artist"] = _first(tags.get("artist") or tags.get("ARTIST"), "Unknown Artist")
    meta["album"] = _first(tags.get("album") or tags.get("ALBUM"), "Unknown Album")
    meta["album_artist"] = _first(
        tags.get("albumartist") or tags.get("album artist") or tags.get("ALBUMARTIST"),
        "",
    ) or None
    meta["genre"] = _first(tags.get("genre") or tags.get("GENRE"), "") or None
    meta["track"] = _as_int(tags.get("tracknumber") or tags.get("track") or tags.get("TRACKNUMBER"))
    meta["disc"] = _as_int(tags.get("discnumber") or tags.get("disc") or tags.get("DISCNUMBER"))
    year_raw = _first(tags.get("date") or tags.get("year") or tags.get("DATE"), "")
    if year_raw:
        meta["year"] = _as_int(year_raw[:4])
    rg = _parse_replaygain_db(
        tags.get("replaygain_track_gain")
        or tags.get("REPLAYGAIN_TRACK_GAIN")
        or tags.get("replaygain_album_gain")
    )
    if rg is not None:
        meta["replaygain_db"] = rg


def _apply_info(meta: dict[str, Any], info: Any) -> None:
    if info is None:
        return
    meta["duration"] = getattr(info, "length", None)
    br = getattr(info, "bitrate", None)
    if br:
        meta["bitrate"] = int(br) if br < 1_000_000 else int(br // 1000)
    meta["sample_rate"] = getattr(info, "sample_rate", None)


def _read_mp3_soft(path: Path, meta: dict[str, Any]) -> list[str]:
    """Read MP3 tags/info without aborting on 'can't sync to MPEG frame'."""
    warnings: list[str] = []

    # 1) ID3 tags only (works even when frame sync fails)
    try:
        id3 = ID3(path)
        # map common frames manually without EasyID3 dependency issues
        if "TIT2" in id3:
            meta["title"] = str(id3["TIT2"]) or meta["title"]
        if "TPE1" in id3:
            meta["artist"] = str(id3["TPE1"]) or meta["artist"]
        if "TALB" in id3:
            meta["album"] = str(id3["TALB"]) or meta["album"]
        if "TPE2" in id3:
            meta["album_artist"] = str(id3["TPE2"]) or None
        if "TCON" in id3:
            meta["genre"] = str(id3["TCON"]) or None
        if "TRCK" in id3:
            meta["track"] = _as_int(str(id3["TRCK"]))
        if "TPOS" in id3:
            meta["disc"] = _as_int(str(id3["TPOS"]))
        if "TDRC" in id3:
            meta["year"] = _as_int(str(id3["TDRC"])[:4])
        elif "TYER" in id3:
            meta["year"] = _as_int(str(id3["TYER"])[:4])
    except ID3NoHeaderError:
        pass
    except Exception as e:
        if _is_soft_mpeg_error(e):
            warnings.append(f"{path.name}: ID3 soft warn: {e}")
        else:
            warnings.append(f"{path.name}: ID3: {e}")

    # 2) MPEG audio info (may fail with can't sync)
    try:
        mp3 = MP3(path)
        _apply_info(meta, mp3.info)
    except HeaderNotFoundError as e:
        meta["tag_ok"] = 0
        warnings.append(f"{path.name}: can't sync to MPEG frame（文件可能损坏或其实不是 mp3）")
        log.warning("MPEG sync failed (kept in library): %s — %s", path, e)
    except Exception as e:
        if _is_soft_mpeg_error(e):
            meta["tag_ok"] = 0
            warnings.append(f"{path.name}: MPEG soft warn: {e}")
            log.warning("MPEG soft error (kept): %s — %s", path, e)
        else:
            meta["tag_ok"] = 0
            warnings.append(f"{path.name}: MP3 info: {e}")

    return warnings


def extract_metadata(path: Path) -> tuple[dict[str, Any], list[str]]:
    """
    Read tags + basic audio info.
    Always returns meta so the file stays in the library even if MPEG headers are broken.
    """
    meta = _base_meta(path)
    warnings: list[str] = []
    ext = path.suffix.lower()

    # Prefer soft path for .mp3 (common source of "can't sync to MPEG frame")
    if ext == ".mp3" or meta["format"] == "mp3":
        warnings.extend(_read_mp3_soft(path, meta))
    else:
        try:
            audio = MutagenFile(path, easy=True)
        except Exception as e:
            if _is_soft_mpeg_error(e):
                meta["tag_ok"] = 0
                warnings.append(f"{path.name}: {e}")
                audio = None
            else:
                log.warning("mutagen easy open failed %s: %s", path, e)
                warnings.append(f"{path.name}: open failed: {e}")
                audio = None

        if audio is not None:
            tags = getattr(audio, "tags", None) or {}
            _apply_easy_tags(meta, tags, path)
            _apply_info(meta, getattr(audio, "info", None))
        else:
            # last try: non-easy
            try:
                raw = MutagenFile(path)
                if raw is not None:
                    _apply_info(meta, getattr(raw, "info", None))
            except Exception as e:
                meta["tag_ok"] = 0
                if _is_soft_mpeg_error(e):
                    warnings.append(f"{path.name}: can't sync / bad header（仍入库）")
                else:
                    warnings.append(f"{path.name}: {e}")

    # webm/mkv mislabeled as mp3 → force transcode path
    if meta["format"] in ("webm", "mkv", "wma", "ape", "wv"):
        meta["tag_ok"] = 0

    try:
        cover = extract_cover(path)
        if cover:
            meta["cover_path"] = cover
    except Exception as e:
        log.debug("cover extract failed %s: %s", path, e)

    return meta, warnings


def extract_cover(path: Path) -> Optional[str]:
    """Save embedded cover art to data/covers; return path."""
    ensure_dirs()
    key = hashlib.sha1(str(path.resolve()).encode("utf-8")).hexdigest()[:16]
    out_base = COVERS_DIR / key

    try:
        for name in ("cover.jpg", "cover.png", "folder.jpg", "Folder.jpg", "front.jpg"):
            sibling = path.parent / name
            if sibling.is_file():
                dest = out_base.with_suffix(sibling.suffix.lower())
                if not dest.exists() or dest.stat().st_mtime < sibling.stat().st_mtime:
                    shutil.copy2(sibling, dest)
                return str(dest)

        data: Optional[bytes] = None
        mime = "image/jpeg"

        # ID3 APIC without full MP3 parse
        if path.suffix.lower() == ".mp3":
            try:
                id3 = ID3(path)
                for k in id3.keys():
                    if k.startswith("APIC"):
                        apic: APIC = id3[k]  # type: ignore
                        data = apic.data
                        mime = apic.mime or mime
                        break
            except Exception:
                pass

        if data is None:
            try:
                raw = MutagenFile(path)
            except Exception:
                raw = None
            if raw is None:
                return None
            if isinstance(raw, FLAC):
                pics: list[Picture] = raw.pictures
                if pics:
                    data = pics[0].data
                    mime = pics[0].mime or mime
            elif isinstance(raw, MP4) and raw.tags:
                covr = raw.tags.get("covr")
                if covr:
                    pic = covr[0]
                    data = bytes(pic)
                    mime = "image/png" if getattr(pic, "imageformat", None) == 14 else "image/jpeg"
            elif isinstance(raw, MP3):
                try:
                    id3 = ID3(path)
                    for k in id3.keys():
                        if k.startswith("APIC"):
                            apic = id3[k]  # type: ignore
                            data = apic.data
                            mime = apic.mime or mime
                            break
                except Exception:
                    pass

        if not data:
            return None

        ext = ".png" if "png" in mime else ".jpg"
        dest = out_base.with_suffix(ext)
        dest.write_bytes(data)
        return str(dest)
    except Exception as e:
        log.debug("cover extract failed %s: %s", path, e)
        return None


def _upsert_song(conn, meta: dict[str, Any]) -> str:
    cur = conn.execute("SELECT id, mtime FROM songs WHERE path = ?", (meta["path"],))
    row = cur.fetchone()
    fields = (
        "title",
        "artist",
        "album",
        "album_artist",
        "track",
        "disc",
        "year",
        "genre",
        "duration",
        "bitrate",
        "sample_rate",
        "format",
        "file_size",
        "mtime",
        "cover_path",
        "tag_ok",
        "replaygain_db",
    )
    if row is None:
        cols = ["path", *fields]
        placeholders = ", ".join("?" * len(cols))
        conn.execute(
            f"INSERT INTO songs ({', '.join(cols)}) VALUES ({placeholders})",
            [meta["path"], *[meta[f] for f in fields]],
        )
        return "added"
    # Always refresh metadata on scan so tag_ok / format probe stay current
    sets = ", ".join(f"{f} = ?" for f in fields)
    conn.execute(
        f"UPDATE songs SET {sets}, updated_at = datetime('now') WHERE path = ?",
        [*[meta[f] for f in fields], meta["path"]],
    )
    if row["mtime"] != meta["mtime"]:
        return "updated"
    return "skipped"


def scan_library(library_path: str | Path) -> ScanResult:
    """Scan a single root directory (compat wrapper)."""
    return scan_libraries([library_path])


def scan_libraries(library_paths: list[str | Path]) -> ScanResult:
    """Scan one or more library roots into the same DB; prune only under those roots."""
    result = ScanResult()
    roots: list[Path] = []
    for library_path in library_paths:
        root = Path(library_path).expanduser().resolve()
        if not root.is_dir():
            result.errors.append(f"Library path does not exist: {root}")
            continue
        roots.append(root)

    if not roots:
        if not result.errors:
            result.errors.append("No valid library paths")
        return result

    files: list[Path] = []
    for root in roots:
        for p in root.rglob("*"):
            if p.is_file() and p.suffix.lower() in AUDIO_EXTENSIONS:
                files.append(p)

    seen_paths: set[str] = set()

    with get_db() as conn:
        for path in files:
            result.scanned += 1
            try:
                meta, warns = extract_metadata(path)
                fmt = meta["format"] or path.suffix.lower().lstrip(".")
                result.formats[fmt] = result.formats.get(fmt, 0) + 1
                result.warnings.extend(warns)
                seen_paths.add(meta["path"])
                status = _upsert_song(conn, meta)
                if status == "added":
                    result.added += 1
                elif status == "updated":
                    result.updated += 1
            except Exception as e:
                try:
                    meta = _base_meta(path)
                    meta["tag_ok"] = 0
                    seen_paths.add(meta["path"])
                    status = _upsert_song(conn, meta)
                    if status == "added":
                        result.added += 1
                    result.warnings.append(f"{path.name}: 元数据失败仍入库 — {e}")
                    log.warning("scan soft-fail %s: %s", path, e)
                except Exception as e2:
                    msg = f"{path}: {e2}"
                    log.exception("scan error")
                    result.errors.append(msg)

        rows = conn.execute("SELECT id, path FROM songs").fetchall()
        for row in rows:
            if row["path"] not in seen_paths:
                try:
                    song_path = Path(row["path"]).resolve()
                    under = any(song_path.is_relative_to(root) for root in roots)
                    if under:
                        conn.execute("DELETE FROM songs WHERE id = ?", (row["id"],))
                        result.removed += 1
                except (ValueError, OSError):
                    pass

    return result


def format_needs_transcode(fmt: str, tag_ok: int | None = 1) -> bool:
    ext = f".{fmt.lstrip('.').lower()}"
    if tag_ok == 0:
        return True
    if ext not in BROWSER_NATIVE:
        return True
    # mislabeled containers
    if fmt in ("webm", "mkv", "wma", "ape", "wv"):
        return True
    return False


def guess_media_type(path: Path) -> str:
    # Prefer probe over extension for correct Content-Type
    probed = probe_real_format(path)
    if probed:
        mapping_probe = {
            "mp3": "audio/mpeg",
            "m4a": "audio/mp4",
            "flac": "audio/flac",
            "ogg": "audio/ogg",
            "wav": "audio/wav",
            "wma": "audio/x-ms-wma",
            "webm": "audio/webm",
        }
        if probed in mapping_probe:
            return mapping_probe[probed]

    mime, _ = mimetypes.guess_type(str(path))
    if mime:
        return mime
    ext = path.suffix.lower()
    mapping = {
        ".mp3": "audio/mpeg",
        ".flac": "audio/flac",
        ".m4a": "audio/mp4",
        ".aac": "audio/aac",
        ".ogg": "audio/ogg",
        ".opus": "audio/ogg",
        ".wav": "audio/wav",
        ".wma": "audio/x-ms-wma",
    }
    return mapping.get(ext, "application/octet-stream")
