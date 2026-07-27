from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
DB_PATH = DATA_DIR / "music.db"
COVERS_DIR = DATA_DIR / "covers"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="MUSIC_HUB_",
        env_file=str(ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Default to a local sample folder under the project; override with env/config.
    library_path: str = str(ROOT / "sample_music")
    host: str = "0.0.0.0"
    port: int = 8787
    ffmpeg_path: Optional[str] = None
    # On-the-fly transcode target when browser can't play the original.
    transcode_bitrate: str = "192k"
    # Max songs returned by list endpoints without pagination intent.
    default_page_size: int = 200
    # Optional access password (also data/access_password.txt). Empty = open LAN.
    password: Optional[str] = None


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    COVERS_DIR.mkdir(parents=True, exist_ok=True)


def get_settings() -> Settings:
    return Settings()


# Common Windows install locations (checked after PATH / env).
_FFMPEG_CANDIDATES = (
    Path(r"D:\Python\ffmpeg-7.1-essentials_build\bin\ffmpeg.exe"),
    Path(r"C:\ffmpeg\bin\ffmpeg.exe"),
    Path(r"D:\ffmpeg\bin\ffmpeg.exe"),
    Path(r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"),
    Path(r"C:\ProgramData\chocolatey\bin\ffmpeg.exe"),
)


def resolve_ffmpeg(settings: Settings) -> Optional[str]:
    """Return ffmpeg executable path if available."""
    # 1) explicit setting / env MUSIC_HUB_FFMPEG_PATH
    if settings.ffmpeg_path:
        p = Path(settings.ffmpeg_path)
        if p.is_file():
            return str(p)

    # 2) runtime file written by setup / first discovery
    runtime = DATA_DIR / "ffmpeg_path.txt"
    if runtime.is_file():
        p = Path(runtime.read_text(encoding="utf-8").strip())
        if p.is_file():
            return str(p)

    # 3) PATH
    for name in ("ffmpeg.exe", "ffmpeg"):
        for folder in os.environ.get("PATH", "").split(os.pathsep):
            candidate = Path(folder) / name
            if candidate.is_file():
                _remember_ffmpeg(candidate)
                return str(candidate)

    # 4) known local paths
    for candidate in _FFMPEG_CANDIDATES:
        if candidate.is_file():
            _remember_ffmpeg(candidate)
            return str(candidate)

    return None


def _remember_ffmpeg(path: Path) -> None:
    try:
        ensure_dirs()
        (DATA_DIR / "ffmpeg_path.txt").write_text(str(path.resolve()), encoding="utf-8")
    except OSError:
        pass
