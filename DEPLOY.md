# meowsic 部署说明（电脑端 + 手机端）

本项目是 **局域网私人音乐库**，不对外提供公网 API 文档站。部署 = 在你自己的电脑上跑服务，手机同 Wi‑Fi 使用。

---

## 一、环境要求

| 组件 | 要求 |
|------|------|
| 电脑 | Windows 10/11（也可用 Linux/macOS 跑 server） |
| Python | 3.10 或以上，已加入 PATH |
| 网络 | 手机与电脑 **同一 Wi‑Fi**（访客网络常隔离，会连不上） |
| 可选 | FFmpeg（少数格式实时转码） |
| 可选 | Flutter 3.x + Android SDK（打包 App / 桌面端） |

防火墙：放行入站 **TCP 8787**（Windows 防火墙若拦截，首次运行可允许访问）。

---

## 二、电脑端 · 服务 + 网页

### 2.1 一键（推荐）

在仓库根目录：

```bat
Start-All.bat
```

会：

1. 启动 `server`（没有 venv 会自动创建并装依赖）  
2. 打开浏览器 http://127.0.0.1:8787  
3. 若已编译过 Flutter Windows 客户端则一并启动  

**关掉「meowsic SERVER」窗口 = 停止服务，手机也会断。**

### 2.2 只启动服务

```bat
server\Start-Music-Hub.bat
```

或手动：

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8787
```

### 2.3 首次使用网页

1. 浏览器打开 http://127.0.0.1:8787  
2. **设置** → 填写音乐文件夹路径（如 `D:\Music`）  
3. **扫描曲库**  
4. 点 **扫码连手机**，记下局域网地址（如 `http://192.168.0.8:8787`）

### 2.4 可选配置

```powershell
# 默认曲库
$env:MUSIC_HUB_LIBRARY_PATH = "D:\Music"
# 端口（默认 8787）
$env:MUSIC_HUB_PORT = "8787"
# FFmpeg
$env:MUSIC_HUB_FFMPEG_PATH = "C:\ffmpeg\bin\ffmpeg.exe"
```

也可复制 `server/config.example.yaml` → `server/config.yaml`（**不要提交 git**）。

---

## 三、手机端 · 浏览器（无需装包）

1. 电脑服务已启动  
2. 手机连同一 Wi‑Fi  
3. 扫电脑网页上的二维码，或手动打开 `http://电脑局域网IP:8787`  
4. 可「添加到主屏幕」当简易 App 用  

详见 [mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md)。

---

## 四、手机端 · 安装 meowsic APK

### 4.1 本机打包（开发机）

```powershell
# 一次：配置 Flutter + Android SDK，flutter doctor 全绿
cd mobile
flutter pub get
flutter build apk --release
```

输出：

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

也可：`mobile\Build-Apk.ps1`（若已配置）。

### 4.2 安装到手机

| 方式 | 做法 |
|------|------|
| USB | 拷贝 apk 到手机，文件管理器安装 |
| 网盘/微信 | 发给自己下载安装 |
| USB 调试 | `flutter install` / `adb install -r app-release.apk` |

允许「未知来源」安装。

### 4.3 App 内连接

1. 电脑服务保持运行  
2. 打开 **meowsic** → **扫码连接** 或填 `http://电脑IP:8787`  
3. **禁止**填 `127.0.0.1`  

### 4.4 发布 APK（给自己 / 开源仓库）

- 用 **GitHub Releases** 上传 apk，**不要**把 apk 提交进 git  
- 命名示例：`meowsic-v1.0.23.apk`

---

## 五、电脑端 · Flutter 桌面 App

```powershell
cd mobile
# Windows 首次：打开「开发人员模式」或双击 Enable-DevMode-Then-Run.bat
flutter pub get
flutter run -d windows
# 或发布构建：
flutter build windows --release
# 产物：build/windows/x64/runner/Release/
```

本机调试连接：`http://127.0.0.1:8787`。

---

## 六、日常使用检查清单

- [ ] 电脑 `Start-Music-Hub.bat` 或 `Start-All.bat` 窗口还在  
- [ ] 网页能打开 127.0.0.1:8787  
- [ ] 已扫描曲库，列表有歌  
- [ ] 手机与电脑同一 Wi‑Fi  
- [ ] 防火墙放行 8787  
- [ ] App/手机用的是 **局域网 IP**，不是 127.0.0.1  

---

## 七、跨网（可选）

家里电脑关机就听不了。若人在外网：

- 用 **Tailscale / ZeroTier** 等组虚拟局域网，手机填虚拟网 IP:8787  
- 勿把服务裸暴露到公网而不设密码  

---

## 八、不要做什么

- 不要提交 `.venv`、`config.yaml`、`data/music.db`、真实密码  
- 不要提交 `*.apk`、`build/`  
- 不要依赖已关闭的 `/docs`（本项目不对外提供 Swagger）  
