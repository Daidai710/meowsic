# meowsic

私人 **局域网** 音乐库：电脑跑服务 + 网页播放器 + Flutter 客户端（**meowsic**）。

只播放 **你自己电脑上的** 本地音乐，**不依赖公网曲库 / 云音乐 API**。  
**每个人在自己电脑上运行服务、扫描自己的曲库**——不会连到别人的电脑（除非你自己做穿透分享）。

```
【用户自己的电脑】
  server 扫描「本机音乐文件夹」
       ▲
       │ 同一 Wi‑Fi
  手机 App / 浏览器 ──► 只连这台电脑 (:8787)
```

> 给他人使用说明（各自曲库 + APK 下载）：见 **[FOR_OTHERS.md](./FOR_OTHERS.md)**  
> Android 安装包：仓库 **[Releases](../../releases)**（上传后把链接写进此处）

## 仓库结构

```
meowsic/                 # 本仓库
  server/                # Python 服务 + 网页播放器
  mobile/                # Flutter 客户端（Android / Windows）
  Start-All.bat          # 一键：服务 + 浏览器 + 桌面端（若已编译）
  LICENSE
  README.md
  DEPLOY.md              # 电脑端 / 手机端部署
  GITHUB_UPLOAD.md       # 如何上传到你的 GitHub（从登录开始）
```

## 功能概览

| 端 | 能力 |
|----|------|
| **电脑服务** | 扫描本机音乐目录、流式播放、歌单、封面、最近播放、可选访问密码 |
| **网页** | 同 Wi‑Fi 浏览器即可听；扫码给手机连 |
| **Flutter App** | 扫码连接、曲库/歌单/队列、听感场景、Android EQ、一起听、本机曲库等 |
| **一起听** | 同步房间或共用曲库各自听 |

## 最快上手（Windows）

### 1. 启动服务

需要 **Python 3.10+**。可选 FFmpeg（个别冷门格式转码）。

```bat
server\Start-Music-Hub.bat
```

或一键（服务 + 打开网页 + 若已编译则启动桌面 App）：

```bat
Start-All.bat
```

- 本机网页：http://127.0.0.1:8787  
- 首次在网页 **设置** 里填音乐文件夹并 **扫描曲库**

### 2. 手机（两种）

| 方式 | 说明 |
|------|------|
| **浏览器** | 与电脑同一 Wi‑Fi → 扫网页「扫码连手机」或打开 `http://电脑IP:8787` |
| **安装 App** | 见 [DEPLOY.md](./DEPLOY.md) 打包 APK，或 [PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md) |

App 连接地址示例：`http://192.168.x.x:8787`  
**手机上不要填 `127.0.0.1`**（那是手机自己）。

### 3. Windows 桌面客户端

```powershell
cd mobile
flutter pub get
flutter run -d windows
```

连接填：`http://127.0.0.1:8787`（本机）。  
首次构建需打开 Windows **开发人员模式**（见 `mobile/Enable-DevMode-Then-Run.bat`）。

## 文档

| 文档 | 内容 |
|------|------|
| [FOR_OTHERS.md](./FOR_OTHERS.md) | **给别人用：各自曲库 + 网页 UI + APK 下载** |
| [DEPLOY.md](./DEPLOY.md) | 服务端 / 网页 / Android / Windows 部署与发布 |
| [mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md) | 手机连接与安装说明 |
| [mobile/README.md](./mobile/README.md) | Flutter 客户端开发 |
| [server/README.md](./server/README.md) | 服务端运行与配置 |
| [GITHUB_UPLOAD.md](./GITHUB_UPLOAD.md) | 上传到个人 GitHub（从登录开始） |

## 配置

| 方式 | 说明 |
|------|------|
| 环境变量 | `MUSIC_HUB_LIBRARY_PATH`、`MUSIC_HUB_PORT`、`MUSIC_HUB_FFMPEG_PATH` |
| `server/config.example.yaml` | 复制为 `config.yaml`（勿提交真实配置） |
| 网页设置 | 运行后修改曲库路径 |

可选访问密码：见 `server/data/access_password.example.txt`。

## 隐私与版权

- 仅用于**个人合法拥有**的本地音频  
- 请勿提交：曲库路径写死的配置、密码、`data/music.db`、`.venv`、APK  
- 开源协议：**MIT**（[LICENSE](./LICENSE)）

## 许可

MIT — 详见 [LICENSE](./LICENSE)。
