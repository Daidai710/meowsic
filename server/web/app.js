/* Music Hub Web Player */
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => [...document.querySelectorAll(sel)];

const PAGE_SIZE = 500; // batch size when loading all
const MAX_SONGS = 100000;

/** 网页独立主题（不必与 Flutter App 同步；改网页样式只动 web/ 即可） */
const THEME_PRESETS = [
  { id: "midnight", label: "午夜蓝", desc: "默认深空蓝，冷静耐看", accent: "#6c9eff", bg: "#0b1020", mid: "#0f1528" },
  { id: "neon_cyber", label: "赛博霓虹", desc: "青紫撞色，夜店 / 电子风", accent: "#00f5d4", bg: "#0a0618", mid: "#12082a" },
  { id: "sunset", label: "暖阳落日", desc: "橙粉渐变，温柔偏暖", accent: "#ff8a5b", bg: "#2a1220", mid: "#1e1018" },
  { id: "forest", label: "森野绿", desc: "墨绿苔藓，安静专注", accent: "#5ddba0", bg: "#0a1812", mid: "#0c1610" },
  { id: "sakura", label: "樱粉夜", desc: "浅粉强调，偏日系氛围", accent: "#ff8fb8", bg: "#221820", mid: "#1a1218" },
  { id: "ocean", label: "深海", desc: "青绿海水，清爽通透", accent: "#3ecfc7", bg: "#061820", mid: "#08141c" },
  { id: "lofi_purple", label: "Lo-fi 紫", desc: "雾紫灰调，适合松弛听感", accent: "#b39ddb", bg: "#161220", mid: "#12101a" },
  { id: "gold_noir", label: "黑金", desc: "香槟金点缀，偏高级感", accent: "#e0c07a", bg: "#14120e", mid: "#100e0a" },
  { id: "oled_ink", label: "OLED 墨黑", desc: "极致黑底，省电、对比强", accent: "#e8e8ec", bg: "#000000", mid: "#000000" },
  { id: "crimson", label: "猩红现场", desc: "红黑舞台感，摇滚向", accent: "#ff4d6d", bg: "#1a080c", mid: "#12060a" },
  { id: "arctic", label: "极光", desc: "冰蓝 + 青绿微光", accent: "#7bdff2", bg: "#0a1420", mid: "#0c1820" },
  { id: "paper_light", label: "纸白日间", desc: "浅色界面，白天更易读", accent: "#3d6bf3", bg: "#f4f6fa", mid: "#eceff5" },
];

const SCENE_PRESETS =
  (window.MusicHubEq && window.MusicHubEq.SCENE_PRESETS) || [
    { id: "default", label: "默认", description: "平坦", eqPreset: "normal", speed: 1, volume: 1 },
  ];

const state = {
  songs: [],
  recent: [],
  totalInDb: 0,
  queue: [],
  queueIndex: -1,
  playlists: [],
  activePlaylistId: null,
  view: "library",
  seeking: false,
  shuffle: false,
  // off | all | one
  loopMode: localStorage.getItem("mh_loop") || "all",
  orderQueue: null,
  search: "",
  playlistSongs: [],
  lanUrl: "",
  lanUrls: [],
  sleepTimer: null,
  sleepUntil: null,
  sleepFade: false,
  speed: Number(localStorage.getItem("mh_speed") || "1") || 1,
  userVolume: Number(localStorage.getItem("mh_vol") || "0.9") || 0.9,
  themeId: localStorage.getItem("mh_theme") || "midnight",
  sceneId: localStorage.getItem("mh_scene") || "default",
  sceneVolume: 1.0,
  eqPreset: localStorage.getItem("mh_eq_preset") || "normal",
  /** 一起听：忽略本地操作回声 / 正在应用远端状态 */
  partyApplying: false,
  partySelectedMember: null,
  followRoomScene: true,
  partyMode: "sync", // sync | solo
  devices: [],
};

/** @type {InstanceType<typeof window.MusicHubParty.PartyClient> | null} */
let partyClient = null;
if (window.MusicHubParty && window.MusicHubParty.PartyClient) {
  partyClient = new window.MusicHubParty.PartyClient();
}

function getTheme(id) {
  return THEME_PRESETS.find((t) => t.id === id) || THEME_PRESETS[0];
}

function applyTheme(id, { silent = false } = {}) {
  const theme = getTheme(id);
  state.themeId = theme.id;
  document.documentElement.setAttribute("data-theme", theme.id);
  try {
    localStorage.setItem("mh_theme", theme.id);
  } catch (_) {}
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = theme.bg;
  renderThemeGrid();
  if (!silent) toast("主题：" + theme.label);
}

function renderThemeGrid() {
  const el = $("#theme-grid");
  if (!el) return;
  const cur = state.themeId || "midnight";
  el.innerHTML = THEME_PRESETS.map((t) => {
    const active = t.id === cur ? " active" : "";
    return `<button type="button" class="theme-swatch${active}" data-theme-id="${t.id}"
      role="option" aria-selected="${t.id === cur}" title="${escapeHtml(t.desc)}">
      <span class="theme-swatch-preview" style="--sw-a:${t.accent};--sw-bg:${t.bg};--sw-mid:${t.mid}"></span>
      <span class="theme-swatch-label">${escapeHtml(t.label)}</span>
      <span class="theme-swatch-desc">${escapeHtml(t.desc)}</span>
    </button>`;
  }).join("");
  el.querySelectorAll("[data-theme-id]").forEach((btn) => {
    btn.addEventListener("click", () => applyTheme(btn.dataset.themeId));
  });
}

function getScene(id) {
  if (window.MusicHubEq && typeof window.MusicHubEq.getScene === "function") {
    return window.MusicHubEq.getScene(id);
  }
  return SCENE_PRESETS.find((s) => s.id === id) || SCENE_PRESETS[0];
}

/** 有效输出音量 = 用户音量 × 场景软音量 ×（睡眠淡出时再衰减） */
function applyOutputVolume() {
  if (state.sleepFade) return;
  const v = Math.max(0, Math.min(1, state.userVolume * state.sceneVolume));
  audio.volume = v;
}

function sceneChipHtml(scene, selectedId) {
  const active = scene.id === selectedId ? " active" : "";
  return `<button type="button" class="scene-chip${active}" data-scene-id="${escapeHtml(scene.id)}"
    role="option" aria-selected="${scene.id === selectedId}" title="${escapeHtml(scene.description)}">
    <span class="scene-chip-label">${escapeHtml(scene.label)}</span>
    <span class="scene-chip-desc">${escapeHtml(scene.description)}</span>
  </button>`;
}

function renderSceneGrid() {
  const el = $("#scene-grid");
  if (!el) return;
  const cur = state.sceneId || "default";
  el.innerHTML = SCENE_PRESETS.map((s) => sceneChipHtml(s, cur)).join("");
  el.querySelectorAll("[data-scene-id]").forEach((btn) => {
    btn.addEventListener("click", () => applyScene(btn.dataset.sceneId));
  });
  const hint = $("#scene-hint");
  if (hint) {
    const scene = getScene(cur);
    const eqOk = eqEngine ? (eqEngine.available ? (eqEngine.ready ? "EQ 已就绪" : "点播放后加载 EQ") : "本浏览器不支持 Web EQ") : "EQ 模块未加载";
    hint.textContent = `当前：${scene.label} · ${eqOk}`;
  }
}

