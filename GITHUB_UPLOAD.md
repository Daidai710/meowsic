# 把 meowsic 放到你的个人 GitHub（从登录开始）

下面按 **零基础** 顺序写。你在 Windows 上操作即可。

---

## 第 0 步：你需要有什么

1. 一个 **GitHub 账号**（没有就去注册）  
2. 本机已安装 **Git**（没有就装）  
3. 本目录就是要上传的代码：`D:\grok\bin\meowsic-github`（整理好的开源副本）

检查 Git 是否已装：

```powershell
git --version
```

若提示找不到命令：打开 https://git-scm.com/download/win 安装，安装时勾选 “Git from the command line”。装完 **重开** PowerShell。

---

## 第 1 步：登录 GitHub 网站

1. 浏览器打开：https://github.com  
2. 点右上角 **Sign in** 登录  
   - 没有账号：点 **Sign up** 注册（邮箱 + 密码）  
3. 登录成功后，右上角应能看到你的头像  

---

## 第 2 步：在 GitHub 上新建空仓库

1. 登录后点右上角 **+** → **New repository**  
2. 填写：  
   - **Repository name**：例如 `meowsic`（可自定）  
   - **Description**（可选）：`Personal LAN music hub`  
   - 选 **Public**（开源）或 **Private**（仅自己可见）  
3. **不要**勾选：  
   - Add a README  
   - Add .gitignore  
   - Choose a license  
   （本地已有这些文件，勾了会和首次推送冲突）  
4. 点 **Create repository**  
5. 创建成功后，页面会显示仓库地址，类似：  

```text
https://github.com/你的用户名/meowsic.git
```

**复制并保存** 这个地址（后面 `origin` 要用）。

---

## 第 3 步：配置本机 Git 身份（首次才需要）

在 PowerShell：

```powershell
git config --global user.name "你的昵称"
git config --global user.email "你的邮箱@example.com"
```

邮箱建议与 GitHub 账号邮箱一致。

---

## 第 4 步：登录 Git（推送时用）

GitHub 已不支持用账户密码直接 `git push`。任选一种：

### 方式 A：GitHub CLI（简单，推荐）

1. 安装：https://cli.github.com/  
2. 打开 PowerShell：

```powershell
gh auth login
```

按提示选：

- GitHub.com  
- HTTPS  
- 用浏览器登录  

成功后 `gh auth status` 应显示 Logged in。

### 方式 B：Personal Access Token（HTTPS）

1. GitHub 网页 → 头像 → **Settings**  
2. 左侧最下 **Developer settings** → **Personal access tokens**  
3. **Tokens (classic)** → **Generate new token**  
4. 勾选至少 **repo**  
5. 生成后 **复制 token**（只显示一次）  
6. 以后 `git push` 时：  
   - Username = 你的 GitHub 用户名  
   - Password = **粘贴 token**（不是登录密码）

### 方式 C：SSH 密钥（可选）

适合长期开发。教程：GitHub Docs → “Connecting to GitHub with SSH”。  
远程地址会变成：`git@github.com:你的用户名/meowsic.git`

---

## 第 5 步：在本地初始化并提交

打开 PowerShell：

```powershell
cd D:\grok\bin\meowsic-github

# 若还没有 git 仓库：
git init

# 看将被提交的文件（确认没有 .apk / .venv / music.db）
git status

git add .
git status
```

**请确认没有这些东西**（`.gitignore` 应已排除）：

- `server/.venv`  
- `server/data/music.db`  
- `*.apk`  
- `mobile/build`  
- `config.yaml`、真实密码  

若误加了大文件：

```powershell
git reset HEAD 某文件
# 或改 .gitignore 后再 git add
```

提交：

```powershell
git commit -m "Initial public release: meowsic server + Flutter client"
```

若提示 “nothing to commit”：可能已经提交过，可跳过。

把分支名设为 main：

```powershell
git branch -M main
```

---

## 第 6 步：绑定远程并推送

把下面的 `你的用户名` 和仓库名换成你的：

```powershell
cd D:\grok\bin\meowsic-github

git remote remove origin 2>$null
git remote add origin https://github.com/你的用户名/meowsic.git

git push -u origin main
```

- 用 **gh auth login** 过：通常直接成功  
- 用 **Token**：弹出登录时密码处贴 token  

### 一键创建并推送（已装 gh 时）

若还没在网页建库，也可以：

```powershell
cd D:\grok\bin\meowsic-github
git init
git add .
git commit -m "Initial public release: meowsic server + Flutter client"
git branch -M main
gh repo create meowsic --public --source=. --remote=origin --push
```

按提示选 public/private。

---

## 第 7 步：在网页上确认

1. 打开 `https://github.com/你的用户名/meowsic`  
2. 应能看到 `README.md`、`server/`、`mobile/`  
3. 点 **Releases**（可选）上传自己打的 APK  

---

## 第 8 步：以后改代码再上传

```powershell
cd D:\grok\bin\meowsic-github
git add .
git status
git commit -m "说明你改了什么"
git push
```

---

## 发布 APK 到 Releases（可选）

1. 本机：`cd mobile` → `flutter build apk --release`  
2. GitHub 仓库页 → **Releases** → **Create a new release**  
3. Tag 例如 `v1.0.0`，上传 `app-release.apk`，命名如 `meowsic-v1.0.0.apk`  
4. **不要** `git add` 这个 apk  

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `git` 不是内部或外部命令 | 安装 Git 并重开终端 |
| `Authentication failed` | 用 token / `gh auth login`，不要用网页登录密码 |
| `remote origin already exists` | `git remote set-url origin https://github.com/你的用户名/meowsic.git` |
| `failed to push` 因远程有 README | 新建库时不要勾选 README；或先 `git pull origin main --rebase` 再 push |
| 文件太大推不动 | 确认没提交 apk / venv / 数据库；用 `git rm --cached` 去掉后重提交 |
| 想改仓库为私有 | 仓库 Settings → Danger Zone → Change visibility |

---

## 请勿提交清单

- `server/.venv/`、`server/data/**`（除 example）  
- `server/config.yaml`、`.env`、真实密码  
- `mobile/build/`、`**/*.apk`、`android/local.properties`  
- 个人绝对路径、内网 IP 写死在配置里  

`.gitignore` 已覆盖大部分；推送前务必 `git status` 看一眼。

---

## 和日常开发目录的关系

| 目录 | 用途 |
|------|------|
| `D:\grok\bin\music_hub_app` | 你本地日常改 App 的开发目录 |
| `D:\grok\bin\music-hub` | 你本地日常改服务的开发目录（若仍用） |
| `D:\grok\bin\meowsic-github` | **整理后的开源副本**，专门推 GitHub |

改完开发目录后，需要时再同步进 `meowsic-github`，然后 `git add` / `commit` / `push`。

---

做完第 6 步后，把你的仓库链接打开能看到文件，即上传成功。  
若某一步报错，把 **完整英文报错** 复制下来即可继续排查。
