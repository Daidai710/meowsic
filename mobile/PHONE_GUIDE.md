# 手机怎么用 meowsic

电脑先启动服务（仓库根目录 `Start-All.bat` 或 `server\Start-Music-Hub.bat`），再选下面任一方式。

---

## 方式 A：浏览器（不用装 App）

1. 电脑服务已开，浏览器能打开 http://127.0.0.1:8787  
2. 网页点 **「扫码连手机」**，记下地址（如 `http://192.168.0.8:8787`）  
3. 手机连与电脑 **同一个 Wi‑Fi**（不要用 4G/5G 访客网）  
4. 用相机 / 浏览器扫码，或手动输入该地址  
5. 即可搜歌、播放、建歌单  

注意：

- 关掉电脑服务窗口后，手机会断  
- 打不开时：检查防火墙 **8787**、是否同一 Wi‑Fi  
- 可「添加到主屏幕」更像 App  

---

## 方式 B：安装 meowsic APK

### 打包（在电脑上，做一次）

需要已安装 **Flutter + Android SDK**，`flutter doctor` 正常。

```powershell
cd mobile
flutter pub get
flutter build apk --release
```

生成文件：

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

### 安装

拷贝 apk 到手机 → 打开安装（允许未知来源）。

### 连接

1. 电脑服务保持运行  
2. 打开 **meowsic**  
3. **扫码连接** 电脑网页二维码，或手动输入 `http://电脑局域网IP:8787`  
4. **不要**填 `127.0.0.1`  

---

## 方式 C：USB 调试安装（开发用）

手机开 USB 调试，连电脑：

```powershell
cd mobile
flutter devices
flutter run --release
```

会直接装到已连接手机。

---

## 对照

| | 浏览器 | meowsic App |
|--|--------|-------------|
| 安装 | 不用 | 装 apk |
| 扫码 | 相机扫网页 | App 内扫码 |
| 后台播放 | 一般一般 | 通常更好 |
| iPhone | Safari 开局域网地址 | 需 Mac 才能打 iOS 包 |

---

## 常见问题

**打不开网页**

- 是否同一 Wi‑Fi  
- 地址是否为电脑局域网 IP  
- Windows 防火墙是否拦截 8787  

**App 连不上**

- 服务窗口是否还在跑  
- 是否误填了 127.0.0.1  
- 是否用了 http（明文局域网，不是 https）  

**只有几首歌 / 没歌**

- 在电脑网页 **设置** 里确认曲库路径并 **扫描**  
