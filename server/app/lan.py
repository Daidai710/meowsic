from __future__ import annotations

import socket
from typing import Optional


def _score_ip(ip: str) -> int:
    """Higher = more likely a usable Wi‑Fi / LAN address for phones."""
    if ip.startswith("127.") or ip.startswith("0."):
        return -100
    if ip.startswith("169.254."):  # link-local
        return -50
    if ip.startswith("192.168."):
        return 100
    if ip.startswith("10."):
        return 90
    parts = ip.split(".")
    if len(parts) == 4 and parts[0] == "172":
        try:
            second = int(parts[1])
            if 16 <= second <= 31:
                return 80
        except ValueError:
            pass
    return 10


def list_lan_ipv4() -> list[str]:
    found: set[str] = set()

    # 1) UDP connect trick — usually the interface used for internet / default route
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.3)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        if ip:
            found.add(ip)
    except OSError:
        pass

    # 2) hostname resolution
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM):
            ip = info[4][0]
            if ip:
                found.add(ip)
    except OSError:
        pass

    # 3) connect to local broadcast-ish (Windows sometimes needs this)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.168.0.1", 1))
        ip = s.getsockname()[0]
        s.close()
        if ip:
            found.add(ip)
    except OSError:
        pass

    ranked = sorted(found, key=lambda x: (-_score_ip(x), x))
    return [ip for ip in ranked if _score_ip(ip) > 0]


def primary_lan_ip() -> Optional[str]:
    ips = list_lan_ipv4()
    return ips[0] if ips else None


def hub_urls(port: int) -> dict:
    ips = list_lan_ipv4()
    urls = [f"http://{ip}:{port}" for ip in ips]
    primary = urls[0] if urls else f"http://127.0.0.1:{port}"
    return {
        "ips": ips,
        "urls": urls,
        "primary_url": primary,
        "port": port,
        "localhost_url": f"http://127.0.0.1:{port}",
    }
