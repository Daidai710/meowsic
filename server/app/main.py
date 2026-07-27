from __future__ import annotations

import logging
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware

from . import __version__
from .auth import (
    auth_enabled,
    get_or_create_token,
    set_password,
    verify_request,
)
from .config import ROOT, ensure_dirs, get_settings, resolve_ffmpeg
from .db import get_db, init_db
from .fix_media import fix_to_mp3
from .lan import hub_urls, primary_lan_ip
from .lyrics import load_lyrics_for_path
from .party import DEFAULT_MOD_PERMS, PERM_KEYS, party_manager
from .qrutil import make_qr_png, qr_available
from .scanner import extract_metadata, format_needs_transcode, scan_libraries
from .schemas import (
    ApiMessage,
    LanOut,
    LibraryPathsOut,
    LibrarySet,
    PlaylistAddSongs,
    PlaylistCreate,
    PlaylistOut,
    ScanResponse,
    SongOut,
    StatusOut,
)
from .stream import should_transcode, stream_original, stream_transcoded

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("music_hub")

ensure_dirs()
init_db()

# Public OpenAPI/Swagger disabled — personal LAN hub, not a public API product.
app = FastAPI(
    title="meowsic",
    version=__version__,
    description="Personal local music hub (LAN only)",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths that stay open without token (discovery / login / static)
_AUTH_OPEN_PREFIXES = (
    "/api/status",
    "/api/lan",
    "/api/qr.png",
    "/api/auth/",
    # /api/party REST follows normal auth; WS checks token in query if auth on
    "/ws/party",
    "/static",
)


class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if not auth_enabled():
            return await call_next(request)
        if path == "/" or any(path == p or path.startswith(p) for p in _AUTH_OPEN_PREFIXES):
            return await call_next(request)
        token = request.headers.get("x-music-hub-token") or request.query_params.get("token")
        password = request.headers.get("x-music-hub-password") or request.query_params.get("password")
        if verify_request(token, password):
            return await call_next(request)
        return JSONResponse({"detail": "Unauthorized"}, status_code=401)


app.add_middleware(AuthMiddleware)

WEB_DIR = ROOT / "web"


def _effective_libraries() -> list[str]:
    """One or more library roots (multi-folder support)."""
    import json

    multi = ROOT / "data" / "library_paths.json"
    if multi.is_file():
        try:
            raw = json.loads(multi.read_text(encoding="utf-8"))
            if isinstance(raw, list):
                paths = [str(Path(p).expanduser()) for p in raw if str(p).strip()]
                if paths:
                    return paths
        except Exception:
            pass
    runtime = ROOT / "data" / "library_path.txt"
    if runtime.is_file():
        p = runtime.read_text(encoding="utf-8").strip()
        if p:
            return [p]
    return [get_settings().library_path]


def _effective_library() -> str:
    libs = _effective_libraries()
    return libs[0] if libs else get_settings().library_path


def _save_libraries(paths: list[str]) -> list[str]:
    import json

    cleaned: list[str] = []
    seen: set[str] = set()
    for p in paths:
        try:
            r = str(Path(p).expanduser().resolve())
        except OSError:
            r = str(Path(p).expanduser())
        if r in seen:
            continue
        seen.add(r)
        cleaned.append(r)
    ensure_dirs()
    (ROOT / "data" / "library_paths.json").write_text(
        json.dumps(cleaned, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    # keep single-path file for older tools
    if cleaned:
        (ROOT / "data" / "library_path.txt").write_text(cleaned[0], encoding="utf-8")
    return cleaned


def _song_out(row) -> SongOut:
    d = dict(row)
    sid = d["id"]
    fmt = d["format"] or ""
    has_cover = bool(d.get("cover_path"))
    tag_ok = d.get("tag_ok")
    if tag_ok is None:
        tag_ok = 1
    tag_ok_b = bool(int(tag_ok))
    return SongOut(
        id=sid,
        title=d["title"],
        artist=d["artist"],
        album=d["album"],
        album_artist=d.get("album_artist"),
        track=d.get("track"),
        disc=d.get("disc"),
        year=d.get("year"),
        genre=d.get("genre"),
        duration=d.get("duration"),
        bitrate=d.get("bitrate"),
        sample_rate=d.get("sample_rate"),
        format=fmt,
        file_size=d.get("file_size"),
        has_cover=has_cover,
        tag_ok=tag_ok_b,
        needs_transcode=format_needs_transcode(fmt, int(tag_ok)),
        replaygain_db=d.get("replaygain_db"),
        stream_url=f"/api/stream/{sid}",
        cover_url=f"/api/cover/{sid}" if has_cover else None,
    )


def _lan_info() -> dict:
    s = get_settings()
    return hub_urls(s.port)


@app.get("/api/status", response_model=StatusOut)
def status():
    s = get_settings()
    with get_db() as conn:
        song_count = conn.execute("SELECT COUNT(*) AS c FROM songs").fetchone()["c"]
        playlist_count = conn.execute("SELECT COUNT(*) AS c FROM playlists").fetchone()["c"]
        rows = conn.execute("SELECT format, COUNT(*) AS c FROM songs GROUP BY format").fetchall()
        formats = {r["format"]: r["c"] for r in rows}
    ff = resolve_ffmpeg(s)
    lan = _lan_info()
    libs = _effective_libraries()
    return StatusOut(
        version=__version__,
        library_path=libs[0] if libs else _effective_library(),
        library_paths=libs,
        song_count=song_count,
        playlist_count=playlist_count,
        ffmpeg=bool(ff),
        ffmpeg_path=ff,
        formats=formats,
        lan_ip=primary_lan_ip(),
        lan_url=lan["primary_url"],
        lan_urls=lan["urls"],
        port=s.port,
        auth_required=auth_enabled(),
        service="music-hub",
    )


@app.get("/api/lan", response_model=LanOut)
def lan_info():
    info = _lan_info()
    url = info["primary_url"]
    if auth_enabled():
        url = f"{url}/?token={get_or_create_token()}"
    return LanOut(
        ips=info["ips"],
        urls=info["urls"],
        primary_url=url if auth_enabled() else info["primary_url"],
        localhost_url=info["localhost_url"],
        port=info["port"],
        qr_path=f"/api/qr.png?url={info['primary_url']}",
    )


@app.get("/api/auth/status")
def auth_status():
    return {
        "auth_required": auth_enabled(),
        "service": "music-hub",
    }


@app.post("/api/auth/login")
def auth_login(body: dict):
    password = str(body.get("password") or "")
    if not auth_enabled():
        return {"ok": True, "token": None, "auth_required": False}
    if verify_request(None, password):
        return {"ok": True, "token": get_or_create_token(), "auth_required": True}
    raise HTTPException(401, "Bad password")


@app.post("/api/auth/set-password", response_model=ApiMessage)
def auth_set_password(body: dict):
    """Set/clear password. Requires current password if auth already on."""
    new_pw = str(body.get("password") or "")
    current = body.get("current_password")
    if auth_enabled() and not verify_request(body.get("token"), current):
        raise HTTPException(401, "Current password/token required")
    token = set_password(new_pw)
    return ApiMessage(
        message="password cleared" if not new_pw else "password set",
        data={"auth_required": auth_enabled(), "token": token or None},
    )


# ---------- B2 devices ----------


@app.post("/api/devices/heartbeat")
def device_heartbeat(body: dict):
    device_id = str(body.get("device_id") or "").strip()[:120]
    if not device_id:
        raise HTTPException(400, "device_id required")
    name = str(body.get("name") or "Device")[:80]
    platform = str(body.get("platform") or "")[:40]
    with get_db() as conn:
        row = conn.execute("SELECT kicked FROM devices WHERE device_id = ?", (device_id,)).fetchone()
        if row and int(row["kicked"] or 0) == 1:
            return {"ok": False, "kicked": True, "message": "device kicked"}
        conn.execute(
            """
            INSERT INTO devices (device_id, name, platform, last_seen, kicked)
            VALUES (?, ?, ?, datetime('now'), 0)
            ON CONFLICT(device_id) DO UPDATE SET
                name = excluded.name,
                platform = excluded.platform,
                last_seen = datetime('now'),
                kicked = 0,
                kicked_at = NULL
            """,
            (device_id, name, platform),
        )
    return {"ok": True, "kicked": False}


@app.get("/api/devices")
def list_devices(active_seconds: int = Query(90, ge=15, le=600)):
    """Online = last_seen within active_seconds."""
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT device_id, name, platform, last_seen, kicked, kicked_at,
                   CASE WHEN kicked = 1 THEN 0
                        WHEN datetime(last_seen) >= datetime('now', ?) THEN 1
                        ELSE 0 END AS online
            FROM devices
            ORDER BY last_seen DESC
            LIMIT 100
            """,
            (f"-{int(active_seconds)} seconds",),
        ).fetchall()
    return [dict(r) for r in rows]


@app.post("/api/devices/{device_id}/kick", response_model=ApiMessage)
def kick_device(device_id: str):
    with get_db() as conn:
        cur = conn.execute(
            """
            UPDATE devices SET kicked = 1, kicked_at = datetime('now')
            WHERE device_id = ?
            """,
            (device_id[:120],),
        )
        if cur.rowcount == 0:
            # still record kick for unknown id
            conn.execute(
                """
                INSERT INTO devices (device_id, name, platform, last_seen, kicked, kicked_at)
                VALUES (?, 'unknown', '', datetime('now'), 1, datetime('now'))
                ON CONFLICT(device_id) DO UPDATE SET kicked = 1, kicked_at = datetime('now')
                """,
                (device_id[:120],),
            )
    return ApiMessage(message="kicked")


@app.post("/api/devices/{device_id}/unkick", response_model=ApiMessage)
def unkick_device(device_id: str):
    with get_db() as conn:
        conn.execute(
            "UPDATE devices SET kicked = 0, kicked_at = NULL WHERE device_id = ?",
            (device_id[:120],),
        )
    return ApiMessage(message="unkicked")


@app.get("/api/qr.png")
def qr_png(
    url: Optional[str] = Query(None, description="URL to encode; default = LAN hub URL"),
):
    """PNG QR for phone camera — open on PC, scan with phone."""
    if not qr_available():
        raise HTTPException(
            501,
            "QR dependency missing. Run: pip install 'qrcode[pil]'",
        )
    target = (url or "").strip() or _lan_info()["primary_url"]
    # Only allow encoding our hub-like http URLs (avoid open redirect abuse)
    if not (target.startswith("http://") or target.startswith("https://")):
        raise HTTPException(400, "url must start with http:// or https://")
    if len(target) > 512:
        raise HTTPException(400, "url too long")
    try:
        png = make_qr_png(target, box_size=8, border=2)
    except Exception as e:
        raise HTTPException(500, f"QR generate failed: {e}") from e
    return Response(
        content=png,
        media_type="image/png",
        headers={
            "Cache-Control": "no-store",
            "X-QR-URL": target,
        },
    )


@app.post("/api/library", response_model=ApiMessage)
def set_library(body: LibrarySet):
    """Replace library list with a single path (web / legacy)."""
    import os

    path = Path(body.path).expanduser()
    if not path.is_dir():
        raise HTTPException(400, f"Not a directory: {path}")
    resolved = str(path.resolve())
    _save_libraries([resolved])
    os.environ["MUSIC_HUB_LIBRARY_PATH"] = resolved
    return ApiMessage(message=f"Library path set to {resolved}")


@app.get("/api/libraries", response_model=LibraryPathsOut)
def list_libraries():
    paths = _effective_libraries()
    return LibraryPathsOut(paths=paths, primary=paths[0] if paths else "")


@app.post("/api/libraries", response_model=LibraryPathsOut)
def add_library(body: LibrarySet):
    path = Path(body.path).expanduser()
    if not path.is_dir():
        raise HTTPException(400, f"Not a directory: {path}")
    resolved = str(path.resolve())
    paths = _effective_libraries()
    if resolved not in paths:
        paths.append(resolved)
    paths = _save_libraries(paths)
    return LibraryPathsOut(paths=paths, primary=paths[0] if paths else "")


@app.delete("/api/libraries", response_model=LibraryPathsOut)
def remove_library(body: LibrarySet):
    target = str(Path(body.path).expanduser().resolve())
    paths = [p for p in _effective_libraries() if str(Path(p).resolve()) != target and p != body.path]
    if not paths:
        raise HTTPException(400, "至少保留一个曲库目录")
    paths = _save_libraries(paths)
    return LibraryPathsOut(paths=paths, primary=paths[0] if paths else "")


@app.post("/api/scan", response_model=ScanResponse)
def scan():
    libs = _effective_libraries()
    log.info("Scanning libraries: %s", libs)
    result = scan_libraries(libs)
    return ScanResponse(
        scanned=result.scanned,
        added=result.added,
        updated=result.updated,
        removed=result.removed,
        errors=result.errors[:50],
        warnings=result.warnings[:80],
        formats=result.formats,
    )


@app.get("/api/songs", response_model=list[SongOut])
def list_songs(
    q: Optional[str] = None,
    artist: Optional[str] = None,
    album: Optional[str] = None,
    limit: int = Query(5000, ge=1, le=100000),
    offset: int = Query(0, ge=0),
):
    sql = "SELECT * FROM songs WHERE 1=1"
    params: list = []
    if q:
        sql += " AND (title LIKE ? OR artist LIKE ? OR album LIKE ?)"
        like = f"%{q}%"
        params.extend([like, like, like])
    if artist:
        sql += " AND artist = ?"
        params.append(artist)
    if album:
        sql += " AND album = ?"
        params.append(album)
    sql += " ORDER BY artist COLLATE NOCASE, album COLLATE NOCASE, track, title COLLATE NOCASE"
    sql += " LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    with get_db() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [_song_out(r) for r in rows]


@app.get("/api/songs/{song_id}", response_model=SongOut)
def get_song(song_id: int):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM songs WHERE id = ?", (song_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Song not found")
    return _song_out(row)


@app.get("/api/artists")
def list_artists():
    with get_db() as conn:
        rows = conn.execute(
            "SELECT artist, COUNT(*) AS count FROM songs GROUP BY artist ORDER BY artist COLLATE NOCASE"
        ).fetchall()
    return [dict(r) for r in rows]


@app.get("/api/albums")
def list_albums(artist: Optional[str] = None):
    sql = "SELECT album, artist, COUNT(*) AS count FROM songs WHERE 1=1"
    params: list = []
    if artist:
        sql += " AND artist = ?"
        params.append(artist)
    sql += " GROUP BY album, artist ORDER BY artist COLLATE NOCASE, album COLLATE NOCASE"
    with get_db() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


@app.get("/api/cover/{song_id}")
def cover(song_id: int):
    with get_db() as conn:
        row = conn.execute("SELECT cover_path FROM songs WHERE id = ?", (song_id,)).fetchone()
    if not row or not row["cover_path"]:
        raise HTTPException(404, "No cover")
    path = Path(row["cover_path"])
    if not path.is_file():
        raise HTTPException(404, "Cover file missing")
    media = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    return FileResponse(path, media_type=media, headers={"Cache-Control": "public, max-age=86400"})


@app.get("/api/stream/{song_id}")
async def stream(
    song_id: int,
    request: Request,
    transcode: bool = False,
    record: bool = True,
    device: Optional[str] = None,
):
    s = get_settings()
    with get_db() as conn:
        row = conn.execute("SELECT * FROM songs WHERE id = ?", (song_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Song not found")
        # Record play only for initial request (not every Range chunk)
        # Clients may send Range; only count when no Range or bytes=0-
        range_h = request.headers.get("range") or ""
        if record and (not range_h or range_h.startswith("bytes=0-") or range_h == "bytes=0-"):
            try:
                conn.execute(
                    "INSERT INTO play_history (song_id, device) VALUES (?, ?)",
                    (song_id, (device or "")[:80]),
                )
            except Exception:
                pass
    path = Path(row["path"])
    fmt = row["format"] or path.suffix.lstrip(".")
    tag_ok = row["tag_ok"] if "tag_ok" in row.keys() else 1
    if tag_ok is None:
        tag_ok = 1
    # Broken / mislabeled MPEG → prefer ffmpeg when available
    force = bool(transcode) or int(tag_ok) == 0
    if should_transcode(fmt, force=force):
        try:
            return await stream_transcoded(path, s)
        except HTTPException as e:
            if e.status_code == 501 and not force:
                raise
            # No ffmpeg: fall back to original bytes (browser may still play some files)
            if e.status_code == 501:
                return stream_original(path, request)
            raise
    return stream_original(path, request)


@app.get("/api/recent", response_model=list[SongOut])
def recent_plays(limit: int = Query(50, ge=1, le=200)):
    """Recently played songs (unique, newest first)."""
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT s.* FROM songs s
            INNER JOIN (
                SELECT song_id, MAX(played_at) AS last_played
                FROM play_history
                GROUP BY song_id
            ) h ON h.song_id = s.id
            ORDER BY h.last_played DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()
    return [_song_out(r) for r in rows]


@app.post("/api/recent/{song_id}", response_model=ApiMessage)
def record_play(song_id: int, device: Optional[str] = None):
    with get_db() as conn:
        row = conn.execute("SELECT id FROM songs WHERE id = ?", (song_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Song not found")
        conn.execute(
            "INSERT INTO play_history (song_id, device) VALUES (?, ?)",
            (song_id, (device or "")[:80]),
        )
    return ApiMessage(message="ok")


@app.get("/api/progress/{device_id}")
def get_progress(device_id: str):
    with get_db() as conn:
        row = conn.execute(
            "SELECT song_id, position, updated_at, device_id FROM playback_progress WHERE device_id = ?",
            (device_id[:120],),
        ).fetchone()
        if not row:
            return {"song_id": None, "position": 0, "updated_at": None, "device_id": device_id, "song": None}
        song = conn.execute("SELECT * FROM songs WHERE id = ?", (row["song_id"],)).fetchone()
    out = dict(row)
    out["song"] = _song_out(song) if song else None
    return out


@app.get("/api/progress-latest")
def get_progress_latest(exclude_device: Optional[str] = None):
    """Most recently updated progress (for multi-device resume)."""
    with get_db() as conn:
        if exclude_device:
            row = conn.execute(
                """
                SELECT song_id, position, updated_at, device_id FROM playback_progress
                WHERE device_id != ?
                ORDER BY updated_at DESC LIMIT 1
                """,
                (exclude_device[:120],),
            ).fetchone()
        else:
            row = conn.execute(
                """
                SELECT song_id, position, updated_at, device_id FROM playback_progress
                ORDER BY updated_at DESC LIMIT 1
                """
            ).fetchone()
        if not row:
            return {"song_id": None, "position": 0, "updated_at": None, "device_id": None, "song": None}
        song = conn.execute("SELECT * FROM songs WHERE id = ?", (row["song_id"],)).fetchone()
    out = dict(row)
    out["song"] = _song_out(song) if song else None
    return out


@app.post("/api/progress", response_model=ApiMessage)
def set_progress(body: dict):
    device_id = str(body.get("device_id") or "default")[:120]
    song_id = body.get("song_id")
    position = float(body.get("position") or 0)
    if not song_id:
        raise HTTPException(400, "song_id required")
    with get_db() as conn:
        exists = conn.execute("SELECT id FROM songs WHERE id = ?", (int(song_id),)).fetchone()
        if not exists:
            raise HTTPException(404, "Song not found")
        conn.execute(
            """
            INSERT INTO playback_progress (device_id, song_id, position, updated_at)
            VALUES (?, ?, ?, datetime('now'))
            ON CONFLICT(device_id) DO UPDATE SET
                song_id = excluded.song_id,
                position = excluded.position,
                updated_at = datetime('now')
            """,
            (device_id, int(song_id), position),
        )
    return ApiMessage(message="ok")


@app.get("/api/lyrics/{song_id}")
def get_lyrics(song_id: int):
    with get_db() as conn:
        row = conn.execute("SELECT path FROM songs WHERE id = ?", (song_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Song not found")
    data = load_lyrics_for_path(Path(row["path"]))
    data["song_id"] = song_id
    return data


@app.get("/api/songs-broken", response_model=list[SongOut])
def list_broken_songs(limit: int = Query(200, ge=1, le=2000)):
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM songs WHERE tag_ok = 0 ORDER BY title COLLATE NOCASE LIMIT ?",
            (limit,),
        ).fetchall()
    return [_song_out(r) for r in rows]


@app.post("/api/songs/{song_id}/fix", response_model=ApiMessage)
def fix_song(song_id: int):
    """C2: re-encode broken/unsupported file to mp3 via FFmpeg, re-index."""
    s = get_settings()
    with get_db() as conn:
        row = conn.execute("SELECT * FROM songs WHERE id = ?", (song_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Song not found")
    src = Path(row["path"])
    try:
        out = fix_to_mp3(src, s)
    except Exception as e:
        raise HTTPException(500, f"Fix failed: {e}") from e
    # re-scan metadata for this file
    try:
        meta, _warns = extract_metadata(out)
        meta["tag_ok"] = 1
        with get_db() as conn:
            # if path changed, update row
            conn.execute(
                """
                UPDATE songs SET path=?, title=?, artist=?, album=?, format=?, duration=?,
                    bitrate=?, sample_rate=?, file_size=?, mtime=?, cover_path=?, tag_ok=1,
                    updated_at=datetime('now')
                WHERE id=?
                """,
                (
                    meta["path"],
                    meta["title"],
                    meta["artist"],
                    meta["album"],
                    meta["format"],
                    meta["duration"],
                    meta["bitrate"],
                    meta["sample_rate"],
                    meta["file_size"],
                    meta["mtime"],
                    meta.get("cover_path"),
                    song_id,
                ),
            )
    except Exception as e:
        raise HTTPException(500, f"Fixed file but reindex failed: {e}") from e
    return ApiMessage(message=f"Fixed -> {out}", data={"path": str(out)})


# ---------- Playlists ----------


@app.get("/api/playlists", response_model=list[PlaylistOut])
def list_playlists():
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT p.id, p.name, p.created_at,
                   (SELECT COUNT(*) FROM playlist_songs ps WHERE ps.playlist_id = p.id) AS song_count
            FROM playlists p
            ORDER BY p.name COLLATE NOCASE
            """
        ).fetchall()
    return [
        PlaylistOut(id=r["id"], name=r["name"], song_count=r["song_count"], created_at=r["created_at"])
        for r in rows
    ]


@app.post("/api/playlists", response_model=PlaylistOut)
def create_playlist(body: PlaylistCreate):
    name = body.name.strip()
    if not name:
        raise HTTPException(400, "Empty name")
    with get_db() as conn:
        try:
            cur = conn.execute("INSERT INTO playlists (name) VALUES (?)", (name,))
            pid = cur.lastrowid
        except Exception:
            raise HTTPException(409, "Playlist already exists")
        row = conn.execute(
            "SELECT id, name, created_at FROM playlists WHERE id = ?", (pid,)
        ).fetchone()
    return PlaylistOut(id=row["id"], name=row["name"], song_count=0, created_at=row["created_at"])


@app.delete("/api/playlists/{playlist_id}", response_model=ApiMessage)
def delete_playlist(playlist_id: int):
    with get_db() as conn:
        cur = conn.execute("DELETE FROM playlists WHERE id = ?", (playlist_id,))
        if cur.rowcount == 0:
            raise HTTPException(404, "Playlist not found")
    return ApiMessage(message="Deleted")


@app.get("/api/playlists/{playlist_id}/songs", response_model=list[SongOut])
def playlist_songs(playlist_id: int):
    with get_db() as conn:
        pl = conn.execute("SELECT id FROM playlists WHERE id = ?", (playlist_id,)).fetchone()
        if not pl:
            raise HTTPException(404, "Playlist not found")
        rows = conn.execute(
            """
            SELECT s.* FROM songs s
            JOIN playlist_songs ps ON ps.song_id = s.id
            WHERE ps.playlist_id = ?
            ORDER BY ps.position, s.title COLLATE NOCASE
            """,
            (playlist_id,),
        ).fetchall()
    return [_song_out(r) for r in rows]


@app.post("/api/playlists/{playlist_id}/songs", response_model=ApiMessage)
def add_to_playlist(playlist_id: int, body: PlaylistAddSongs):
    with get_db() as conn:
        pl = conn.execute("SELECT id FROM playlists WHERE id = ?", (playlist_id,)).fetchone()
        if not pl:
            raise HTTPException(404, "Playlist not found")
        pos_row = conn.execute(
            "SELECT COALESCE(MAX(position), 0) AS m FROM playlist_songs WHERE playlist_id = ?",
            (playlist_id,),
        ).fetchone()
        pos = pos_row["m"]
        added = 0
        for sid in body.song_ids:
            exists = conn.execute("SELECT id FROM songs WHERE id = ?", (sid,)).fetchone()
            if not exists:
                continue
            pos += 1
            try:
                conn.execute(
                    "INSERT OR IGNORE INTO playlist_songs (playlist_id, song_id, position) VALUES (?, ?, ?)",
                    (playlist_id, sid, pos),
                )
                added += 1
            except Exception:
                pass
    return ApiMessage(message=f"Added {added} song(s)")


@app.delete("/api/playlists/{playlist_id}/songs/{song_id}", response_model=ApiMessage)
def remove_from_playlist(playlist_id: int, song_id: int):
    with get_db() as conn:
        conn.execute(
            "DELETE FROM playlist_songs WHERE playlist_id = ? AND song_id = ?",
            (playlist_id, song_id),
        )
    return ApiMessage(message="Removed")


# ---------- Party / listen-together ----------


@app.get("/api/party/meta")
def party_meta():
    """Permission keys + default moderator grants (for UI)."""
    return {
        "perm_keys": list(PERM_KEYS),
        "perm_labels": {
            "skip": "切歌 / 点歌",
            "play_pause": "播放 / 暂停",
            "seek": "拖动进度",
            "scene": "房间场景 / EQ 提示",
            "queue": "改队列",
        },
        "default_mod_perms": dict(DEFAULT_MOD_PERMS),
    }


@app.get("/api/party")
def party_list():
    return {"rooms": party_manager.list_rooms()}


@app.post("/api/party/create")
async def party_create(body: dict):
    try:
        room = await party_manager.create(
            device_id=str(body.get("device_id") or ""),
            name=str(body.get("name") or "Host"),
            platform=str(body.get("platform") or ""),
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    except RuntimeError as e:
        raise HTTPException(500, str(e)) from e
    return {"ok": True, "room": room.public()}


@app.post("/api/party/join")
async def party_join(body: dict):
    code = str(body.get("code") or "").strip().upper()
    try:
        room = await party_manager.join(
            code=code,
            device_id=str(body.get("device_id") or ""),
            name=str(body.get("name") or "Guest"),
            platform=str(body.get("platform") or ""),
        )
    except KeyError:
        raise HTTPException(404, "房间不存在或已解散") from None
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    await party_manager.broadcast(room.code, {"type": "state", "room": room.public()})
    return {"ok": True, "room": room.public()}


@app.get("/api/party/{code}")
def party_get(code: str):
    room = party_manager.get(code)
    if not room:
        raise HTTPException(404, "房间不存在")
    return room.public()


@app.post("/api/party/{code}/leave")
async def party_leave(code: str, body: dict):
    await party_manager.leave(code, str(body.get("device_id") or ""))
    return {"ok": True}


@app.post("/api/party/{code}/role")
async def party_set_role(code: str, body: dict):
    try:
        room = await party_manager.set_role(
            code=code,
            actor_id=str(body.get("actor_id") or body.get("device_id") or ""),
            target_id=str(body.get("target_id") or ""),
            role=str(body.get("role") or "guest"),
            perms=body.get("perms"),
        )
    except KeyError as e:
        raise HTTPException(404, str(e)) from e
    except PermissionError as e:
        raise HTTPException(403, str(e)) from e
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    return {"ok": True, "room": room.public()}


@app.post("/api/party/{code}/transfer")
async def party_transfer(code: str, body: dict):
    try:
        room = await party_manager.transfer_host(
            code=code,
            actor_id=str(body.get("actor_id") or body.get("device_id") or ""),
            target_id=str(body.get("target_id") or ""),
        )
    except KeyError as e:
        raise HTTPException(404, str(e)) from e
    except PermissionError as e:
        raise HTTPException(403, str(e)) from e
    return {"ok": True, "room": room.public()}


@app.post("/api/party/{code}/kick")
async def party_kick(code: str, body: dict):
    try:
        await party_manager.kick(
            code=code,
            actor_id=str(body.get("actor_id") or body.get("device_id") or ""),
            target_id=str(body.get("target_id") or ""),
        )
    except KeyError as e:
        raise HTTPException(404, str(e)) from e
    except PermissionError as e:
        raise HTTPException(403, str(e)) from e
    return {"ok": True}


@app.websocket("/ws/party/{code}")
async def party_ws(websocket: WebSocket, code: str):
    """
    Query: device_id (required), token/password optional if hub auth on.
    Client messages:
      {type: control, action, ...}
      {type: set_role, target_id, role, perms}
      {type: kick, target_id}
      {type: transfer_host, target_id}
      {type: leave}
      {type: ping}
    Server: {type: state|error|kicked|pong|hello}
    """
    q = websocket.query_params
    device_id = (q.get("device_id") or "").strip()
    if auth_enabled():
        token = q.get("token") or websocket.headers.get("x-music-hub-token")
        password = q.get("password") or websocket.headers.get("x-music-hub-password")
        if not verify_request(token, password):
            await websocket.close(code=4401)
            return
    if not device_id:
        await websocket.close(code=4400)
        return

    room = party_manager.get(code)
    if not room or device_id not in room.members:
        await websocket.close(code=4404)
        return

    await websocket.accept()
    try:
        await party_manager.attach_ws(code, device_id, websocket)
        room = party_manager.get(code)
        if room:
            await websocket.send_json(
                {
                    "type": "hello",
                    "server_ts": __import__("time").time(),
                    "room": room.public(),
                    "you": room.members[device_id].public() if device_id in room.members else None,
                    "perm_keys": list(PERM_KEYS),
                    "default_mod_perms": dict(DEFAULT_MOD_PERMS),
                }
            )
            await party_manager.broadcast(code, {"type": "state", "room": room.public()})

        while True:
            raw = await websocket.receive_json()
            if not isinstance(raw, dict):
                continue
            typ = str(raw.get("type") or "")
            try:
                if typ == "ping":
                    await websocket.send_json({"type": "pong", "server_ts": __import__("time").time()})
                elif typ == "leave":
                    await party_manager.leave(code, device_id)
                    break
                elif typ == "control":
                    await party_manager.apply_control(code, device_id, raw)
                elif typ == "set_role":
                    await party_manager.set_role(
                        code,
                        device_id,
                        str(raw.get("target_id") or ""),
                        str(raw.get("role") or "guest"),
                        raw.get("perms"),
                    )
                elif typ == "kick":
                    await party_manager.kick(code, device_id, str(raw.get("target_id") or ""))
                elif typ == "transfer_host":
                    await party_manager.transfer_host(code, device_id, str(raw.get("target_id") or ""))
                else:
                    await websocket.send_json({"type": "error", "message": f"unknown type: {typ}"})
            except PermissionError as e:
                await websocket.send_json({"type": "error", "message": str(e)})
            except KeyError as e:
                await websocket.send_json({"type": "error", "message": str(e)})
            except Exception as e:
                log.exception("party ws control error")
                await websocket.send_json({"type": "error", "message": str(e)})
    except WebSocketDisconnect:
        pass
    except Exception:
        log.exception("party ws error")
    finally:
        party_manager.detach_ws(code, device_id, websocket)
        room = party_manager.get(code)
        if room:
            await party_manager.broadcast(code, {"type": "state", "room": room.public()})


# ---------- Static web UI ----------

if WEB_DIR.is_dir():
    app.mount("/static", StaticFiles(directory=str(WEB_DIR)), name="static")


@app.get("/")
def index():
    index_path = WEB_DIR / "index.html"
    if not index_path.is_file():
        return {"message": "meowsic server is running. Web UI not found (server/web)."}
    return FileResponse(index_path)


def run():
    import uvicorn

    s = get_settings()
    uvicorn.run("app.main:app", host=s.host, port=s.port, reload=False)


if __name__ == "__main__":
    run()