function renderScenePopover() {
  const el = $("#scene-popover-list");
  if (!el) return;
  const cur = state.sceneId || "default";
  el.innerHTML = SCENE_PRESETS.map((s) => {
    const active = s.id === cur ? " active" : "";
    return `<button type="button" class="scene-popover-item${active}" data-scene-id="${escapeHtml(s.id)}"
      role="option" aria-selected="${s.id === cur}">
      <span class="scene-chip-label">${escapeHtml(s.label)}</span>
      <span class="scene-chip-desc">${escapeHtml(s.description)}</span>
    </button>`;
  }).join("");
  el.querySelectorAll("[data-scene-id]").forEach((btn) => {
    btn.addEventListener("click", () => {
      applyScene(btn.dataset.sceneId);
      setScenePopoverOpen(false);
    });
  });
}

function updateSceneUi() {
  const scene = getScene(state.sceneId);
  const btn = $("#btn-scene");
  if (btn) {
    const isDefault = scene.id === "default";
    btn.classList.toggle("active", !isDefault);
    btn.title = isDefault ? "听感场景：默认" : `听感场景：${scene.label}`;
    btn.setAttribute("aria-label", btn.title);
  }
  renderSceneGrid();
  renderScenePopover();
}

function setScenePopoverOpen(open) {
  const pop = $("#scene-popover");
  const btn = $("#btn-scene");
  if (!pop) return;
  pop.hidden = !open;
  if (btn) btn.setAttribute("aria-expanded", open ? "true" : "false");
}

/**
 * 应用听感场景。
 * 与 App 一致：default 不强制改 EQ 曲线；其它场景写入对应 EQ + 速度 + 软音量。
 */
async function applyScene(id, { silent = false, fromParty = false } = {}) {
  const scene = getScene(id);
  state.sceneId = scene.id;
  state.sceneVolume = typeof scene.volume === "number" ? scene.volume : 1;
  try {
    localStorage.setItem("mh_scene", scene.id);
  } catch (_) {}

  if (scene.id !== "default") {
    state.eqPreset = scene.eqPreset || "normal";
    try {
      localStorage.setItem("mh_eq_preset", state.eqPreset);
    } catch (_) {}
    if (eqEngine) {
      await eqEngine.resume();
      eqEngine.applyEqPreset(state.eqPreset);
    }
  }

  state.speed = Math.max(0.5, Math.min(2, Number(scene.speed) || 1));
  try {
    localStorage.setItem("mh_speed", String(state.speed));
  } catch (_) {}
  audio.playbackRate = state.speed;
  updateSpeedUi();
  applyOutputVolume();
  updateSceneUi();
  if (!silent) toast(`场景：${scene.label}`);
  if (!fromParty && !state.partyApplying && partyClient?.isInRoom && partyClient.can("set_scene")) {
    partyClient.control("set_scene", { scene_id: scene.id });
    if (partyClient.can("set_speed")) {
      partyClient.control("set_speed", { speed: state.speed, position: audio.currentTime || 0 });
    }
  }
}

function partyFindSong(songId) {
  if (songId == null) return null;
  const id = Number(songId);
  return (
    state.queue.find((s) => s.id === id) ||
    state.songs.find((s) => s.id === id) ||
    state.recent.find((s) => s.id === id) ||
    (state.playlistSongs || []).find((s) => s.id === id) ||
    null
  );
}

async function partyResolveSongs(ids) {
  const out = [];
  for (const id of ids || []) {
    let s = partyFindSong(id);
    if (!s) {
      // try pull single page from library cache; if missing, skip
      s = state.songs.find((x) => x.id === Number(id));
    }
    if (s) out.push(s);
  }
  return out;
}

function partyBroadcastQueueIfHost() {
  if (!partyClient?.isInRoom || state.partyApplying) return;
  if (!(partyClient.isHost || partyClient.can("set_queue") || partyClient.can("set_song"))) return;
  const song = state.queue[state.queueIndex];
  if (!song) return;
  if (partyClient.can("set_queue") || partyClient.isHost) {
    partyClient.control("set_queue", {
      queue: state.queue.map((s) => s.id),
      queue_index: state.queueIndex,
      position: audio.currentTime || 0,
      playing: !audio.paused && !!audio.src,
    });
  } else if (partyClient.can("set_song")) {
    partyClient.control("set_song", {
      song_id: song.id,
      position: audio.currentTime || 0,
      playing: !audio.paused && !!audio.src,
    });
  }
}

async function applyPartyRoomState(room) {
  if (!room || !room.state) return;
  const st = room.state;
  state.partyApplying = true;
  try {
    // shared scene
    if (state.followRoomScene && st.scene_id && st.scene_id !== state.sceneId) {
      await applyScene(st.scene_id, { silent: true, fromParty: true });
    }
    if (st.speed && Math.abs(st.speed - state.speed) > 0.01) {
      state.speed = st.speed;
      audio.playbackRate = state.speed;
      updateSpeedUi();
    }

    const targetId = st.song_id;
    const cur = state.queue[state.queueIndex];
    const needSong = targetId != null && (!cur || cur.id !== targetId);

    if (needSong || (st.queue && st.queue.length && !state.queue.length)) {
      let list = [];
      if (st.queue && st.queue.length) {
        list = await partyResolveSongs(st.queue);
      }
      if (!list.length && targetId != null) {
        const one = partyFindSong(targetId);
        if (one) list = [one];
      }
      if (list.length) {
        state.queue = list;
        let idx = list.findIndex((s) => s.id === Number(targetId));
        if (idx < 0) idx = Math.max(0, st.queue_index || 0);
        if (idx >= list.length) idx = 0;
        state.queueIndex = idx;
        state.orderQueue = list.slice();
        playCurrent();
      } else if (targetId != null) {
        // not in local cache — soft load songs then retry once
        try {
          if (!state.songs.length) await loadSongs();
          const one = partyFindSong(targetId);
          if (one) {
            state.queue = [one];
            state.queueIndex = 0;
            playCurrent();
          }
        } catch (_) {}
      }
    }

    // position + play/pause after media ready
    const targetPos = typeof st.estimated_position === "number" ? st.estimated_position : st.position || 0;
    const applyPosPlay = () => {
      try {
        if (audio.src && isFinite(targetPos)) {
          if (Math.abs((audio.currentTime || 0) - targetPos) > 1.2) {
            audio.currentTime = Math.max(0, targetPos);
          }
        }
      } catch (_) {}
      if (st.playing) {
        if (audio.paused && audio.src) {
          ensureEqOnPlayback().finally(() => audio.play().catch(() => {}));
        }
      } else if (!audio.paused) {
        audio.pause();
      }
    };

    if (audio.readyState >= 1) applyPosPlay();
    else {
      const once = () => {
        audio.removeEventListener("loadedmetadata", once);
        applyPosPlay();
      };
      audio.addEventListener("loadedmetadata", once);
      // also try soon
      setTimeout(applyPosPlay, 400);
    }
  } finally {
    setTimeout(() => {
      state.partyApplying = false;
    }, 300);
  }
  renderPartyUi();
}

function partyJoinUrl(code) {
  const origin = location.origin.replace(/\/$/, "");
  return `${origin}/?party=${encodeURIComponent(code || "")}`;
}

function setPartyMode(mode) {
  state.partyMode = mode === "solo" ? "solo" : "sync";
  $$(".party-mode-btn").forEach((b) => {
    const on = b.dataset.partyMode === state.partyMode;
    b.classList.toggle("active", on);
    b.classList.toggle("btn-ghost", !on);
  });
  const sync = $("#party-panel-sync");
  const solo = $("#party-panel-solo");
  if (sync) sync.hidden = state.partyMode !== "sync";
  if (solo) solo.hidden = state.partyMode !== "solo";
  const hint = $("#party-mode-hint");
  if (hint) {
    hint.textContent =
      state.partyMode === "sync"
        ? "同步听：多人同一进度；房主可授权限。扫码或链接邀请。"
        : "各自听：共用曲库、独立点歌；可踢在线设备。不同步进度。";
  }
  if (state.partyMode === "solo") loadPartyDevices();
  renderPartyUi();
}

