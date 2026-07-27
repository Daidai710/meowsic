/**
 * Listen-together client (WebSocket + REST).
 * Depends on app.js helpers when loaded after app.js patterns; self-contained API.
 */
(function (global) {
  "use strict";

  const PERM_LABELS = {
    skip: "切歌 / 点歌",
    play_pause: "播放 / 暂停",
    seek: "拖动进度",
    scene: "房间场景 / EQ",
    queue: "改队列",
  };

  function deviceId() {
    try {
      let id = localStorage.getItem("mh_device_id");
      if (!id) {
        id = "web_" + Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
        localStorage.setItem("mh_device_id", id);
      }
      return id;
    } catch (_) {
      return "web_anon";
    }
  }

  function deviceName() {
    try {
      return localStorage.getItem("mh_device_name") || "网页";
    } catch (_) {
      return "网页";
    }
  }

  function wsUrl(code, token) {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    const q = new URLSearchParams({ device_id: deviceId() });
    if (token) q.set("token", token);
    return `${proto}//${location.host}/ws/party/${encodeURIComponent(code)}?${q}`;
  }

  class PartyClient {
    constructor(hooks = {}) {
      this.hooks = hooks;
      this.ws = null;
      this.room = null;
      this.you = null;
      this.code = null;
      this.token = null;
      this._tickTimer = null;
      this._reconnectTimer = null;
      this._closed = false;
      this.meta = { perm_keys: Object.keys(PERM_LABELS), default_mod_perms: {}, perm_labels: PERM_LABELS };
    }

    setHooks(hooks) {
      this.hooks = { ...this.hooks, ...hooks };
    }

    get isInRoom() {
      return !!this.code && !!this.room;
    }

    get isHost() {
      return this.you && this.you.role === "host";
    }

    get isMod() {
      return this.you && this.you.role === "mod";
    }

    can(action) {
      if (!this.you) return false;
      if (this.you.role === "host") return true;
      if (this.you.role !== "mod") return false;
      const map = {
        play: "play_pause",
        pause: "play_pause",
        toggle: "play_pause",
        seek: "seek",
        next: "skip",
        prev: "skip",
        set_song: "skip",
        set_queue: "queue",
        queue_add: "queue",
        set_scene: "scene",
        set_speed: "scene",
        host_tick: false,
      };
      const key = map[action];
      if (key === false) return false;
      return !!(this.you.perms && this.you.perms[key]);
    }

    async fetchMeta() {
      try {
        const r = await fetch("/api/party/meta");
        if (r.ok) {
          this.meta = await r.json();
          this.meta.perm_labels = this.meta.perm_labels || PERM_LABELS;
        }
      } catch (_) {}
      return this.meta;
    }

    async create() {
      const r = await fetch("/api/party/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          device_id: deviceId(),
          name: deviceName(),
          platform: "web",
        }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.detail || "创建房间失败");
      this.room = j.room;
      this.code = j.room.code;
      await this.connectWs();
      return j.room;
    }

    async join(code) {
      const c = String(code || "").trim().toUpperCase();
      const r = await fetch("/api/party/join", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          code: c,
          device_id: deviceId(),
          name: deviceName(),
          platform: "web",
        }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.detail || "加入失败");
      this.room = j.room;
      this.code = j.room.code;
      await this.connectWs();
      return j.room;
    }

    connectWs() {
      return new Promise((resolve, reject) => {
        this._closed = false;
        if (this.ws) {
          try {
            this.ws.close();
          } catch (_) {}
        }
        const url = wsUrl(this.code, this.token);
        const ws = new WebSocket(url);
        this.ws = ws;
        let settled = false;
        ws.onopen = () => {
          /* wait for hello */
        };
        ws.onmessage = (ev) => {
          let msg;
          try {
            msg = JSON.parse(ev.data);
          } catch (_) {
            return;
          }
          this._onMessage(msg);
          if (msg.type === "hello" && !settled) {
            settled = true;
            resolve(msg);
          }
        };
        ws.onerror = () => {
          if (!settled) {
            settled = true;
            reject(new Error("WebSocket 连接失败"));
          }
        };
        ws.onclose = () => {
          this._stopHostTick();
          if (this.hooks.onClose) this.hooks.onClose();
          if (!this._closed && this.code) {
            clearTimeout(this._reconnectTimer);
            this._reconnectTimer = setTimeout(() => {
              this.connectWs().catch(() => {});
            }, 2000);
          }
        };
        setTimeout(() => {
          if (!settled) {
            settled = true;
            reject(new Error("加入房间超时"));
          }
        }, 8000);
      });
    }

    _onMessage(msg) {
      if (msg.type === "hello" || msg.type === "state") {
        if (msg.room) this.room = msg.room;
        if (msg.you) this.you = msg.you;
        else if (this.room && this.room.members) {
          this.you = this.room.members.find((m) => m.device_id === deviceId()) || this.you;
        }
        if (this.isHost) this._startHostTick();
        else this._stopHostTick();
        if (this.hooks.onState) this.hooks.onState(this.room, this.you, msg);
      } else if (msg.type === "error") {
        if (this.hooks.onError) this.hooks.onError(msg.message || "错误");
      } else if (msg.type === "kicked") {
        this._closed = true;
        this.code = null;
        this.room = null;
        if (this.hooks.onKicked) this.hooks.onKicked(msg.message);
      }
    }

    send(obj) {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(obj));
        return true;
      }
      return false;
    }

    control(action, extra = {}) {
      return this.send({ type: "control", action, ...extra });
    }

    setRole(targetId, role, perms) {
      return this.send({ type: "set_role", target_id: targetId, role, perms });
    }

    kick(targetId) {
      return this.send({ type: "kick", target_id: targetId });
    }

    transferHost(targetId) {
      return this.send({ type: "transfer_host", target_id: targetId });
    }

    leave() {
      this._closed = true;
      this._stopHostTick();
      this.send({ type: "leave" });
      try {
        this.ws && this.ws.close();
      } catch (_) {}
      this.ws = null;
      this.code = null;
      this.room = null;
      this.you = null;
      if (this.hooks.onLeft) this.hooks.onLeft();
    }

    /** Host periodically anchors position so followers stay in sync. */
    attachHostClock(getTick) {
      this._getTick = getTick;
    }

    _startHostTick() {
      if (this._tickTimer) return;
      this._tickTimer = setInterval(() => {
        if (!this.isHost || !this._getTick) return;
        const t = this._getTick();
        if (!t) return;
        this.control("host_tick", t);
      }, 4000);
    }

    _stopHostTick() {
      if (this._tickTimer) {
        clearInterval(this._tickTimer);
        this._tickTimer = null;
      }
    }
  }

  global.MusicHubParty = {
    PartyClient,
    deviceId,
    deviceName,
    PERM_LABELS,
    setDeviceName(name) {
      try {
        localStorage.setItem("mh_device_name", String(name || "").slice(0, 40));
      } catch (_) {}
    },
  };
})(typeof window !== "undefined" ? window : globalThis);
