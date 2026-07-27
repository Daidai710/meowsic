# 进阶部署

日常使用请先看 [USAGE.md](./USAGE.md) / [README.md](./README.md)。  
本文写给需要手动配置、从源码编译或跨网访问的用户。

## 手动启动服务

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8787
```

## 环境变量

```powershell
$env:MUSIC_HUB_LIBRARY_PATH = "D:\Music"
$env:MUSIC_HUB_PORT = "8787"
$env:MUSIC_HUB_FFMPEG_PATH = "C:\ffmpeg\bin\ffmpeg.exe"
```

也可复制 `server/config.example.yaml` 为 `server/config.yaml` 后编辑。

## 从源码编译 App（可选）

需要 Flutter + Android SDK：

```powershell
cd mobile
flutter pub get
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

## Windows 桌面客户端（可选）

```powershell
cd mobile
flutter pub get
flutter run -d windows
```

本机连接：`http://127.0.0.1:8787`。  
首次构建若提示 symlink，请打开 Windows「开发人员模式」。

## 跨网（可选）

服务默认在局域网。若人在外网：

- 使用 **Tailscale / ZeroTier** 等虚拟局域网，手机填虚拟 IP:8787  
- 不建议在未设密码时把服务直接暴露到公网  