async function loadPartyDevices() {
  const ul = $("#party-devices");
  if (!ul) return;
  try {
    const list = await api("/api/devices?active_seconds=90");
    state.devices = Array.isArray(list) ? list : [];
  } catch {
    state.devices = [];
  }
  const me = window.MusicHubParty?.deviceId?.() || "";
  if (!state.devices.length) {
    ul.innerHTML = `<li class="muted">暂无设备 · 连接并播放后会心跳上报</li>`;
    return;
  }
  ul.innerHTML = state.devices
    .map((d) => {
      const id = d.device_id || "";
      const name = d.name || "设备";
      const online = d.online === 1 || d.online === true;
      const kicked = d.kicked === 1 || d.kicked === true;
      const isMe = id === me;
      const kickBtn =
        isMe || kicked
          ? kicked
            ? `<span class="role-tag guest">已踢</span>`
            : `<span class="role-tag">本机</span>`
          : `<button type="button" class="btn btn-sm btn-ghost" data-kick-device="${escapeHtml(id)}">踢下线</button>`;
      return `<li class="party-member">
        <span>${escapeHtml(name)}${isMe ? "（我）" : ""} · ${online ? "在线" : "离线"} · ${escapeHtml(d.platform || "")}</span>
        ${kickBtn}
      </li>`;
    })
    .join("");
  ul.querySelectorAll("[data-kick-device]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const id = btn.getAttribute("data-kick-device");
      if (!id || !confirm("踢下线该设备？")) return;
      try {
        await api(`/api/devices/${encodeURIComponent(id)}/kick`, { method: "POST", body: "{}" });
        toast("已踢下线");
        loadPartyDevices();
      } catch (e) {
        toast(e.message || String(e));
      }
    });
  });
}

function renderPartyUi() {
  const active = $("#party-active");
  if (!active) return;
  const inRoom = !!(partyClient && partyClient.isInRoom && partyClient.room);
  active.hidden = !inRoom;
  if (!inRoom) {
    if (state.partyMode === "solo") loadPartyDevices();
    return;
  }

  const room = partyClient.room;
  const you = partyClient.you;
  const code = room.code || "";
  $("#party-code-show").textContent = code;
  const joinUrl = partyJoinUrl(code);
  const urlEl = $("#party-join-url");
  if (urlEl) urlEl.textContent = joinUrl;
  const qr = $("#party-qr-img");
  if (qr) {
    qr.src = `/api/qr.png?url=${encodeURIComponent(joinUrl)}&t=${Date.now()}`;
    qr.alt = `房间 ${code} 二维码`;
  }

  const role = you?.role || "guest";
  const roleLabel = role === "host" ? "房主" : role === "mod" ? "管理员" : "听众";
  $("#party-role-line").textContent = `你是${roleLabel} · 在线 ${room.online_count ?? "?"} / ${room.member_count ?? "?"}`;

  const st = room.state || {};
  const song = partyFindSong(st.song_id);
  $("#party-track-line").textContent = song
    ? `当前曲目：${song.title} — ${song.artist}`
    : st.song_id
      ? `当前曲目：#${st.song_id}`
      : "当前曲目：—";

  const perms = you?.perms || {};
  const labels = (partyClient.meta && partyClient.meta.perm_labels) || window.MusicHubParty?.PERM_LABELS || {};
  if (role === "host") {
    $("#party-perm-line").textContent = "权限：全部（房主）";
  } else if (role === "mod") {
    const on = Object.keys(perms)
      .filter((k) => perms[k])
      .map((k) => labels[k] || k);
    $("#party-perm-line").textContent = on.length ? `权限：${on.join("、")}` : "权限：无（仅跟随）";
  } else {
    $("#party-perm-line").textContent = "权限：仅跟随播放";
  }

  const ul = $("#party-members");
  const members = room.members || [];
  if (ul) {
    ul.innerHTML = members
      .map((m) => {
        const selected = state.partySelectedMember === m.device_id ? " selected" : "";
        const r = m.role === "host" ? "host" : m.role === "mod" ? "mod" : "guest";
        const rText = m.role === "host" ? "房主" : m.role === "mod" ? "管理" : "听众";
        const me = m.device_id === window.MusicHubParty.deviceId() ? "（我）" : "";
        const offline = m.online === false ? " · 离线" : "";
        return `<li class="party-member${selected}" data-member-id="${escapeHtml(m.device_id)}">
        <span>${escapeHtml(m.name || "设备")}${me}${offline}</span>
        <span class="role-tag ${r}">${rText}</span>
      </li>`;
      })
      .join("");
    ul.querySelectorAll("[data-member-id]").forEach((el) => {
      el.addEventListener("click", () => {
        state.partySelectedMember = el.getAttribute("data-member-id");
        renderPartyUi();
      });
    });
  }

  const modPanel = $("#party-mod-panel");
  if (modPanel) modPanel.hidden = role !== "host";

  const checks = $("#party-perm-checks");
  if (checks && role === "host") {
    const keys = (partyClient.meta && partyClient.meta.perm_keys) || Object.keys(labels);
    const defaults = (partyClient.meta && partyClient.meta.default_mod_perms) || {};
    const selected = members.find((m) => m.device_id === state.partySelectedMember);
    const curPerms = selected && selected.role === "mod" ? selected.perms || defaults : defaults;
    checks.innerHTML = keys
      .map((k) => {
        const checked = curPerms[k] ? " checked" : "";
        return `<label><input type="checkbox" data-perm="${k}"${checked}/> ${escapeHtml(labels[k] || k)}</label>`;
      })
      .join("");
  }
}

function partyReadPermChecks() {
  const out = {};
  $$("#party-perm-checks [data-perm]").forEach((el) => {
    out[el.getAttribute("data-perm")] = !!el.checked;
  });
  return out;
}

