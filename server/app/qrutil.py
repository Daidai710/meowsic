from __future__ import annotations

from io import BytesIO
from typing import Optional


def make_qr_png(text: str, box_size: int = 8, border: int = 2) -> bytes:
    """Return PNG bytes for QR code. Requires package `qrcode` (+ pillow for PNG)."""
    import qrcode

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border,
    )
    qr.add_data(text)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def make_qr_svg(text: str, box_size: int = 10, border: int = 2) -> str:
    """SVG QR (no Pillow required if qrcode SVG factory works)."""
    import qrcode
    import qrcode.image.svg

    factory = qrcode.image.svg.SvgPathImage
    img = qrcode.make(
        text,
        image_factory=factory,
        box_size=box_size,
        border=border,
    )
    buf = BytesIO()
    img.save(buf)
    return buf.getvalue().decode("utf-8")


def qr_available() -> bool:
    try:
        import qrcode  # noqa: F401

        return True
    except ImportError:
        return False
