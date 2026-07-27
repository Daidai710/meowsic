# meowsic

私人 **局域网** 音乐库：电脑跑服务 + 网页播放器 + Flutter 客户端（**meowsic**）。

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
3. 点 **扫码连手机**（显示的是你自己的局域网地址）

防火墙请放行端口 **8787**。

### 2. 手机：听歌

| 方式 | 做法 |
|------|------|
| **浏览器（免安装）** | 与电脑同一 Wi‑Fi → 扫电脑网页二维码，或打开 `http://电脑IP:8787` |
| **安装 App** | 从 [Releases 下载 APK](https://github.com/Daidai710/meowsic/releases) → 安装 → 扫码或填 `http://电脑IP:8787` |

**手机上不要填 `127.0.0.1`**（那是手机自己，不是电脑）。

更细的说明：[FOR_OTHERS.md](./FOR_OTHERS.md) · [手机指南](./mobile/PHONE_GUIDE.md)

### 3. Windows 桌面客户端（可选）

需 [Flutter](https://docs.flutter.dev/get-started/install)：

```powershell
cd mobile
flutter pub get
flutter run -d windows
```

本机连接：`http://127.0.0.1:8787`。  
首次构建若提示 symlink，请打开 Windows「开发人员模式」。

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
  FOR_OTHERS.md    # 使用说明（各自曲库 + 手机）
  DEPLOY.md        # 更完整的部署说明
  LICENSE          # MIT
```

## 文档

| 文档 | 内容 |
|------|------|
| [FOR_OTHERS.md](./FOR_OTHERS.md) | 使用说明：各自曲库、网页 UI、手机 |
| [DEPLOY.md](./DEPLOY.md) | 服务端 / 网页 / Android / Windows 部署 |
| [mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md) | 手机连接与安装 |
| [mobile/README.md](./mobile/README.md) | Flutter 客户端开发 |
| [server/README.md](./server/README.md) | 服务端运行与配置 |

## 配置（可选）

| 方式 | 说明 |
|------|------|
| 环境变量 | `MUSIC_HUB_LIBRARY_PATH`、`MUSIC_HUB_PORT`、`MUSIC_HUB_FFMPEG_PATH` |
| `server/config.example.yaml` | 复制为 `config.yaml`（勿把真实配置提交到 git） |
| 网页设置 | 运行后修改曲库路径 |

可选访问密码：见 `server/data/access_password.example.txt`。

## 隐私与版权

- 仅用于**个人合法拥有**的本地音频  
- 请勿把真实密码、本机绝对路径配置、数据库提交到公开仓库  
- 开源协议：**MIT**（[LICENSE](./LICENSE)）

## 许可

MIT — 详见 [LICENSE](./LICENSE)。
