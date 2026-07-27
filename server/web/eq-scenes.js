/**
 * Web 端场景 EQ（独立于 Flutter App）
 * - 曲线数值参考 Android 系统 EQ 的 mB 预设（听感接近即可，不必逐 dB 一致）
 * - 使用 Web Audio API：MediaElementSource → 多段 peaking → destination
 */
(function (global) {
  "use strict";

  /** 典型 5 段中心频率 (Hz) */
  const EQ_BANDS_HZ = [60, 230, 910, 3600, 14000];

  /** EQ 预设：5 段增益，单位 mB（100 mB ≈ 1 dB） */
  const EQ_CURVES = {
    normal: [0, 0, 0, 0, 0],
    pop: [350, 150, -100, 250, 450],
    bass: [900, 600, 150, 0, -150],
    vocal: [-250, 50, 700, 550, 150],
    treble: [-250, -100, 50, 550, 900],
    classical: [450, 200, 0, 250, 450],
    rock: [500, 200, -50, 300, 500],
    jazz: [300, 100, 100, 200, 300],
    electronic: [700, 200, -100, 200, 600],
    hiphop: [800, 400, 0, 150, 250],
    dance: [600, 200, -50, 350, 550],
    acoustic: [100, 200, 250, 150, 50],
    podcast: [-300, 100, 600, 400, -100],
    cinematic: [550, 250, 0, 200, 400],
    lofi: [400, 150, -200, -100, -300],
    sad_ballad: [-100, 100, 400, 250, -50],
  };

  /**
   * 听感场景：EQ + 可选速度 / 软音量
   * 语义与 App 的 scene_presets 一致，但实现与 UI 完全独立。
   */
  const SCENE_PRESETS = [
    {
      id: "default",
      label: "默认",
      description: "不额外染色，按当前均衡器设置",
      eqPreset: "normal",
      speed: 1.0,
      volume: 1.0,
    },
    {
      id: "cinematic",
      label: "Cinematic",
      description: "电影感：低频厚实、中高频开阔",
      eqPreset: "cinematic",
      speed: 1.0,
      volume: 0.95,
    },
    {
      id: "lofi",
      label: "Lo-fi",
      description: "柔和滚降高音，略慢一点更松弛",
      eqPreset: "lofi",
      speed: 0.95,
      volume: 0.9,
    },
    {
      id: "sad_ballad",
      label: "Sad Ballad",
      description: "人声与中频靠前，适合抒情慢歌",
      eqPreset: "sad_ballad",
      speed: 0.98,
      volume: 0.92,
    },
    {
      id: "night_drive",
      label: "Night Drive",
      description: "低音推进 + 高音轮廓，适合夜驾",
      eqPreset: "electronic",
      speed: 1.0,
      volume: 0.95,
    },
    {
      id: "focus",
      label: "Focus",
      description: "削弱低频轰鸣，中高频干净，利于专注",
      eqPreset: "podcast",
      speed: 1.0,
      volume: 0.85,
    },
    {
      id: "party",
      label: "Party",
      description: "舞曲感，低音与空气感更足",
      eqPreset: "dance",
      speed: 1.0,
      volume: 1.0,
    },
    {
      id: "acoustic_cafe",
      label: "Acoustic Café",
      description: "原声温暖，中频自然",
      eqPreset: "acoustic",
      speed: 1.0,
      volume: 0.9,
    },
    {
      id: "hiphop_street",
      label: "Hip-Hop",
      description: "重低频与节奏感",
      eqPreset: "hiphop",
      speed: 1.0,
      volume: 0.95,
    },
    {
      id: "bright_pop",
      label: "Bright Pop",
      description: "流行曲明亮贴耳",
      eqPreset: "pop",
      speed: 1.0,
      volume: 0.95,
    },
  ];

  function getScene(id) {
    return SCENE_PRESETS.find((s) => s.id === id) || SCENE_PRESETS[0];
  }

  function getCurve(eqPreset) {
    return EQ_CURVES[eqPreset] || EQ_CURVES.normal;
  }

  /**
   * @param {HTMLAudioElement} audioEl
   */
  function createEqEngine(audioEl) {
    let ctx = null;
    let source = null;
    /** @type {BiquadFilterNode[]} */
    let filters = [];
    let ready = false;
    let failed = false;
    /** 待应用的曲线（图未建好时缓存） */
    let pendingLevels = null;

    function ensure() {
      if (ready) return true;
      if (failed || !audioEl) return false;
      try {
        const AC = global.AudioContext || global.webkitAudioContext;
        if (!AC) {
          failed = true;
          return false;
        }
        ctx = new AC();
        source = ctx.createMediaElementSource(audioEl);
        let node = source;
        filters = EQ_BANDS_HZ.map((hz) => {
          const f = ctx.createBiquadFilter();
          f.type = "peaking";
          f.frequency.value = hz;
          f.Q.value = 1.0;
          f.gain.value = 0;
          node.connect(f);
          node = f;
          return f;
        });
        node.connect(ctx.destination);
        ready = true;
        if (pendingLevels) {
          applyLevelsMb(pendingLevels);
          pendingLevels = null;
        }
        return true;
      } catch (e) {
        console.warn("[Music Hub] Web EQ init failed:", e);
        failed = true;
        return false;
      }
    }

    async function resume() {
      if (!ensure()) return false;
      if (ctx && ctx.state === "suspended") {
        try {
          await ctx.resume();
        } catch (_) {}
      }
      return true;
    }

    function applyLevelsMb(levelsMb) {
      const levels = levelsMb || EQ_CURVES.normal;
      if (!ready) {
        pendingLevels = levels.slice();
        ensure();
        if (!ready) return;
      }
      for (let i = 0; i < filters.length; i++) {
        const mb = levels[i] != null ? levels[i] : 0;
        // peaking gain 单位为 dB
        filters[i].gain.value = mb / 100;
      }
    }

    function applyEqPreset(name) {
      applyLevelsMb(getCurve(name));
    }

    return {
      ensure,
      resume,
      applyLevelsMb,
      applyEqPreset,
      get ready() {
        return ready;
      },
      get available() {
        return !failed && !!(global.AudioContext || global.webkitAudioContext);
      },
      bandsHz: EQ_BANDS_HZ.slice(),
    };
  }

  global.MusicHubEq = {
    EQ_BANDS_HZ,
    EQ_CURVES,
    SCENE_PRESETS,
    getScene,
    getCurve,
    createEqEngine,
  };
})(typeof window !== "undefined" ? window : globalThis);
