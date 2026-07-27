# meowsic（Flutter 客户端）

私人局域网音乐库的 Flutter App（显示名 **meowsic**）。  
连接本仓库 [`../server`](../server) 提供的服务，仅本地 / 局域网。

## 普通用户

不必自己编译。请从仓库 [Releases](https://github.com/Daidai710/meowsic/releases/latest) 下载 APK，  
并按 [PHONE_GUIDE.md](./PHONE_GUIDE.md) 连接电脑。

## 开发者：运行

需要 Flutter 3.x。先启动 `../server`（或仓库根 `Start-All.bat`）。

```powershell
flutter pub get

# 本机桌面
flutter run -d windows
# 连接填 http://127.0.0.1:8787

# 手机
flutter devices
flutter run -d <device_id>
# 连接填 http://电脑局域网IP:8787
```

Windows 首次构建若报 symlink：打开「开发人员模式」，或双击 `Enable-DevMode-Then-Run.bat`。

## 开发者：生成 APK

```powershell
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

## 功能摘要

- 扫码 / 粘贴 / 局域网发现服务器  
- 曲库、歌单、队列、最近、浏览  
- 本机曲库  
- 听感场景、Android EQ、睡眠定时、主题  
- 一起听（同步 / 各自听）  

## 目录

```
lib/
  api/          # 与本机 server 通信
  audio/        # 播放、EQ、场景
  screens/
  state/
  widgets/
assets/icons/
```

总说明：[../README.md](../README.md) · 部署：[../DEPLOY.md](../DEPLOY.md)