function setupPartyUi() {
  if (!partyClient) return;
  partyClient.fetchMeta().then(() => renderPartyUi());
  partyClient.setHooks({
    onState: (room) => {
      applyPartyRoomState(room);
    },
    onError: (m) => toast(m),
    onKicked: (m) => {
      toast(m || "已离开房间");
      renderPartyUi();
    },
    onLeft: () => renderPartyUi(),
    onClose: () => {},
  });
  partyClient.attachHostClock(() => {
    const song = state.queue[state.queueIndex];
    if (!song) return null;
    return {
      song_id: song.id,
      position: audio.currentTime || 0,
      playing: !audio.paused && !!audio.src,
      speed: state.speed || 1,
    };
  });

  try {
    const n = localStorage.getItem("mh_device_name");
    if (n && $("#party-name")) $("#party-name").value = n;
  } catch (_) {}

  $$(".party-mode-btn").forEach((btn) => {
    btn.addEventListener("click", () => setPartyMode(btn.dataset.partyMode));
  });
  setPartyMode(state.partyMode);

  $("#btn-party-create")?.addEventListener("click", async () => {
    try {
      const name = ($("#party-name")?.value || "").trim();
      if (name && window.MusicHubParty) window.MusicHubParty.setDeviceName(name);
      await partyClient.create();
      partyBroadcastQueueIfHost();
      toast("房间已创建：" + partyClient.code);
      setPartyMode("sync");
      renderPartyUi();
      setView("party");
    } catch (e) {
      toast(e.message || String(e));
    }
  });
  $("#btn-party-join")?.addEventListener("click", async () => {
    try {
      const name = ($("#party-name")?.value || "").trim();
      if (name && window.MusicHubParty) window.MusicHubParty.setDeviceName(name);
      const code = $("#party-code-input")?.value || "";
      await partyClient.join(code);
      toast("已加入 " + partyClient.code);
      setPartyMode("sync");
      renderPartyUi();
      setView("party");
    } catch (e) {
      toast(e.message || String(e));
    }
  });
  $("#btn-party-leave")?.addEventListener("click", () => {
    partyClient.leave();
    toast("已离开房间");
    renderPartyUi();
  });
  $("#btn-party-copy")?.addEventListener("click", async () => {
    const c = partyClient.code;
    if (!c) return;
    try {
      await navigator.clipboard.writeText(c);
      toast("已复制房间码 " + c);
    } catch (_) {
      toast(c);
    }
  });
  $("#btn-party-copy-link")?.addEventListener("click", async () => {
    const c = partyClient.code;
    if (!c) return;
    const url = partyJoinUrl(c);
    try {
      await navigator.clipboard.writeText(url);
      toast("已复制邀请链接");
    } catch (_) {
      toast(url);
    }
  });
  $("#btn-party-refresh-devices")?.addEventListener("click", () => loadPartyDevices());
  $("#btn-party-make-mod")?.addEventListener("click", () => {
    if (!state.partySelectedMember) return toast("先点选一名成员");
    partyClient.setRole(state.partySelectedMember, "mod", partyReadPermChecks());
    toast("已设为管理员");
  });
  $("#btn-party-make-guest")?.addEventListener("click", () => {
    if (!state.partySelectedMember) return toast("先点选一名成员");
    partyClient.setRole(state.partySelectedMember, "guest", {});
    toast("已降为听众");
  });
  $("#btn-party-transfer")?.addEventListener("click", () => {
    if (!state.partySelectedMember) return toast("先点选一名成员");
    if (!confirm("确定转让房主？")) return;
    partyClient.transferHost(state.partySelectedMember);
  });
  $("#btn-party-kick")?.addEventListener("click", () => {
    if (!state.partySelectedMember) return toast("先点选一名成员");
    if (!confirm("踢出该成员？")) return;
    partyClient.kick(state.partySelectedMember);
    state.partySelectedMember = null;
  });

  // Auto-join from ?party=CODE
  try {
    const params = new URLSearchParams(location.search);
    const code = (params.get("party") || "").trim().toUpperCase();
    if (code && partyClient && !partyClient.isInRoom) {
      if ($("#party-code-input")) $("#party-code-input").value = code;
      partyClient
        .join(code)
        .then(() => {
          toast("已通过链接加入 " + code);
          setPartyMode("sync");
          setView("party");
          renderPartyUi();
          // clean URL without reload
          try {
            const u = new URL(location.href);
            u.searchParams.delete("party");
            history.replaceState({}, "", u.pathname + u.search + u.hash);
          } catch (_) {}
        })
        .catch((e) => toast(e.message || String(e)));
    }
  } catch (_) {}
}

async function ensureEqOnPlayback() {
  if (!eqEngine) return;
  await eqEngine.resume();
  // 非 default 场景或已记过 eq 预设时恢复曲线
  if (state.sceneId !== "default") {
    eqEngine.applyEqPreset(state.eqPreset || getScene(state.sceneId).eqPreset);
  } else if (state.eqPreset && state.eqPreset !== "normal") {
    eqEngine.applyEqPreset(state.eqPreset);
  }
  updateSceneUi();
}

const audio = $("#audio");
/** @type {ReturnType<typeof window.MusicHubEq.createEqEngine> | null} */
const eqEngine =
  window.MusicHubEq && typeof window.MusicHubEq.createEqEngine === "function"
    ? window.MusicHubEq.createEqEngine(audio)
    : null;

function toast(msg, ms = 2600) {
  const el = $("#toast");
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => {
    el.hidden = true;
  }, ms);
}

function fmtTime(sec) {
  if (sec == null || !isFinite(sec) || sec < 0) return "0:00";
  const s = Math.floor(sec % 60);
  const m = Math.floor(sec / 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function isMobile() {
  return window.matchMedia("(max-width: 900px)").matches;
}

async function api(path, opts = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(opts.headers || {}) },
    ...opts,
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const j = await res.json();
      detail = j.detail || JSON.stringify(j);
    } catch (_) {}
    throw new Error(detail);
  }
  if (res.status === 204) return null;
  const ct = res.headers.get("content-type") || "";
  if (ct.includes("application/json")) return res.json();
  return res.text();
}

async function loadStatus() {
  const s = await api("/api/status");
  state.totalInDb = s.song_count || 0;
  const ff = s.ffmpeg ? "可用" : "未安装";
  const ipHint = s.lan_ip ? ` · ${s.lan_ip}` : "";
  const authHint = s.auth_required ? " · 需密码" : "";
  $("#status-line").textContent = `${s.song_count} 首 · FFmpeg ${ff}${ipHint}${authHint}`;
  $("#library-path").value = s.library_path || "";
  $("#status-json").textContent = JSON.stringify(s, null, 2);
  const ffEl = $("#ffmpeg-status");
  if (ffEl) {
    ffEl.textContent = s.ffmpeg
      ? `已检测到：${s.ffmpeg_path || "PATH"}`
      : "未检测到 FFmpeg。损坏 mp3 / wma 等可能无法转码。";
  }
  if (s.lan_url) {
    state.lanUrl = s.lan_url;
    state.lanUrls = s.lan_urls || [];
    updateLanUi();
  }
  return s;
}

async function loadLan() {
  const info = await api("/api/lan");
  state.lanUrl = info.primary_url;
  state.lanUrls = info.urls || [];
  updateLanUi();
  return info;
}

function qrImgSrc(url) {
  const u = url || state.lanUrl || "";
  return `/api/qr.png?url=${encodeURIComponent(u)}&t=${Date.now()}`;
}

function updateLanUi() {
  const url = state.lanUrl || "";
  const setText = (sel) => {
    const el = $(sel);
    if (el) el.textContent = url || "未检测到局域网 IP";
  };
  setText("#settings-lan-url");
  setText("#modal-lan-url");

  const list = $("#lan-url-list");
  if (list) {
    list.innerHTML = "";
    (state.lanUrls || []).forEach((u) => {
      const li = document.createElement("li");
      li.innerHTML = u === url ? `<strong>${escapeHtml(u)}</strong>（推荐）` : escapeHtml(u);
      list.appendChild(li);
    });
    if (!(state.lanUrls || []).length) {
      list.innerHTML = "<li>未检测到可用局域网 IP，请确认 Wi‑Fi 已连接</li>";
    }
  }

  const imgs = ["#settings-qr-img", "#modal-qr-img"];
  imgs.forEach((sel) => {
    const img = $(sel);
    if (img && url) {
      img.src = qrImgSrc(url);
      img.alt = `扫码打开 ${url}`;
    }
  });
}

function openQrModal() {
  const modal = $("#qr-modal");
  modal.hidden = false;
  loadLan()
    .then(() => updateLanUi())
    .catch((e) => toast("获取局域网地址失败：" + e.message));
}

function closeQrModal() {
  $("#qr-modal").hidden = true;
}

async function copyLanUrl() {
  const url = state.lanUrl;
  if (!url) return toast("没有可复制的地址");
  try {
    await navigator.clipboard.writeText(url);
    toast("已复制：" + url);
  } catch (_) {
    // fallback
    const ta = document.createElement("textarea");
    ta.value = url;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    ta.remove();
    toast("已复制：" + url);
  }
}

