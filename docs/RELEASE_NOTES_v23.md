# meowsic v23

## What is this?

**meowsic** is a **personal self-hosted music hub** for your home network:

- Run a small server on **your PC**
- Scan **your own** music folders
- Play from the **web player** or the **Android app**
- Everyone uses **their own computer and their own library** — you do not stream someone else’s collection by default

中文：私人局域网音乐库。在自己电脑上建曲库，手机同 Wi‑Fi 连接；不是连作者或某个公共服务器。

## Download

- **Android APK:** [meowsic-v23.apk](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk)
- **Source code:** this repository (`server/` + `mobile/`)

## Requirements

| Item | Detail |
|------|--------|
| PC | Windows 10/11 recommended (Linux/macOS can run the server too) |
| Python | 3.10 or newer |
| Network | Phone and PC on the **same Wi‑Fi** (guest Wi‑Fi often blocks devices) |
| Firewall | Allow inbound **TCP 8787** |
| Optional | FFmpeg for a few uncommon audio formats |

## Install & use (3 minutes)

### On your PC

1. Install [Python 3.10+](https://www.python.org/downloads/)
2. Download this repo (Code → **Download ZIP**) and unzip
3. Double-click `Start-All.bat` (or `server\Start-Music-Hub.bat`)
4. Browser opens http://127.0.0.1:8787
5. **Settings** → choose **your local music folder** → **Scan library**
6. Click **QR for phone** to show your LAN address

Keep the server window open. Closing it stops the service.

### On your phone

1. Install `meowsic-v23.apk` (allow install from unknown sources)
2. Connect to the **same Wi‑Fi** as the PC
3. Open the app → **scan the QR code** on the PC web page  
   or type `http://YOUR-PC-LAN-IP:8787`
4. **Do not** enter `127.0.0.1` on the phone

No APK? Open the PC’s LAN URL in the phone browser (web player).

## What you get

| UI | How |
|----|-----|
| Web player | Automatic after starting the server |
| Android app | This release’s APK |
| Windows desktop app | Optional; build with Flutter (see `DEPLOY.md`) |

Features include playlists, search, queue, EQ / listening scenes, and party / listen-together mode (same hub).

## Privacy

- Music stays on **your** machine and LAN  
- No cloud music catalog / third-party streaming APIs required  
- Use only for **personally owned** audio files  

## Docs

- Chinese guide: [USAGE.md](https://github.com/Daidai710/meowsic/blob/main/USAGE.md)
- English overview: [README.en.md](https://github.com/Daidai710/meowsic/blob/main/README.en.md)
- Advanced setup: [DEPLOY.md](https://github.com/Daidai710/meowsic/blob/main/DEPLOY.md)

## License

MIT — see [LICENSE](https://github.com/Daidai710/meowsic/blob/main/LICENSE).
