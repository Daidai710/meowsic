"""
Listen-together (party) rooms: host-controlled playback sync + optional moderators.

In-memory only (personal hub). Clients:
  - REST create/join/list
  - WebSocket /ws/party/{code} for state + control
"""
from __future__ import annotations

import asyncio
import secrets
import string
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Optional

if TYPE_CHECKING:
    from fastapi import WebSocket
else:
    WebSocket = object  # runtime: only stored as opaque socket ref

# Permission keys moderators can be granted
PERM_KEYS = ("skip", "play_pause", "seek", "scene", "queue")

DEFAULT_MOD_PERMS: dict[str, bool] = {
    "skip": True,  # next / prev / pick song if queue perm false still can skip
    "play_pause": False,
    "seek": False,
    "scene": True,  # shared room scene / EQ hint
    "queue": False,  # replace / edit shared queue
}


def _now() -> float:
    return time.time()


def _code(n: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    # avoid ambiguous 0/O I/1
    alphabet = alphabet.replace("0", "").replace("O", "").replace("1", "").replace("I", "")
    return "".join(secrets.choice(alphabet) for _ in range(n))


def _normalize_perms(raw: Any) -> dict[str, bool]:
    base = {k: False for k in PERM_KEYS}
    if not isinstance(raw, dict):
        return base
    for k in PERM_KEYS:
        if k in raw:
            base[k] = bool(raw[k])
    return base


@dataclass
class Member:
    device_id: str
    name: str
    role: str = "guest"  # host | mod | guest
    perms: dict[str, bool] = field(default_factory=lambda: {k: False for k in PERM_KEYS})
    platform: str = ""
    joined_at: float = field(default_factory=_now)
    ws: Optional[WebSocket] = field(default=None, repr=False)

    def public(self) -> dict[str, Any]:
        return {
            "device_id": self.device_id,
            "name": self.name,
            "role": self.role,
            "perms": dict(self.perms) if self.role == "mod" else (
                {k: True for k in PERM_KEYS} if self.role == "host" else {k: False for k in PERM_KEYS}
            ),
            "platform": self.platform,
            "online": self.ws is not None,
            "joined_at": self.joined_at,
        }

    def can(self, action: str) -> bool:
        if self.role == "host":
            return True
        if self.role == "mod":
            # map control actions → perm keys
            key = {
                "play": "play_pause",
                "pause": "play_pause",
                "toggle": "play_pause",
                "seek": "seek",
                "next": "skip",
                "prev": "skip",
                "set_song": "skip",  # jump to song
                "set_queue": "queue",
                "queue_add": "queue",
                "set_scene": "scene",
                "set_speed": "scene",  # speed tied to scene feel
                "host_tick": False,  # only host
                "set_role": False,
                "kick": False,
                "transfer_host": False,
                "close": False,
            }.get(action, action)
            if key is False:
                return False
            if key in PERM_KEYS:
                return bool(self.perms.get(key))
            return False
        return False


@dataclass
class RoomState:
    song_id: Optional[int] = None
    queue: list[int] = field(default_factory=list)
    queue_index: int = -1
    playing: bool = False
    position: float = 0.0  # seconds at server_ts
    server_ts: float = field(default_factory=_now)
    speed: float = 1.0
    scene_id: str = "default"
    updated_by: str = ""

    def snapshot(self) -> dict[str, Any]:
        return {
            "song_id": self.song_id,
            "queue": list(self.queue),
            "queue_index": self.queue_index,
            "playing": self.playing,
            "position": round(self.position, 3),
            "server_ts": self.server_ts,
            "speed": self.speed,
            "scene_id": self.scene_id,
            "updated_by": self.updated_by,
            # Estimated live position if still playing (client can refine with local clock)
            "estimated_position": round(self.estimated_position(), 3),
        }

    def estimated_position(self) -> float:
        if not self.playing:
            return max(0.0, self.position)
        elapsed = (_now() - self.server_ts) * max(0.5, min(2.0, self.speed or 1.0))
        return max(0.0, self.position + elapsed)

    def apply_anchor(self, position: float, playing: Optional[bool] = None, speed: Optional[float] = None) -> None:
        self.position = max(0.0, float(position))
        self.server_ts = _now()
        if playing is not None:
            self.playing = bool(playing)
        if speed is not None:
            self.speed = max(0.5, min(2.0, float(speed)))


@dataclass
class PartyRoom:
    code: str
    host_id: str
    created_at: float = field(default_factory=_now)
    members: dict[str, Member] = field(default_factory=dict)
    state: RoomState = field(default_factory=RoomState)
    lock: asyncio.Lock = field(default_factory=asyncio.Lock, repr=False)

    def public(self, include_members: bool = True) -> dict[str, Any]:
        out: dict[str, Any] = {
            "code": self.code,
            "host_id": self.host_id,
            "created_at": self.created_at,
            "member_count": len(self.members),
            "online_count": sum(1 for m in self.members.values() if m.ws is not None),
            "state": self.state.snapshot(),
        }
        if include_members:
            out["members"] = [m.public() for m in sorted(self.members.values(), key=lambda x: x.joined_at)]
        return out


class PartyManager:
    def __init__(self) -> None:
        self.rooms: dict[str, PartyRoom] = {}
        self._lock = asyncio.Lock()

    async def create(self, device_id: str, name: str, platform: str = "") -> PartyRoom:
        device_id = (device_id or "").strip()[:120]
        if not device_id:
            raise ValueError("device_id required")
        name = (name or "Host").strip()[:80] or "Host"
        async with self._lock:
            for _ in range(20):
                code = _code(6)
                if code not in self.rooms:
                    break
            else:
                raise RuntimeError("could not allocate room code")
            room = PartyRoom(code=code, host_id=device_id)
            room.members[device_id] = Member(
                device_id=device_id,
                name=name,
                role="host",
                perms={k: True for k in PERM_KEYS},
                platform=(platform or "")[:40],
            )
            self.rooms[code] = room
            return room

    def get(self, code: str) -> Optional[PartyRoom]:
        return self.rooms.get((code or "").strip().upper())

    def list_rooms(self) -> list[dict[str, Any]]:
        return [
            r.public(include_members=False)
            for r in sorted(self.rooms.values(), key=lambda x: x.created_at, reverse=True)
        ]

    async def join(self, code: str, device_id: str, name: str, platform: str = "") -> PartyRoom:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        device_id = (device_id or "").strip()[:120]
        if not device_id:
            raise ValueError("device_id required")
        name = (name or "Guest").strip()[:80] or "Guest"
        async with room.lock:
            existing = room.members.get(device_id)
            if existing:
                existing.name = name
                if platform:
                    existing.platform = platform[:40]
                # host reconnect keeps role
            else:
                role = "host" if device_id == room.host_id else "guest"
                room.members[device_id] = Member(
                    device_id=device_id,
                    name=name,
                    role=role,
                    perms={k: True for k in PERM_KEYS} if role == "host" else {k: False for k in PERM_KEYS},
                    platform=(platform or "")[:40],
                )
        return room

    async def leave(self, code: str, device_id: str) -> None:
        room = self.get(code)
        if not room:
            return
        async with room.lock:
            m = room.members.get(device_id)
            if m and m.ws is not None:
                try:
                    await m.ws.close()
                except Exception:
                    pass
                m.ws = None
            if device_id in room.members and device_id != room.host_id:
                del room.members[device_id]
            # host leaving: transfer or close
            if device_id == room.host_id:
                online = [x for x in room.members.values() if x.device_id != device_id and x.ws]
                if online:
                    new_host = online[0]
                    room.host_id = new_host.device_id
                    new_host.role = "host"
                    new_host.perms = {k: True for k in PERM_KEYS}
                    if device_id in room.members:
                        del room.members[device_id]
                else:
                    # dissolve
                    for mem in list(room.members.values()):
                        if mem.ws:
                            try:
                                await mem.ws.close()
                            except Exception:
                                pass
                    self.rooms.pop(room.code, None)
                    return
        await self.broadcast(room.code, {"type": "state", "room": room.public()})

    async def set_role(
        self,
        code: str,
        actor_id: str,
        target_id: str,
        role: str,
        perms: Optional[dict[str, bool]] = None,
    ) -> PartyRoom:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        async with room.lock:
            actor = room.members.get(actor_id)
            if not actor or actor.role != "host":
                raise PermissionError("only host can change roles")
            if target_id == room.host_id:
                raise PermissionError("cannot demote host; transfer first")
            target = room.members.get(target_id)
            if not target:
                raise KeyError("member not found")
            role = (role or "guest").lower()
            if role not in ("guest", "mod"):
                raise ValueError("role must be guest or mod")
            target.role = role
            if role == "mod":
                target.perms = _normalize_perms(perms if perms is not None else DEFAULT_MOD_PERMS)
            else:
                target.perms = {k: False for k in PERM_KEYS}
        await self.broadcast(room.code, {"type": "state", "room": room.public()})
        return room

    async def transfer_host(self, code: str, actor_id: str, target_id: str) -> PartyRoom:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        async with room.lock:
            if actor_id != room.host_id:
                raise PermissionError("only host can transfer")
            target = room.members.get(target_id)
            if not target:
                raise KeyError("member not found")
            old = room.members.get(actor_id)
            room.host_id = target_id
            target.role = "host"
            target.perms = {k: True for k in PERM_KEYS}
            if old:
                old.role = "mod"
                old.perms = dict(DEFAULT_MOD_PERMS)
        await self.broadcast(room.code, {"type": "state", "room": room.public()})
        return room

    async def kick(self, code: str, actor_id: str, target_id: str) -> None:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        async with room.lock:
            actor = room.members.get(actor_id)
            if not actor or actor.role != "host":
                raise PermissionError("only host can kick")
            if target_id == room.host_id:
                raise PermissionError("cannot kick host")
            m = room.members.pop(target_id, None)
            if m and m.ws:
                try:
                    await m.ws.send_json({"type": "kicked", "message": "你已被房主移出房间"})
                    await m.ws.close()
                except Exception:
                    pass
        await self.broadcast(code, {"type": "state", "room": room.public() if self.get(code) else None})

    async def broadcast(self, code: str, message: dict[str, Any]) -> None:
        room = self.get(code)
        if not room:
            return
        dead: list[str] = []
        for mid, m in list(room.members.items()):
            if not m.ws:
                continue
            try:
                await m.ws.send_json(message)
            except Exception:
                dead.append(mid)
        for mid in dead:
            m = room.members.get(mid)
            if m:
                m.ws = None

    async def attach_ws(self, code: str, device_id: str, ws: WebSocket) -> PartyRoom:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        async with room.lock:
            m = room.members.get(device_id)
            if not m:
                raise KeyError("join room first")
            # replace old socket
            if m.ws is not None and m.ws is not ws:
                try:
                    await m.ws.close()
                except Exception:
                    pass
            m.ws = ws
        return room

    def detach_ws(self, code: str, device_id: str, ws: WebSocket) -> None:
        room = self.get(code)
        if not room:
            return
        m = room.members.get(device_id)
        if m and m.ws is ws:
            m.ws = None

    async def apply_control(self, code: str, actor_id: str, msg: dict[str, Any]) -> dict[str, Any]:
        room = self.get(code)
        if not room:
            raise KeyError("room not found")
        action = str(msg.get("action") or "").strip()
        async with room.lock:
            actor = room.members.get(actor_id)
            if not actor:
                raise PermissionError("not a member")
            if not actor.can(action):
                raise PermissionError(f"no permission: {action}")

            st = room.state
            st.updated_by = actor_id

            if action == "play":
                st.apply_anchor(float(msg.get("position", st.estimated_position())), playing=True)
            elif action == "pause":
                st.apply_anchor(float(msg.get("position", st.estimated_position())), playing=False)
            elif action == "toggle":
                pos = float(msg.get("position", st.estimated_position()))
                st.apply_anchor(pos, playing=not st.playing)
            elif action == "seek":
                st.apply_anchor(float(msg.get("position", 0)), playing=st.playing)
            elif action == "set_speed":
                st.apply_anchor(st.estimated_position(), playing=st.playing, speed=float(msg.get("speed", 1)))
            elif action == "set_scene":
                st.scene_id = str(msg.get("scene_id") or "default")[:40]
                st.server_ts = _now()
            elif action == "set_song":
                sid = int(msg["song_id"])
                st.song_id = sid
                if sid not in st.queue:
                    st.queue.append(sid)
                    st.queue_index = len(st.queue) - 1
                else:
                    st.queue_index = st.queue.index(sid)
                pos = float(msg.get("position", 0))
                playing = bool(msg.get("playing", True))
                st.apply_anchor(pos, playing=playing)
            elif action == "set_queue":
                q = msg.get("queue") or []
                st.queue = [int(x) for x in q][:500]
                idx = int(msg.get("queue_index", 0))
                st.queue_index = max(-1, min(idx, len(st.queue) - 1)) if st.queue else -1
                if st.queue_index >= 0:
                    st.song_id = st.queue[st.queue_index]
                pos = float(msg.get("position", 0))
                playing = bool(msg.get("playing", st.playing))
                st.apply_anchor(pos, playing=playing)
            elif action == "queue_add":
                sid = int(msg["song_id"])
                if sid not in st.queue:
                    st.queue.append(sid)
                st.server_ts = _now()
            elif action == "next":
                if st.queue and st.queue_index < len(st.queue) - 1:
                    st.queue_index += 1
                    st.song_id = st.queue[st.queue_index]
                    st.apply_anchor(0.0, playing=True)
                elif st.queue:
                    st.queue_index = 0
                    st.song_id = st.queue[0]
                    st.apply_anchor(0.0, playing=True)
            elif action == "prev":
                if st.queue and st.queue_index > 0:
                    st.queue_index -= 1
                    st.song_id = st.queue[st.queue_index]
                    st.apply_anchor(0.0, playing=True)
                else:
                    st.apply_anchor(0.0, playing=st.playing)
            elif action == "host_tick":
                # host position heartbeat for drift correction
                if actor.role != "host":
                    raise PermissionError("host_tick host only")
                st.apply_anchor(
                    float(msg.get("position", st.position)),
                    playing=bool(msg.get("playing", st.playing)),
                    speed=float(msg.get("speed", st.speed)),
                )
                if msg.get("song_id") is not None:
                    st.song_id = int(msg["song_id"])
            else:
                raise ValueError(f"unknown action: {action}")

            payload = {"type": "state", "room": room.public()}
        await self.broadcast(code, payload)
        return payload


party_manager = PartyManager()