/** Load entire library in batches (no hard 500 cap). */
async function loadSongs(q = "") {
  state.search = q;
  const all = [];
  let offset = 0;
  while (offset < MAX_SONGS) {
    const params = new URLSearchParams({
      limit: String(PAGE_SIZE),
      offset: String(offset),
    });
    if (q) params.set("q", q);
    const batch = await api(`/api/songs?${params}`);
    all.push(...batch);
    if (batch.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }
  state.songs = all;
  renderLibrary();
  updateLibrarySub();
  return all;
}

function updateLibrarySub() {
  if (state.view !== "library") return;
  const n = state.songs.length;
  const total = state.totalInDb;
  if (state.search) {
    $("#view-sub").textContent = `搜索到 ${n} 首`;
  } else if (total && n < total) {
    $("#view-sub").textContent = `已加载 ${n} / 库内 ${total} 首`;
  } else {
    $("#view-sub").textContent = `共 ${n} 首`;
  }
}

function renderLibrary() {
  const songs = state.songs;
  $("#empty-library").hidden = songs.length > 0;
  renderSongTable(songs, $("#song-tbody"), { mode: "library" });
  renderSongCards(songs, $("#song-cards"), { mode: "library" });
}

function renderSongTable(songs, tbody, { mode = "library", playlistId = null } = {}) {
  if (!tbody) return;
  tbody.innerHTML = "";
  songs.forEach((song, i) => {
    const tr = document.createElement("tr");
    if (state.queue[state.queueIndex]?.id === song.id) tr.classList.add("playing");
    const fmtBadge =
      song.needs_transcode || song.tag_ok === false
        ? `<span class="badge warn" title="可能需 FFmpeg">${escapeHtml(song.format)}${song.tag_ok === false ? "!" : ""}</span>`
        : `<span class="badge">${escapeHtml(song.format)}</span>`;

    let actions = "";
    if (mode === "library") {
      actions = `<button class="btn btn-sm btn-ghost" data-act="play-next" data-id="${song.id}" title="下一首播放">下一首</button>
        <button class="btn btn-sm btn-ghost" data-act="add-pl" data-id="${song.id}">+歌单</button>`;
    } else if (mode === "playlist") {
      actions = `<button class="btn btn-sm btn-ghost" data-act="play-next" data-id="${song.id}">下一首</button>
        <button class="btn btn-sm btn-danger" data-act="rm-pl" data-id="${song.id}" data-pl="${playlistId}">移除</button>`;
    }

    tr.innerHTML = `
      <td>${i + 1}</td>
      <td class="cell-title">${escapeHtml(song.title)}</td>
      <td>${escapeHtml(song.artist)}</td>
      <td class="cell-album">${escapeHtml(song.album)}</td>
      <td>${fmtBadge}</td>
      <td>${fmtTime(song.duration)}</td>
      <td class="row cell-actions">${actions}</td>
    `;
    tr.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      playFromList(songs, i);
    });
    tbody.appendChild(tr);
  });
  bindRowActions(tbody, playlistId);
}

function renderSongCards(songs, container, { mode = "library", playlistId = null } = {}) {
  if (!container) return;
  container.innerHTML = "";
  songs.forEach((song, i) => {
    const card = document.createElement("article");
    card.className = "song-card";
    if (state.queue[state.queueIndex]?.id === song.id) card.classList.add("playing");

    const warn = song.needs_transcode || song.tag_ok === false;
    card.innerHTML = `
      <div class="song-card-main">
        <div class="song-card-idx">${i + 1}</div>
        <div class="song-card-text">
          <div class="song-card-title">${escapeHtml(song.title)}</div>
          <div class="song-card-sub muted">${escapeHtml(song.artist)} · ${fmtTime(song.duration)}</div>
        </div>
        ${warn ? `<span class="badge warn">${escapeHtml(song.format)}!</span>` : `<span class="badge">${escapeHtml(song.format)}</span>`}
      </div>
      <div class="song-card-actions">
        ${
          mode === "library"
            ? `<button class="btn btn-sm btn-ghost" data-act="play-next" data-id="${song.id}">下一首</button>
               <button class="btn btn-sm btn-ghost" data-act="add-pl" data-id="${song.id}">+歌单</button>`
            : mode === "playlist"
              ? `<button class="btn btn-sm btn-ghost" data-act="play-next" data-id="${song.id}">下一首</button>
                 <button class="btn btn-sm btn-danger" data-act="rm-pl" data-id="${song.id}" data-pl="${playlistId}">移除</button>`
              : ""
        }
      </div>
    `;
    card.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      playFromList(songs, i);
    });
    container.appendChild(card);
  });
  bindRowActions(container, playlistId);
}

function bindRowActions(root, playlistId) {
  root.querySelectorAll("[data-act=add-pl]").forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation();
      await addSongToPlaylistPrompt(Number(btn.dataset.id));
    });
  });
  root.querySelectorAll("[data-act=play-next]").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const id = Number(btn.dataset.id);
      const song =
        state.songs.find((s) => s.id === id) ||
        state.recent.find((s) => s.id === id) ||
        state.queue.find((s) => s.id === id) ||
        (state.playlistSongs || []).find((s) => s.id === id);
      if (song) playNextSong(song);
    });
  });
  root.querySelectorAll("[data-act=rm-pl]").forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation();
      const pid = Number(btn.dataset.pl);
      const sid = Number(btn.dataset.id);
      await api(`/api/playlists/${pid}/songs/${sid}`, { method: "DELETE" });
      toast("已从歌单移除");
      await openPlaylist(pid);
    });
  });
}

