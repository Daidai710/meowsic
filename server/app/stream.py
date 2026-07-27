from __future__ import annotations

import asyncio
import logging
import shutil
import subprocess
from pathlib import Path
from typing import AsyncIterator, Optional

from fastapi import HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse

from .config import Settings, resolve_ffmpeg
from .scanner import format_needs_transcode, guess_media_type

log = logging.getLogger("music_hub.stream")


def parse_range(range_header: Optional[str], file_size: int) -> tuple[int, int]:
    """Return (start, end) inclusive."""
    if not range_header or not range_header.startswith("bytes="):
        return 0, file_size - 1
    try:
        unit = range_header.replace("bytes=", "").strip()
        if "," in unit:
            unit = unit.split(",", 1)[0]
        start_s, _, end_s = unit.partition("-")
        if start_s == "":
            # suffix: bytes=-500
            length = int(end_s)
            start = max(0, file_size - length)
            end = file_size - 1
        else:
            start = int(start_s)
            end = int(end_s) if end_s else file_size - 1
        start = max(0, min(start, file_size - 1))
        end = max(start, min(end, file_size - 1))
        return start, end
    except ValueError:
        return 0, file_size - 1


async def file_chunk_iter(path: Path, start: int, end: int, chunk_size: int = 64 * 1024) -> AsyncIterator[bytes]:
    loop = asyncio.get_event_loop()

    def read_chunk(pos: int, size: int) -> bytes:
        with path.open("rb") as f:
            f.seek(pos)
            return f.read(size)

    pos = start
    while pos <= end:
        to_read = min(chunk_size, end - pos + 1)
        data = await loop.run_in_executor(None, read_chunk, pos, to_read)
        if not data:
            break
        pos += len(data)
        yield data


def stream_original(path: Path, request: Request) -> FileResponse | StreamingResponse:
    if not path.is_file():
        raise HTTPException(404, "Audio file missing on disk")

    file_size = path.stat().st_size
    media_type = guess_media_type(path)
    range_header = request.headers.get("range")

    if not range_header:
        return FileResponse(
            path,
            media_type=media_type,
            filename=path.name,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Cache-Control": "public, max-age=3600",
            },
        )

    start, end = parse_range(range_header, file_size)
    length = end - start + 1
    headers = {
        "Content-Range": f"bytes {start}-{end}/{file_size}",
        "Accept-Ranges": "bytes",
        "Content-Length": str(length),
        "Cache-Control": "public, max-age=3600",
    }
    return StreamingResponse(
        file_chunk_iter(path, start, end),
        status_code=206,
        media_type=media_type,
        headers=headers,
    )


async def stream_transcoded(
    path: Path,
    settings: Settings,
    fmt_out: str = "mp3",
) -> StreamingResponse:
    ffmpeg = resolve_ffmpeg(settings)
    if not ffmpeg:
        raise HTTPException(
            501,
            "This format needs FFmpeg transcoding, but FFmpeg is not installed. "
            "Install FFmpeg and set MUSIC_HUB_FFMPEG_PATH, or convert the file to mp3/flac/m4a.",
        )

    if not path.is_file():
        raise HTTPException(404, "Audio file missing on disk")

    # Stream ffmpeg stdout as mp3/aac
    if fmt_out == "aac":
        media_type = "audio/aac"
        args = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-vn",
            "-c:a",
            "aac",
            "-b:a",
            settings.transcode_bitrate,
            "-f",
            "adts",
            "pipe:1",
        ]
    else:
        media_type = "audio/mpeg"
        args = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-vn",
            "-c:a",
            "libmp3lame",
            "-b:a",
            settings.transcode_bitrate,
            "-f",
            "mp3",
            "pipe:1",
        ]

    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError:
        raise HTTPException(501, "FFmpeg executable not found")

    async def gen() -> AsyncIterator[bytes]:
        assert proc.stdout is not None
        try:
            while True:
                chunk = await proc.stdout.read(64 * 1024)
                if not chunk:
                    break
                yield chunk
        finally:
            if proc.returncode is None:
                proc.kill()
                await proc.wait()

    return StreamingResponse(
        gen(),
        media_type=media_type,
        headers={
            "Cache-Control": "no-cache",
            "X-Transcoded": "1",
        },
    )


def should_transcode(fmt: str, force: bool = False) -> bool:
    if force:
        return True
    return format_needs_transcode(fmt, tag_ok=1)


def ffmpeg_available(settings: Settings) -> bool:
    return resolve_ffmpeg(settings) is not None or shutil.which("ffmpeg") is not None
