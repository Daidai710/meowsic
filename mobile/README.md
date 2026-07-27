# meowsic（Flutter 客户端）

私人局域网音乐库的 Flutter App（显示名 **meowsic**）。  
连接本仓库 [`../server`](../server) 提供的服务，**仅本地/局域网**，无公网云音乐搜索。

## 要求

- Flutter 3.x  
- Android 打包需 Android SDK  
- Windows 桌面可选  

## 运行

```powershell
flutter pub get

# 先启动 ../server （或仓库根 Start-All.bat）

# 本机桌面
flutter run -d windows
# 连接填 http://127.0.0.1:8787

# 手机
flutter devices
flutter run -d <device_id>
# 连接填 http://电脑局域网IP:8787
```

Windows 首次构建若报 symlink：打开「开发人员模式」，或双击 `Enable-DevMode-Then-Run.bat`。

## 构建 APK

```powershell
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

**不要把 APK 提交进 git**，用 GitHub Releases 上传。

## 功能摘要

- 扫码 / 粘贴 / 局域网发现服务器  
- 曲库、歌单、队列、最近、浏览  
- 本机曲库（离线侧）  
- 听感场景、Android EQ、睡眠定时、主题  
- 一起听（同步 / 各自听）  
- K 歌相关（依赖电脑端能力时）  

已移除：公网在线搜歌（iTunes 等）。

## 目录

```
lib/
  api/          # 与本机 server 通信（非公开文档）
  audio/        # 播放、EQ、场景
  screens/      # 页面
  state/        # HubState / 主题
  widgets/
assets/icons/
```

总说明：[../README.md](../README.md) · 部署：[../DEPLOY.md](../DEPLOY.md)