function shuffleArray(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function playFromList(list, index) {
  if (!list.length) return;
  // 听众无权限时阻止本地点歌打断同步
  if (partyClient?.isInRoom && !state.partyApplying && !partyClient.isHost && !partyClient.can("set_song") && !partyClient.can("set_queue")) {
    toast("一起听中：仅房主/有权限的管理员可点歌");
    return;
  }
  state.orderQueue = list.slice();
  if (state.shuffle) {
    const current = list[index];
    const rest = list.filter((_, i) => i !== index);
    state.queue = [current, ...shuffleArray(rest)];
    state.queueIndex = 0;
  } else {
    state.queue = list.slice();
    state.queueIndex = index;
  }
  playCurrent();
  partyBroadcastQueueIfHost();
}

/** Start shuffle playback from current view list (library or playlist). */
function playShuffleAll() {
  const list =
    state.view === "playlists" && state.playlistSongs.length
      ? state.playlistSongs
      : state.songs;
  if (!list.length) return toast("没有可播放的歌曲");
  state.shuffle = true;
  updateShuffleUi();
  const idx = Math.floor(Math.random() * list.length);
  playFromList(list, idx);
  toast("随机播放已开启");
}

function toggleShuffle() {
  state.shuffle = !state.shuffle;
  updateShuffleUi();
  if (!state.queue.length) {
    toast(state.shuffle ? "随机已开：点歌后生效" : "随机已关");
    return;
  }
  const current = state.queue[state.queueIndex];
  const base = state.orderQueue && state.orderQueue.length ? state.orderQueue : state.queue;
  if (state.shuffle) {
    const rest = base.filter((s) => s.id !== current.id);
    state.queue = [current, ...shuffleArray(rest)];
    state.queueIndex = 0;
  } else {
    state.queue = base.slice();
    const i = state.queue.findIndex((s) => s.id === current.id);
    state.queueIndex = i >= 0 ? i : 0;
  }
  $("#queue-info").textContent = `队列 ${state.queueIndex + 1}/${state.queue.length}${state.shuffle ? " · 随机" : ""}`;
  toast(state.shuffle ? "随机播放开" : "随机播放关");
}

function updateShuffleUi() {
  const btn = $("#btn-shuffle");
  if (!btn) return;
  btn.classList.toggle("active", state.shuffle);
  btn.setAttribute("aria-pressed", state.shuffle ? "true" : "false");
  btn.title = state.shuffle ? "随机：开" : "随机：关";
}

function streamUrl(song, forceTranscode = false) {
  const need = forceTranscode || song.needs_transcode || song.tag_ok === false;
  const q = need ? "?transcode=true" : "";
  return `${song.stream_url}${q}`;
}

function playCurrent(opts = {}) {
  const song = state.queue[state.queueIndex];
  if (!song) return;
  const force = !!opts.forceTranscode;
  song._triedTranscode = force || song._triedTranscode;
  audio.src = streamUrl(song, force);
  audio.playbackRate = state.speed;
  applyOutputVolume();
  ensureEqOnPlayback().finally(() => {
    audio.play().catch((err) => {
      console.error(err);
      if (!song._triedTranscode) {
        song._triedTranscode = true;
        toast("直出失败，尝试转码播放…");
        playCurrent({ forceTranscode: true });
        return;
      }
      toast("播放失败：文件可能损坏或需 FFmpeg");
    });
  });
  updateNowPlaying(song);
  $("#queue-info").textContent = `队列 ${state.queueIndex + 1}/${state.queue.length}${state.shuffle ? " · 随机" : ""}`;
  $("#btn-play").textContent = "⏸";
  if (state.view === "library") renderLibrary();
  else if (state.view === "playlists" && state.activePlaylistId) {
    renderSongTable(state.playlistSongs, $("#pl-tbody"), {
      mode: "playlist",
      playlistId: state.activePlaylistId,
    });
    renderSongCards(state.playlistSongs, $("#pl-cards"), {
      mode: "playlist",
      playlistId: state.activePlaylistId,
    });
  }
}

audio.addEventListener("error", () => {
  const song = state.queue[state.queueIndex];
  if (!song) return;
  if (!song._triedTranscode) {
    song._triedTranscode = true;
    toast("解码失败，尝试转码…");
    playCurrent({ forceTranscode: true });
  }
});

function updateNowPlaying(song) {
  $("#now-title").textContent = song.title;
  $("#now-artist").textContent = `${song.artist} · ${song.album}`;
  const cover = $("#now-cover");
  if (song.cover_url) {
    cover.innerHTML = `<img src="${song.cover_url}" alt="" />`;
  } else {
    cover.textContent = "♪";
  }
  if ("mediaSession" in navigator) {
    navigator.mediaSession.metadata = new MediaMetadata({
      title: song.title,
      artist: song.artist,
      album: song.album,
      artwork: song.cover_url
        ? [{ src: song.cover_url, sizes: "300x300", type: "image/jpeg" }]
        : [],
    });
    navigator.mediaSession.setActionHandler("previoustrack", () => prev());
    navigator.mediaSession.setActionHandler("nexttrack", () => next());
    navigator.mediaSession.setActionHandler("play", () => audio.play());
    navigator.mediaSession.setActionHandler("pause", () => audio.pause());
  }
}

function togglePlay() {
  if (partyClient?.isInRoom && !state.partyApplying && !partyClient.isHost && !partyClient.can("play_pause")) {
    toast("一起听中：无播放/暂停权限");
    return;
  }
  if (!audio.src) {
    if (state.songs.length) {
      if (state.shuffle) playShuffleAll();
      else playFromList(state.songs, 0);
    }
    return;
  }
  if (audio.paused) {
    ensureEqOnPlayback().finally(() => {
      audio.play().catch(() => {});
    });
    if (partyClient?.isInRoom && !state.partyApplying && partyClient.can("play_pause")) {
      partyClient.control("play", { position: audio.currentTime || 0 });
    }
  } else {
    audio.pause();
    if (partyClient?.isInRoom && !state.partyApplying && partyClient.can("play_pause")) {
      partyClient.control("pause", { position: audio.currentTime || 0 });
    }
  }
}

function next(fromEnded = false) {
  if (!state.queue.length) return;
  // 一起听：非房主播完不自切；有 skip 的管理员点下一首走服务端
  if (partyClient?.isInRoom && !state.partyApplying) {
    if (fromEnded && !partyClient.isHost) return;
    if (!fromEnded && !partyClient.isHost) {
      if (!partyClient.can("skip")) {
        toast("一起听中：无切歌权限");
        return;
      }
      partyClient.control("next");
      return;
    }
  }
  if (fromEnded && state.loopMode === "one") {
    audio.currentTime = 0;
    audio.play().catch(() => {});
    return;
  }
  const atEnd = state.queueIndex >= state.queue.length - 1;
  if (atEnd) {
    if (fromEnded && state.loopMode === "off") {
      audio.pause();
      $("#btn-play").textContent = "▶";
      if (partyClient?.isHost) {
        partyClient.control("pause", { position: audio.currentTime || 0 });
      }
      return;
    }
    if (state.shuffle) {
      const current = state.queue[state.queueIndex];
      const base = state.orderQueue && state.orderQueue.length ? state.orderQueue : state.queue;
      const rest = shuffleArray(base.filter((s) => s.id !== current.id));
      state.queue = [current, ...rest];
      state.queueIndex = rest.length ? 1 : 0;
    } else {
      state.queueIndex = 0;
    }
  } else {
    state.queueIndex += 1;
  }
  playCurrent();
  if (partyClient?.isInRoom && !state.partyApplying && partyClient.isHost) {
    partyBroadcastQueueIfHost();
  }
}

function updateLoopUi() {
  const btn = $("#btn-loop");
  if (!btn) return;
  const map = { off: ["➡", "循环：播完停止"], all: ["🔁", "循环：列表循环"], one: ["🔂", "循环：单曲循环"] };
  const [icon, title] = map[state.loopMode] || map.all;
  btn.textContent = icon;
  btn.title = title;
  btn.classList.toggle("active", state.loopMode !== "off");
}

function cycleLoop() {
  state.loopMode = state.loopMode === "off" ? "all" : state.loopMode === "all" ? "one" : "off";
  localStorage.setItem("mh_loop", state.loopMode);
  updateLoopUi();
  toast(state.loopMode === "off" ? "播完停止" : state.loopMode === "all" ? "列表循环" : "单曲循环");
}

function setSleep(minutes) {
  if (state.sleepTimer) clearInterval(state.sleepTimer);
  state.sleepFade = false;
  applyOutputVolume();
  if (!minutes) {
    state.sleepUntil = null;
    state.sleepTimer = null;
    toast("已取消睡眠定时");
    updateSleepUi();
    return;
  }
  state.sleepUntil = Date.now() + minutes * 60 * 1000;
  const fadeSec = 30;
  state.sleepTimer = setInterval(() => {
    if (!state.sleepUntil) return;
    const leftMs = state.sleepUntil - Date.now();
    if (leftMs <= 0) {
      clearInterval(state.sleepTimer);
      state.sleepTimer = null;
      state.sleepUntil = null;
      state.sleepFade = false;
      audio.pause();
      applyOutputVolume();
      updateSleepUi();
      toast("睡眠定时到，已暂停");
      return;
    }
    const leftSec = leftMs / 1000;
    if (leftSec <= fadeSec) {
      state.sleepFade = true;
      audio.volume = Math.max(0, state.userVolume * state.sceneVolume * (leftSec / fadeSec));
    }
    updateSleepUi();
  }, 500);
  toast(`睡眠定时 ${minutes} 分钟（结束前 30 秒淡出）`);
  updateSleepUi();
}

function updateSleepUi() {
  const btn = $("#btn-sleep");
  if (!btn) return;
  if (state.sleepUntil) {
    const m = Math.max(0, Math.ceil((state.sleepUntil - Date.now()) / 60000));
    btn.textContent = state.sleepFade ? "🔉" : "⏱";
    btn.title = state.sleepFade ? "睡眠淡出中" : `睡眠剩余约 ${m} 分`;
    btn.classList.add("active");
  } else {
    btn.textContent = "⏱";
    btn.title = "睡眠定时";
    btn.classList.remove("active");
  }
}

function cycleSpeed() {
  const opts = [0.75, 1, 1.25, 1.5];
  let i = opts.indexOf(state.speed);
  if (i < 0) i = 1;
  state.speed = opts[(i + 1) % opts.length];
  audio.playbackRate = state.speed;
  localStorage.setItem("mh_speed", String(state.speed));
  updateSpeedUi();
  toast(`速度 ${state.speed}x`);
}

function updateSpeedUi() {
  const btn = $("#btn-speed");
  if (btn) {
    btn.textContent = `${state.speed}x`;
    btn.title = `播放速度 ${state.speed}x`;
  }
}

function playNextSong(song) {
  if (!state.queue.length || state.queueIndex < 0) {
    playFromList([song], 0);
    toast("开始播放");
    return;
  }
  state.queue.splice(state.queueIndex + 1, 0, song);
  if (state.view === "queue") renderQueueView();
  toast("已设为下一首播放");
}

function addToQueueEnd(song) {
  if (!state.queue.length || state.queueIndex < 0) {
    playFromList([song], 0);
    return;
  }
  state.queue.push(song);
  if (state.view === "queue") renderQueueView();
  toast("已加到队列末尾");
}

async function loadRecent() {
  try {
    state.recent = await api("/api/recent?limit=80");
  } catch {
    state.recent = [];
  }
  renderSongTable(state.recent, $("#recent-tbody"), { mode: "library" });
  renderSongCards(state.recent, $("#recent-cards"), { mode: "library" });
  const empty = $("#empty-recent");
  if (empty) empty.hidden = state.recent.length > 0;
}

function renderQueueView() {
  const list = state.queue || [];
  renderSongTable(list, $("#queue-tbody"), { mode: "library" });
  renderSongCards(list, $("#queue-cards"), { mode: "library" });
  const empty = $("#empty-queue");
  if (empty) empty.hidden = list.length > 0;
  $("#view-sub").textContent = list.length ? `队列 ${state.queueIndex + 1}/${list.length}` : "队列为空";
}

function prev() {
  if (!state.queue.length) return;
  if (partyClient?.isInRoom && !state.partyApplying && !partyClient.isHost) {
    if (audio.currentTime > 3) {
      if (!partyClient.can("seek")) {
        toast("一起听中：无拖动进度权限");
        return;
      }
      partyClient.control("seek", { position: 0 });
      return;
    }
    if (!partyClient.can("skip")) {
      toast("一起听中：无切歌权限");
      return;
    }
    partyClient.control("prev");
    return;
  }
  if (audio.currentTime > 3) {
    audio.currentTime = 0;
    if (partyClient?.isInRoom && !state.partyApplying && partyClient.isHost) {
      partyClient.control("seek", { position: 0 });
    }
    return;
  }
  state.queueIndex = (state.queueIndex - 1 + state.queue.length) % state.queue.length;
  playCurrent();
  if (partyClient?.isInRoom && !state.partyApplying && partyClient.isHost) {
    partyBroadcastQueueIfHost();
  }
}

audio.addEventListener("play", () => {
  $("#btn-play").textContent = "⏸";
});
audio.addEventListener("pause", () => {
  $("#btn-play").textContent = "▶";
});
audio.addEventListener("ended", () => next(true));
audio.addEventListener("timeupdate", () => {
  if (state.seeking || !audio.duration) return;
  const ratio = audio.currentTime / audio.duration;
  $("#seek").value = String(Math.floor(ratio * 1000));
  $("#time-cur").textContent = fmtTime(audio.currentTime);
  $("#time-dur").textContent = fmtTime(audio.duration);
});
audio.addEventListener("loadedmetadata", () => {
  $("#time-dur").textContent = fmtTime(audio.duration);
});

$("#seek").addEventListener("pointerdown", () => {
  state.seeking = true;
});
$("#seek").addEventListener("pointerup", () => {
  if (audio.duration) {
    if (partyClient?.isInRoom && !state.partyApplying && !partyClient.isHost && !partyClient.can("seek")) {
      toast("一起听中：无拖动进度权限");
      state.seeking = false;
      return;
    }
    const t = (Number($("#seek").value) / 1000) * audio.duration;
    audio.currentTime = t;
    if (partyClient?.isInRoom && !state.partyApplying && (partyClient.isHost || partyClient.can("seek"))) {
      partyClient.control("seek", { position: t });
    }
  }
  state.seeking = false;
});
$("#seek").addEventListener("input", () => {
  if (!state.seeking || !audio.duration) return;
  const t = (Number($("#seek").value) / 1000) * audio.duration;
  $("#time-cur").textContent = fmtTime(t);
});
$("#volume").addEventListener("input", (e) => {
  state.userVolume = Number(e.target.value);
  localStorage.setItem("mh_vol", String(state.userVolume));
  applyOutputVolume();
});
$("#btn-play").addEventListener("click", togglePlay);
$("#btn-scene")?.addEventListener("click", (e) => {
  e.stopPropagation();
  const pop = $("#scene-popover");
  if (!pop) return;
  setScenePopoverOpen(pop.hidden);
});
document.addEventListener("click", (e) => {
  const pop = $("#scene-popover");
  const btn = $("#btn-scene");
  if (!pop || pop.hidden) return;
  if (pop.contains(e.target) || btn?.contains(e.target)) return;
  setScenePopoverOpen(false);
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") setScenePopoverOpen(false);
});
$("#btn-next").addEventListener("click", () => next(false));
$("#btn-prev").addEventListener("click", prev);
$("#btn-shuffle").addEventListener("click", toggleShuffle);
$("#btn-shuffle-all").addEventListener("click", playShuffleAll);
$("#btn-shuffle-order")?.addEventListener("click", () => {
  if (!state.songs || state.songs.length < 2) {
    toast("列表太短，无法打乱");
    return;
  }
  // Fisher–Yates
  const arr = state.songs.slice();
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  state.songs = arr;
  renderLibrary();
  toast("已打乱曲库列表顺序");
});
$("#btn-loop")?.addEventListener("click", cycleLoop);
$("#btn-speed")?.addEventListener("click", cycleSpeed);
$("#btn-sleep")?.addEventListener("click", () => {
  if (state.sleepUntil) {
    setSleep(0);
    return;
  }
  const m = prompt("睡眠定时（分钟）\n例如 15 / 30 / 60，取消填 0", "30");
  if (m == null) return;
  const n = Number(m);
  if (!n) setSleep(0);
  else setSleep(n);
});
$("#btn-clear-queue")?.addEventListener("click", () => {
  const cur = state.queue[state.queueIndex];
  if (!cur) return;
  state.queue = [cur];
  state.queueIndex = 0;
  state.orderQueue = [cur];
  renderQueueView();
  toast("已清空队列（保留当前）");
});

function setView(name) {
  state.view = name;
  $$(".nav-btn").forEach((b) => b.classList.toggle("active", b.dataset.view === name));
  $("#view-library").hidden = name !== "library";
  $("#view-recent").hidden = name !== "recent";
  $("#view-queue").hidden = name !== "queue";
  $("#view-playlists").hidden = name !== "playlists";
  $("#view-party").hidden = name !== "party";
  $("#view-settings").hidden = name !== "settings";
  $("#playlist-nav").hidden = name !== "playlists";
  const titles = {
    library: "曲库",
    recent: "最近播放",
    queue: "播放队列",
    playlists: "歌单",
    party: "一起听",
    settings: "设置",
  };
  $("#view-title").textContent = titles[name] || name;
  if (name === "playlists") loadPlaylists();
  if (name === "settings") {
    loadStatus().then(() => loadLan().catch(() => {}));
  }
  if (name === "library") updateLibrarySub();
  if (name === "recent") {
    loadRecent();
    $("#view-sub").textContent = "最近听过的歌";
  }
  if (name === "queue") renderQueueView();
  if (name === "party") {
    $("#view-sub").textContent = "多设备同步播放";
    renderPartyUi();
  }
}

$("#btn-qr")?.addEventListener("click", openQrModal);
$("#btn-copy-lan")?.addEventListener("click", copyLanUrl);
$("#btn-modal-copy")?.addEventListener("click", copyLanUrl);
$("#btn-refresh-qr")?.addEventListener("click", async () => {
  try {
    await loadLan();
    toast("二维码已刷新");
  } catch (e) {
    toast(e.message);
  }
});
$("#btn-modal-refresh")?.addEventListener("click", async () => {
  try {
    await loadLan();
    toast("二维码已刷新");
  } catch (e) {
    toast(e.message);
  }
});
$$("[data-close-qr]").forEach((el) => el.addEventListener("click", closeQrModal));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") closeQrModal();
});

