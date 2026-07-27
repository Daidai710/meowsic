# meowsic server

电脑端私人音乐库服务 + 内置网页播放器。  
面向 **局域网自用**，不提供对外 Swagger / 公开 API 文档页。

## 运行

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8787
```

Windows 双击：`Start-Music-Hub.bat`  
仓库根一键：`..\Start-All.bat`

- 网页播放器：http://127.0.0.1:8787  
- 手机同 Wi‑Fi：http://`<电脑局域网IP>`:8787  

首次在网页 **设置** 填写音乐目录并 **扫描曲库**。

## 目录

```
app/           # 服务逻辑（扫描、流、歌单、一起听、鉴权）
web/           # 静态网页播放器
data/          # 运行时数据（gitignore；仅 example 可入库）
config.example.yaml
requirements.txt
```

## 环境变量

| 变量 | 含义 |
|------|------|
| `MUSIC_HUB_LIBRARY_PATH` | 默认曲库目录 |
| `MUSIC_HUB_HOST` / `MUSIC_HUB_PORT` | 监听（默认 0.0.0.0:8787） |
| `MUSIC_HUB_FFMPEG_PATH` | ffmpeg 路径（可选） |

可选访问密码：见 `data/access_password.example.txt`。

## 说明

客户端（App / 网页）通过局域网与本服务通信。  
仓库文档**不罗列 HTTP 接口表**；第三方请勿依赖未公开协议。  
更多：仓库根 [README.md](../README.md)、[DEPLOY.md](../DEPLOY.md)。
