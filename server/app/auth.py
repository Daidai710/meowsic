from __future__ import annotations

import hashlib
import secrets
from pathlib import Path
from typing import Optional

from .config import DATA_DIR, ensure_dirs, get_settings


def _password_file() -> Path:
    return DATA_DIR / "access_password.txt"


def _token_file() -> Path:
    return DATA_DIR / "access_token.txt"


def get_configured_password() -> Optional[str]:
    """Password from env MUSIC_HUB_PASSWORD or data/access_password.txt."""
    s = get_settings()
    env_pw = getattr(s, "password", None) or None
    if env_pw:
        return str(env_pw).strip() or None
    ensure_dirs()
    pf = _password_file()
    if pf.is_file():
        pw = pf.read_text(encoding="utf-8").strip()
        return pw or None
    return None


def auth_enabled() -> bool:
    return bool(get_configured_password())


def get_or_create_token() -> str:
    ensure_dirs()
    tf = _token_file()
    if tf.is_file():
        t = tf.read_text(encoding="utf-8").strip()
        if t:
            return t
    # derive stable token from password, or random
    pw = get_configured_password()
    if pw:
        t = hashlib.sha256(f"music-hub:{pw}".encode("utf-8")).hexdigest()[:32]
    else:
        t = secrets.token_hex(16)
    tf.write_text(t, encoding="utf-8")
    return t


def set_password(password: str) -> str:
    ensure_dirs()
    password = password.strip()
    if not password:
        # clear auth
        for f in (_password_file(), _token_file()):
            if f.is_file():
                f.unlink()
        return ""
    _password_file().write_text(password, encoding="utf-8")
    # refresh token
    if _token_file().is_file():
        _token_file().unlink()
    return get_or_create_token()


def verify_request(token: Optional[str], password: Optional[str]) -> bool:
    if not auth_enabled():
        return True
    expected = get_or_create_token()
    if token and secrets.compare_digest(str(token), expected):
        return True
    pw = get_configured_password()
    if password and pw and secrets.compare_digest(str(password), pw):
        return True
    return False