$$(".nav-btn").forEach((btn) => {
  btn.addEventListener("click", () => setView(btn.dataset.view));
});

let searchTimer;
$("#search").addEventListener("input", (e) => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    if (state.view === "library") loadSongs(e.target.value.trim());
  }, 280);
});

$("#btn-refresh").addEventListener("click", async () => {
  await loadStatus();
  await loadSongs($("#search").value.trim());
  toast("已刷新");
});

$("#btn-scan").addEventListener("click", async () => {
  const btn = $("#btn-scan");
  btn.disabled = true;
  btn.textContent = "扫描中…";
  try {
    const r = await api("/api/scan", { method: "POST" });
    const w = r.warnings?.length || 0;
    const e = r.errors?.length || 0;
    let msg = `扫描完成：+${r.added} / 更新 ${r.updated} / 移除 ${r.removed}`;
    if (w) msg += ` · ${w} 个标签警告`;
    if (e) msg += ` · ${e} 个失败`;
    toast(msg, w || e ? 4500 : 2600);
    await loadStatus();
    await loadSongs($("#search").value.trim());
    if (r.warnings?.length) console.warn("scan warnings", r.warnings);
    if (r.errors?.length) console.warn("scan errors", r.errors);
  } catch (e) {
    toast("扫描失败：" + e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = "扫描曲库";
  }
});

$("#btn-set-library").addEventListener("click", async () => {
  const path = $("#library-path").value.trim();
  if (!path) return toast("请填写路径");
  try {
    await api("/api/library", { method: "POST", body: JSON.stringify({ path }) });
    toast("路径已保存，请点击「扫描曲库」");
    await loadStatus();
  } catch (e) {
    toast("保存失败：" + e.message);
  }
});

async function loadPlaylists() {
  state.playlists = await api("/api/playlists");
  const ul = $("#playlist-list");
  ul.innerHTML = "";
  state.playlists.forEach((pl) => {
    const li = document.createElement("li");
    li.dataset.id = pl.id;
    if (state.activePlaylistId === pl.id) li.classList.add("active");
    li.innerHTML = `<span>${escapeHtml(pl.name)}</span><span class="muted">${pl.song_count}</span>`;
    li.addEventListener("click", () => openPlaylist(pl.id));
    ul.appendChild(li);
  });
}

async function openPlaylist(id) {
  state.activePlaylistId = id;
  await loadPlaylists();
  const songs = await api(`/api/playlists/${id}/songs`);
  state.playlistSongs = songs;
  const pl = state.playlists.find((p) => p.id === id);
  $("#view-sub").textContent = pl ? `${pl.name} · ${songs.length} 首` : "歌单";
  const box = $("#playlist-detail");
  box.innerHTML = `
    <div class="table-wrap desktop-only">
      <table class="song-table">
        <thead>
          <tr>
            <th style="width:3rem">#</th>
            <th>标题</th>
            <th>艺人</th>
            <th>专辑</th>
            <th style="width:5rem">格式</th>
            <th style="width:5rem">时长</th>
            <th style="width:6rem"></th>
          </tr>
        </thead>
        <tbody id="pl-tbody"></tbody>
      </table>
    </div>
    <div id="pl-cards" class="song-cards mobile-only"></div>
    <p class="muted pl-hint">在曲库中点「+歌单」可把歌曲加入歌单。</p>
  `;
  renderSongTable(songs, $("#pl-tbody"), { mode: "playlist", playlistId: id });
  renderSongCards(songs, $("#pl-cards"), { mode: "playlist", playlistId: id });
  if (!songs.length) {
    box.insertAdjacentHTML("beforeend", `<p class="empty">这个歌单还是空的</p>`);
  }
}

$("#btn-create-playlist").addEventListener("click", async () => {
  const name = $("#new-playlist-name").value.trim();
  if (!name) return toast("请输入歌单名");
  try {
    const pl = await api("/api/playlists", { method: "POST", body: JSON.stringify({ name }) });
    $("#new-playlist-name").value = "";
    toast("已创建 " + pl.name);
    await loadPlaylists();
    openPlaylist(pl.id);
  } catch (e) {
    toast("创建失败：" + e.message);
  }
});

async function addSongToPlaylistPrompt(songId) {
  if (!state.playlists.length) {
    state.playlists = await api("/api/playlists");
  }
  if (!state.playlists.length) {
    toast("请先在「歌单」里创建一个歌单");
    setView("playlists");
    return;
  }
  let pid = state.activePlaylistId;
  if (!pid) {
    const names = state.playlists.map((p, i) => `${i + 1}. ${p.name}`).join("\n");
    const pick = prompt(`加入哪个歌单？输入序号：\n${names}`, "1");
    if (!pick) return;
    const idx = Number(pick) - 1;
    if (!state.playlists[idx]) return toast("无效序号");
    pid = state.playlists[idx].id;
  }
  await api(`/api/playlists/${pid}/songs`, {
    method: "POST",
    body: JSON.stringify({ song_ids: [songId] }),
  });
  toast("已加入歌单");
  if (state.view === "playlists" && state.activePlaylistId === pid) openPlaylist(pid);
  loadPlaylists();
}

// boot
(async function init() {
  applyTheme(state.themeId, { silent: true });

  // 恢复场景软音量（EQ 在首次播放手势时再挂载）
  const bootScene = getScene(state.sceneId);
  state.sceneVolume = typeof bootScene.volume === "number" ? bootScene.volume : 1;
  if (state.sceneId !== "default") {
    state.eqPreset = bootScene.eqPreset || state.eqPreset || "normal";
  }

  $("#volume").value = String(state.userVolume);
  applyOutputVolume();
  audio.playbackRate = state.speed;
  updateShuffleUi();
  updateLoopUi();
  updateSpeedUi();
  updateSleepUi();
  updateSceneUi();
  setupPartyUi();
  try {
    await loadStatus();
    await loadSongs();
    loadRecent().catch(() => {});
    loadLan().catch(() => {});
  } catch (e) {
    toast("无法连接服务：" + e.message);
  }
})();
