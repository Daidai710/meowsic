<p align="center">
  <img src="mobile/assets/icons/meowsic_icon_256.png" width="120" alt="meowsic logo">
</p>

<h1 align="center">meowsic</h1>

<p align="center">
  私人局域网音乐库 · Personal self-hosted music hub<br>
  <strong>你的电脑 · 你的曲库 · 你的手机</strong>
</p>

<p align="center">
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><img src="https://img.shields.io/github/v/release/Daidai710/meowsic?label=release&color=brightgreen" alt="release"></a>
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><img src="https://img.shields.io/github/downloads/Daidai710/meowsic/total?label=downloads" alt="downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license"></a>
  <a href="https://github.com/Daidai710/meowsic/stargazers"><img src="https://img.shields.io/github/stars/Daidai710/meowsic?style=social" alt="stars"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20Web-informational" alt="platform">
  <img src="https://img.shields.io/badge/stack-Python%20%7C%20Flutter-orange" alt="stack">
</p>

<p align="center">
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><strong>⬇ 下载 Android APK</strong></a>
  ·
  <a href="#快速开始">快速开始</a>
  ·
  <a href="FOR_OTHERS.md">使用说明</a>
  ·
  <a href="DEPLOY.md">部署</a>
</p>

---

只播放 **你自己电脑上的** 本地音乐，不依赖公网曲库 / 云音乐。  
**每个人在自己电脑上运行服务、扫描自己的曲库**——不会连到别人的电脑。

```
【你自己的电脑】
  server 扫描「本机音乐文件夹」
       ▲
       │ 同一 Wi‑Fi
  手机 App / 浏览器 ──► 只连这台电脑 (:8787)
```

## 快速开始

### 1. 电脑：启动服务（建你自己的曲库）

需要 [Python 3.10+](https://www.python.org/downloads/)。

```bat
server\Start-Music-Hub.bat
```

或根目录一键（服务 + 打开网页）：

```bat
Start-All.bat
```

1. 浏览器打开 http://127.0.0.1:8787  
2. **设置** → 填写 **本机** 音乐文件夹 → **扫描曲库**  
3. 点 **扫码连手机**

防火墙请放行端口 **8787**。

### 2. 手机：听歌

| 方式 | 做法 |
|------|------|
| **安装 App（推荐）** | [下载 meowsic-v23.apk](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk) 或打开 [Releases](https://github.com/Daidai710/meowsic/releases/latest) → 安装 → 扫码连接 |
| **浏览器（免安装）** | 与电脑同一 Wi‑Fi → 扫电脑网页二维码，或打开 `http://电脑IP:8787` |

**手机上不要填 `127.0.0.1`**（那是手机自己，不是电脑）。

### 3. Windows 桌面客户端（可选）

需 [Flutter](https://docs.flutter.dev/get-started/install)：

```powershell
cd mobile
flutter pub get
flutter run -d windows
```

本机连接：`http://127.0.0.1:8787`。

## 功能

| 端 | 能力 |
|----|------|
| **电脑服务** | 扫描本机音乐、流式播放、歌单、封面、最近播放、可选访问密码 |
| **网页** | 同 Wi‑Fi 即可听；扫码给手机连 |
| **App** | 扫码连接、曲库/歌单/队列、听感场景、EQ、一起听等 |
| **一起听** | 同步房间，或共用曲库各自听 |

## 仓库结构

```
meowsic/
  server/          # Python 服务 + 网页播放器
  mobile/          # Flutter 客户端（Android / Windows）
  Start-All.bat    # 一键启动
  FOR_OTHERS.md    # 使用说明
  DEPLOY.md        # 部署说明
  LICENSE          # MIT
```

## 文档

| 文档 | 内容 |
|------|------|
| [FOR_OTHERS.md](./FOR_OTHERS.md) | 使用说明：各自曲库、网页、手机 |
| [DEPLOY.md](./DEPLOY.md) | 完整部署 |
| [mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md) | 手机连接 |
| [mobile/README.md](./mobile/README.md) | Flutter 开发 |
| [server/README.md](./server/README.md) | 服务端配置 |

## 配置（可选）

| 方式 | 说明 |
|------|------|
| 环境变量 | `MUSIC_HUB_LIBRARY_PATH`、`MUSIC_HUB_PORT`、`MUSIC_HUB_FFMPEG_PATH` |
| `server/config.example.yaml` | 复制为 `config.yaml` 后按本机路径修改 |
| 网页设置 | 运行后修改曲库路径 |

## 隐私与版权

- 仅用于**个人合法拥有**的本地音频  
- 开源协议：**MIT**（[LICENSE](./LICENSE)）

如果觉得有用，欢迎点右上角 **Star**。

## 许可

MIT — 详见 [LICENSE](./LICENSE)。
