from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field


class SongOut(BaseModel):
    id: int
    title: str
    artist: str
    album: str
    album_artist: Optional[str] = None
    track: Optional[int] = None
    disc: Optional[int] = None
    year: Optional[int] = None
    genre: Optional[str] = None
    duration: Optional[float] = None
    bitrate: Optional[int] = None
    sample_rate: Optional[int] = None
    format: str
    file_size: Optional[int] = None
    has_cover: bool = False
    needs_transcode: bool = False
    tag_ok: bool = True
    replaygain_db: Optional[float] = None
    stream_url: str
    cover_url: Optional[str] = None


class PlaylistOut(BaseModel):
    id: int
    name: str
    song_count: int = 0
    created_at: Optional[str] = None


class PlaylistCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)


class PlaylistAddSongs(BaseModel):
    song_ids: list[int]


class ScanResponse(BaseModel):
    scanned: int
    added: int
    updated: int
    removed: int
    errors: list[str]
    warnings: list[str] = []
    formats: dict[str, int]


class StatusOut(BaseModel):
    version: str
    library_path: str
    library_paths: list[str] = []
    song_count: int
    playlist_count: int
    ffmpeg: bool
    ffmpeg_path: Optional[str] = None
    formats: dict[str, int]
    lan_ip: Optional[str] = None
    lan_url: Optional[str] = None
    lan_urls: list[str] = []
    port: int = 8787
    auth_required: bool = False
    service: str = "music-hub"


class LanOut(BaseModel):
    ips: list[str]
    urls: list[str]
    primary_url: str
    localhost_url: str
    port: int
    qr_path: str


class LibrarySet(BaseModel):
    path: str


class LibraryPathsOut(BaseModel):
    paths: list[str]
    primary: str = ""


class ApiMessage(BaseModel):
    ok: bool = True
    message: str
    data: Optional[Any] = None
