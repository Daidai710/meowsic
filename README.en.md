<p align="center">
  <img src="mobile/assets/icons/meowsic_icon_256.png" width="120" alt="meowsic logo">
</p>

<h1 align="center">meowsic</h1>

<p align="center">
  Personal self-hosted LAN music hub · <a href="README.md">中文</a><br>
  <strong>Your PC · Your library · Your phone</strong>
</p>

<p align="center">
  <a href="https://github.com/Daidai710/meowsic/releases/latest"><img src="https://img.shields.io/github/v/release/Daidai710/meowsic?label=release&color=brightgreen" alt="release"></a>
  <a href="https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk"><img src="https://img.shields.io/badge/download-Android%20APK-brightgreen" alt="apk"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license"></a>
</p>

---

Play **your own local music** on your home network.  
No cloud music catalog. **Each person runs the server on their own computer** and scans **their own** folders — you do not connect to someone else’s library.

```
[Your PC]
  server scans your music folder
       ▲
       │ same Wi‑Fi
  phone App / browser ──► only this PC (:8787)
```

## Quick start

1. Install [Python 3.10+](https://www.python.org/downloads/)  
2. Download this repo (Code → **Download ZIP**)  
3. On Windows, run `Start-All.bat` (or `server\Start-Music-Hub.bat`)  
4. Open http://127.0.0.1:8787 → **Settings** → set **your** music folder → **Scan**  
5. On your phone, install the [Android APK](https://github.com/Daidai710/meowsic/releases/download/v23/meowsic-v23.apk)  
6. Same Wi‑Fi → scan the QR code on the PC web page (or enter `http://PC-LAN-IP:8787`)  

**Do not use `127.0.0.1` on the phone** (that is the phone itself).  
Allow firewall port **8787**. Closing the server window stops the service.

Full guide (Chinese): [USAGE.md](./USAGE.md) · Advanced: [DEPLOY.md](./DEPLOY.md)

## Features

| Part | What it does |
|------|----------------|
| **PC server** | Scan local files, stream audio, playlists, covers, optional password |
| **Web player** | Listen in a browser on the same Wi‑Fi; QR for phones |
| **Flutter app** | Scan-to-connect, library, playlists, queue, EQ scenes, party mode |

## Repository layout

```
server/      Python hub + web UI
mobile/      Flutter client (Android / Windows)
USAGE.md     User guide (Chinese)
DEPLOY.md    Advanced setup
README.md    Chinese homepage
```

## Privacy & license

For **personally owned** local audio only.  
**MIT** — see [LICENSE](./LICENSE).
