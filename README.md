<p align="center">
  <img src="mobile/assets/icons/meowsic_icon_256.png" width="120" alt="meowsic logo">
</p>

<h1 align="center">meowsic</h1>

<p align="center">
  私人局域网音乐库 · <a href="README.en.md">English</a><br>
  <strong>你的电脑 · 你的曲库 · 你的手机</strong>
</p>

<p align="center">
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><img src="https://img.shields.io/github/v/release/Daidai710/meowsic?label=release&color=brightgreen" alt="release"></a>
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><img src="https://img.shields.io/github/downloads/Daidai710/meowsic/total?label=downloads" alt="downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license"></a>
  <a href="https://github.com/Daidai710/meowsic/stargazers"><img src="https://img.shields.io/github/stars/Daidai710/meowsic?style=social" alt="stars"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20Web-informational" alt="platform">
</p>

<p align="center">
  <a href="https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk"><strong>⬇ 下载 Android APK</strong></a>
  ·
  <a href="USAGE.md">使用说明</a>
  ·
  <a href="DEPLOY.md">进阶部署</a>
  ·
  <a href="README.en.md">English</a>
</p>

---

只播放 **你自己电脑上的** 本地音乐，不依赖公网曲库。  
**每个人在自己电脑上运行服务、扫描自己的曲库**——不会连到别人的电脑。

```
【你自己的电脑】
  server 扫描「本机音乐文件夹」
       ▲
       │ 同一 Wi‑Fi
  手机 App / 浏览器 ──► 只连这台电脑 (:8787)
```

## 快速开始

1. 安装 [Python 3.10+](https://www.python.org/downloads/)  
2. 下载本仓库 → 双击 `Start-All.bat`  
3. 打开 http://127.0.0.1:8787 → **设置** 本机音乐文件夹 → **扫描**  
4. 手机下载 [APK](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk)，同 Wi‑Fi **扫码连接**  
   （或用手机浏览器打开电脑给出的局域网地址）  

**手机不要填 `127.0.0.1`。** 防火墙请放行 **8787**。

完整步骤与常见问题 → **[USAGE.md](./USAGE.md)**

## 功能

| 端 | 能力 |
|----|------|
| **电脑服务** | 扫描本机音乐、流式播放、歌单、封面、可选访问密码 |
| **网页** | 同 Wi‑Fi 即可听；扫码给手机连 |
| **App** | 扫码、曲库/歌单/队列、听感场景、EQ、一起听等 |

## 仓库结构

```
server/     Python 服务 + 网页
mobile/     Flutter 客户端
USAGE.md    使用说明
DEPLOY.md   进阶配置 / 编译
README.en.md
```

## 许可

仅用于**个人合法拥有**的本地音频。  
**MIT** — 详见 [LICENSE](./LICENSE)。欢迎 Star。
