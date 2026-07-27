# meowsic 部署说明（电脑端 + 手机端）

在你自己的电脑上运行服务，手机与电脑 **同一 Wi‑Fi** 使用。曲库是你本机文件夹，不会连到别人的电脑。

---

## 一、环境要求

| 组件 | 要求 |
|------|------|
| 电脑 | Windows 10/11（也可用 Linux/macOS 跑 server） |
| Python | 3.10 或以上，已加入 PATH |
| 网络 | 手机与电脑 **同一 Wi‑Fi**（访客网络常隔离，会连不上） |
| 可选 | FFmpeg（少数格式实时转码） |
| 可选 | Flutter 3.x（自行编译桌面端 / 从源码装 App） |

防火墙：放行入站 **TCP 8787**。

---

## 二、电脑端 · 服务 + 网页

### 2.1 一键（推荐）

在仓库根目录：

```bat
Start-All.bat
```

会：

1. 启动 `server`（没有环境会自动创建并装依赖）  
2. 打开浏览器 http://127.0.0.1:8787  
3. 若本机已编译过 Windows 客户端则一并启动  

**关掉服务窗口 = 停止服务，手机也会断。**

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
$env:MUSIC_HUB_LIBRARY_PATH = "D:\Music"
$env:MUSIC_HUB_PORT = "8787"
$env:MUSIC_HUB_FFMPEG_PATH = "C:\ffmpeg\bin\ffmpeg.exe"
```

也可复制 `server/config.example.yaml` 为 `server/config.yaml` 后编辑。

---

## 三、手机端 · 浏览器（无需装包）

1. 电脑服务已启动  
2. 手机连同一 Wi‑Fi  
3. 扫电脑网页上的二维码，或手动打开 `http://电脑局域网IP:8787`  
4. 可「添加到主屏幕」当简易 App 用  

详见 [mobile/PHONE_GUIDE.md](./mobile/PHONE_GUIDE.md)。

---

## 四、手机端 · 安装 meowsic App

### 4.1 下载安装（推荐）

1. 打开 [Releases](https://github.com/Daidai710/meowsic/releases/latest)  
2. 下载 **meowsic-*.apk**（例如 [meowsic-v23.apk](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk)）  
3. 传到手机安装（允许「未知来源」）

### 4.2 App 内连接

1. 电脑服务保持运行  
2. 打开 **meowsic** → **扫码连接** 或填 `http://电脑IP:8787`  
3. **不要**填 `127.0.0.1`  

### 4.3 从源码自行编译（可选）

若你有 Flutter + Android 环境，也可自己生成安装包：

```powershell
cd mobile
flutter pub get
flutter build apk --release
```

生成文件在：`mobile/build/app/outputs/flutter-apk/app-release.apk`，拷到手机安装即可。

---

## 五、电脑端 · Flutter 桌面 App（可选）

```powershell
cd mobile
flutter pub get
flutter run -d windows
```

本机连接：`http://127.0.0.1:8787`。  
Windows 首次构建若提示 symlink，请打开「开发人员模式」。

---

## 六、日常使用检查清单

- [ ] 电脑服务窗口还在  
- [ ] 网页能打开 127.0.0.1:8787  
- [ ] 已扫描曲库，列表有歌  
- [ ] 手机与电脑同一 Wi‑Fi  
- [ ] 防火墙放行 8787  
- [ ] 手机用的是 **局域网 IP**，不是 127.0.0.1  

---

## 七、跨网（可选）

家里电脑关机就听不了。若人在外网：

- 用 **Tailscale / ZeroTier** 等组虚拟局域网，手机填虚拟网 IP:8787  
- 不建议在无密码时把服务直接暴露到公网  
