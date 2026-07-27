# 给其他人用 meowsic（各自电脑、各自曲库）

## 核心说明（请先读）

meowsic **不是**「连到某个固定服务器听某个人的歌」。

| | 含义 |
|--|------|
| **每人各自部署** | 对方在 **自己的电脑** 上运行 `server` |
| **曲库是对方自己的** | 在网页设置里选 **对方电脑上的音乐文件夹** 并扫描 |
| **你的电脑** | 对方 **不需要**、也 **连不上** 你的曲库（除非你主动做端口转发/共享，默认不会） |
| **手机 App** | 只连「同一 Wi‑Fi 下、正在跑服务的那台电脑」 |

```
用户 A 的电脑 ──跑 server──► 扫 A 的 D:\Music ──► A 的手机装 App 扫 A 的二维码
用户 B 的电脑 ──跑 server──► 扫 B 的 E:\Songs ──► B 的手机装 App 扫 B 的二维码
```

**UI 从哪来？**

| UI | 来源 |
|----|------|
| 网页播放器界面 | 对方启动 server 后，浏览器打开 `http://127.0.0.1:8787` 自动有 |
| 手机 App 界面 | 安装你发布在 **GitHub Releases** 的 APK |
| Windows 桌面端 | 可选：对方自己 `flutter run -d windows`，或你以后再发桌面安装包 |

---

## 对方怎么用（你写在仓库 README 里即可）

### 1. 电脑（建自己的曲库服务）

1. 安装 [Python 3.10+](https://www.python.org/downloads/)  
2. 下载本仓库（Code → Download ZIP，或 `git clone`）  
3. 双击 `server\Start-Music-Hub.bat`（或根目录 `Start-All.bat`）  
4. 浏览器打开 http://127.0.0.1:8787  
5. **设置** → 填 **自己电脑上的** 音乐文件夹 → **扫描曲库**  
6. 点 **扫码连手机**（显示的是对方自己的局域网 IP）

### 2. 手机（下载你发的 APK）

1. 打开你仓库的 **Releases** 页（例如 `https://github.com/你的用户名/meowsic/releases`）  
2. 下载最新 `meowsic-xxx.apk` 并安装  
3. 与电脑同一 Wi‑Fi → App 里 **扫码** 或填 `http://对方电脑IP:8787`  
4. **不要**填 127.0.0.1  

没有 APK 时：对方也可用 **手机浏览器** 打开电脑给出的局域网地址（仍是对方自己的服务）。

---

## 你（作者）要准备的两样东西

### A. 源码仓库（别人自己跑服务 + 网页 UI）

推送到 GitHub 后，对方 clone/下载即可。  
**不要**提交你的 `config.yaml`、`music.db`、真实曲库路径。

### B. 可下载的 APK（手机 UI）

1. 本机打包：

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
cd D:\grok\bin\meowsic-github\mobile
flutter build apk --release
# 输出: build\app\outputs\flutter-apk\app-release.apk
```

2. 代码推上 GitHub 后：仓库页 → **Releases** → **Create a new release**  
3. Tag 如 `v1.0.0`，标题如 `meowsic v1.0.0`  
4. 上传 `app-release.apk`，改名为 `meowsic-v1.0.0.apk`  
5. 公开后下载链接形如：

```text
https://github.com/你的用户名/meowsic/releases/latest
```

或具体资产：

```text
https://github.com/你的用户名/meowsic/releases/download/v1.0.0/meowsic-v1.0.0.apk
```

6. 在 README 里写上：**[下载 Android APK](https://github.com/你的用户名/meowsic/releases/latest)**  

**不要把 apk 用 `git add` 提交进仓库**（体积大；用 Releases）。

---

## 和「连到你的曲库」的区别

| 错误理解 | 正确行为 |
|----------|----------|
| 装 App 就听到你的歌 | 没有。App 只连用户自己启动的 server |
| 分享一个固定 IP | 不要。每人 IP 不同，用各自网页二维码 |
| 云端账号登录听歌 | 无。纯局域网自建 |

若你希望「朋友远程听你的歌」，那是另一套（内网穿透 + 密码），**默认开源包不做这个**。
