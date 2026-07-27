# 使用说明（各自电脑、各自曲库）

## 先读这句

meowsic **不是**「连到某个固定服务器听某个人的歌」。

| | 含义 |
|--|------|
| **各自部署** | 在 **你自己的电脑** 上运行 `server` |
| **曲库是你的** | 网页设置里选 **你电脑上的音乐文件夹** 并扫描 |
| **别人的电脑** | 你默认连不上，也听不到别人的歌 |
| **手机 App** | 只连「同一 Wi‑Fi 下、正在跑服务的那台电脑」 |

```
你的电脑 ──跑 server──► 扫描你的音乐文件夹 ──► 你的手机装 App / 浏览器扫码
朋友的电脑 ──跑 server──► 扫描朋友的音乐文件夹 ──► 朋友的手机连朋友的电脑
```

## UI 从哪来

| UI | 来源 |
|----|------|
| 网页播放器 | 启动 server 后打开 http://127.0.0.1:8787 |
| 手机 App | [下载 meowsic-v23.apk](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk) · [全部 Releases](https://github.com/Daidai710/meowsic/releases) |
| Windows 桌面端 | 可选：用 Flutter 自行编译（见 README） |

## 怎么用

### 1. 电脑

1. 安装 [Python 3.10+](https://www.python.org/downloads/)  
2. 下载本仓库（Code → Download ZIP，或 `git clone`）  
3. 双击 `server\Start-Music-Hub.bat`（或根目录 `Start-All.bat`）  
4. 浏览器打开 http://127.0.0.1:8787  
5. **设置** → 填 **本机** 音乐文件夹 → **扫描曲库**  
6. 点 **扫码连手机**  

### 2. 手机

1. 打开 [Releases](https://github.com/Daidai710/meowsic/releases) 下载 APK 并安装  
   - 若暂时没有 APK：用手机浏览器打开电脑网页上的局域网地址即可  
2. 与电脑同一 Wi‑Fi  
3. App 内 **扫码** 或填写 `http://电脑局域网IP:8787`  
4. **不要**填 `127.0.0.1`  

### 3. 防火墙

Windows 若拦截，请允许 Python / 端口 **8787** 入站。

## 常见问题

| 现象 | 处理 |
|------|------|
| 手机打不开 | 是否同一 Wi‑Fi；地址是否为电脑局域网 IP |
| 没有歌 | 是否在网页里扫描了 **本机** 文件夹 |
| 关掉电脑就听不了 | 正常：服务跑在你电脑上，关机即停 |

更细的部署见 [DEPLOY.md](./DEPLOY.md)、[mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md)。
