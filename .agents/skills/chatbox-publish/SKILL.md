---
name: "chatbox-publish"
description: "Publish a built custom chatbox installer to GitHub Releases (version bump, release notes, tag, upload, verify). Invoke when user asks to publish/upload a release to GitHub, upload the installer, push a release, or create a GitHub Release."
---

# Chatbox 发布到 GitHub Skill

把**已经打好的安装包**发布到 GitHub Releases。本 skill 只负责"产物 → GitHub"这一段。

## 与 chatbox-release 的分工

| Skill | 职责 | 起点 → 终点 |
|---|---|---|
| `chatbox-release` | 从源码到安装包 | 干净工作区 → `release/build/Chatbox-<版本>-Setup.exe` |
| **`chatbox-publish`（本 skill）** | 从安装包到 GitHub | 安装包 + release notes → GitHub Release（含 tag） |

先按 `chatbox-release` 打出包，再回到本 skill 发布。若安装包已存在（`sh CUSTOMIZATIONS/scripts/manager.sh artifacts` 能看到），可跳过 chatbox-release。

## 快速路径

```bash
# 0) 定版本号：看已有 tag，取最大序号 +1
git tag -l "v*-custom.*" --sort=-v:refname | head -5

# 1) 改版本号两处 + 写 release notes + 改 registry frontmatter（见"执行流程"1、2 步）
#    （若包已打好，版本号应已改过，核对一下即可）

# 2) 先干跑校验（不发网络请求，检查产物/notes/路径是否齐备）
node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.N --dry-run

# 3) 提交 + 打 annotated tag + 推送
git add package.json release/app/package.json CUSTOMIZATIONS/registry.md \
        CUSTOMIZATIONS/release-notes/v1.23.0-custom.N.md
git commit -m "chore(release): bump version to v1.23.0-custom.N"
git tag -a v1.23.0-custom.N -m "Release v1.23.0-custom.N

Based on upstream chatbox v1.23.0"
git push origin custom/main
git push origin v1.23.0-custom.N

# 4) 发布（脚本幂等，失败可直接重跑）
gh release create v1.23.0-custom.N \
  release/build/Chatbox-1.23.0-custom.N-Setup.exe \
  release/build/Chatbox-1.23.0-custom.N-Setup.exe.blockmap \
  --title v1.23.0-custom.N \
  --notes-file CUSTOMIZATIONS/release-notes/v1.23.0-custom.N.md \
  --target custom/main \
  --verify-tag

# gh 不可用时的回退方案（GCM token + REST API，同样幂等）
# node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.N
```

## 前置检查

```bash
git branch --show-current      # 必须是 custom/main
git status --porcelain         # 必须干净（发布前不要有未提交改动）
gh auth status                 # 已登录账号需含 repo scope
gh repo view --json nameWithOwner   # ⚠️ 必须输出 zouv/custom-chatbox，不是 chatboxai/chatbox（见坑点 1）
node --version                 # v20.x - v22.x
pnpm --version                 # v10+
```

**产物版本自检**（防止发布与版本号不符的包）：

```bash
powershell -NoProfile -Command "(Get-Item 'release\build\Chatbox-<版本>-Setup.exe').VersionInfo.FileVersion"
# 应输出与版本号一致的 1.23.0-custom.N
```

## 执行流程

### 1. 更新版本号

`package.json` 与 `release/app/package.json` **两处都要改**（后者驱动 electron-builder 的产物文件名）。**必须在打包之前改**——版本号内嵌在产物文件名和 exe 资源里。

> 正常顺序是"改版本号 → 打包 → 发布"。若安装包已经打好（`manager.sh artifacts` 能看到），说明本步已做过，核对 `release/app/package.json` 与产物文件名一致即可，不要重复改。

### 2. 更新 registry frontmatter + 写 release notes

`CUSTOMIZATIONS/registry.md` 头部三个字段（字段职责见 `CUSTOMIZATIONS/README.md`）：

```yaml
custom_version: "1.23.0-custom.N"
last_release_version: "v1.23.0-custom.N"
last_release_date: "YYYY-MM-DD"
```

release notes 落到 `CUSTOMIZATIONS/release-notes/v1.23.0-custom.N.md`（随仓库归档，格式照抄上一版：本版新增 / 修复与改进 / 已知问题 / 下载）。

> **改动清单从哪来**：`git log --oneline <上一个发布提交>..HEAD` + registry 变更日志。注意上一个 tag 可能指向被 amend 掉的提交（见坑点 6），取 diff 基准时用**发布提交在分支上的实际提交**更稳。

### 3. 提交 + tag + 推送

见"快速路径"第 3 步。tag 必须是 annotated（`-a`）。

### 4. 发布并上传

**首选 gh**（见快速路径第 4 步）：

```bash
gh release create v1.23.0-custom.N \
  release/build/Chatbox-1.23.0-custom.N-Setup.exe \
  release/build/Chatbox-1.23.0-custom.N-Setup.exe.blockmap \
  --title v1.23.0-custom.N \
  --notes-file CUSTOMIZATIONS/release-notes/v1.23.0-custom.N.md \
  --target custom/main \
  --verify-tag
```

- `--verify-tag`：tag 没推到远端就中止，防呆（对应坑点 6）
- 补传漏掉的产物：`gh release upload v1.23.0-custom.N <file>`
- 发布前后核对：`gh release view v1.23.0-custom.N`、`gh release list`

**回退方案**：gh 不可用时用 `node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.N`——从 GCM 取 token → 查 release（有则复用/无则创建，正文用 release notes 文件）→ 逐个上传产物（同名旧资产先删，保证可重跑）→ 校验远端字节数与本地一致。默认上传 `release/build/Chatbox-<版本>-Setup.exe` 与其 `.blockmap`；可用 `--asset` / `--notes` / `--repo` 覆盖，`--dry-run` 先干跑校验。

### 5. 验证

```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/zouv/custom-chatbox/releases/tags/v1.23.0-custom.N" \
| node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const r=JSON.parse(d);
  console.log(r.tag_name,'draft:',r.draft,'prerelease:',r.prerelease);
  r.assets.forEach(a=>console.log(' -',a.name,a.size,'bytes',a.state))})"
```

确认：非 draft / 非 prerelease、资产 `state: uploaded`、字节数与本地一致。最后在浏览器打开 release 页面肉眼确认一遍。

## 坑点与经验

### 1. ⚠️ gh 默认认「上游仓库」—— 不加 `-R` 会发错地方

本机已装 gh 2.100.0（`C:\Program Files\GitHub CLI\`，机器级 PATH 已含；**已开的终端要新开才认**）。

本仓库有**两个 remote**（`origin` = 自己的 fork、`upstream` = chatboxai/chatbox）。gh 检测到 fork 关系后会**优先选用上游作为 base 仓库**：

```bash
gh repo view --json nameWithOwner   # 修复前输出 {"nameWithOwner":"chatboxai/chatbox"}
gh release view v1.23.0-custom.3    # 修复前：release not found（它跑去上游找了）
```

**后果**：`gh release create` 不加 `-R` 会**试图往 chatboxai/chatbox 发 release**——你的 token 没有上游写权限会失败，但这是必须防住的危险默认行为。

**修法**（写入 `.git/config` 的 `remote.origin.gh-resolved=base`，仅本地生效、不随仓库提交；**新克隆的仓库需要重跑一次**）：

```bash
gh repo set-default zouv/custom-chatbox
gh repo view --json nameWithOwner   # 修复后输出 {"nameWithOwner":"zouv/custom-chatbox"}
```

发布前若发现 `gh repo view` 输出的不是 `zouv/custom-chatbox`，**先修这个再发布**；应急可在命令后加 `-R zouv/custom-chatbox`。

**登录注意**：`gh auth login` 会问 "Authenticate Git with your GitHub credentials?"，**建议答 No**——答 Yes 会执行 `gh auth setup-git`，把 git 的 credential helper 从 GCM 改成 gh，动到现有 push 链路。当前状态：`git config --get credential.helper` = `manager`（GCM），gh 用自己的 keyring，两者互不干扰。

### 2. gh 不可用时的回退：GCM token + REST API

gh 没装或没登录时**不要卡在"先装 gh"上**：Git Credential Manager 里已存有可用 token（`gho_` 前缀，与 git push 是同一把），`publish-release.mjs` 已封装取用逻辑：

```bash
printf 'protocol=https\nhost=github.com\n\n' | git credential fill   # username=zouv, password=gho_xxx
node CUSTOMIZATIONS/scripts/publish-release.mjs v1.23.0-custom.N
```

token 只在运行时读取、不落盘、不回显。

### 3. ⚠️ 管道会吃掉退出码 —— 别用 `| tail` 看长命令结果

```bash
pnpm run test 2>&1 | tail -60     # ❌ 退出码是 tail 的，测试失败也返回 0
pnpm run test > /tmp/t.log 2>&1   # ✅ 重定向到文件，再 grep/Read 日志
```

**本次发布真实踩过**：第一次跑测试因管道返回 0，误报"测试通过"，险些漏掉 31 个失败用例。凡是"看命令退出码判断成败"的场合，一律重定向到文件（或加 `set -o pipefail`）。

### 4. 长任务用「后台 + 日志文件 + 轮询」

打包（`manager.sh setup`）和全量测试各要 4~10 分钟。开成后台任务、输出写日志文件，然后用 `grep -E "^ FAIL|Test Files|Tests "` 之类轮询关键行；**不要**用管道导致拿不到中途输出（见坑点 3）。Git Bash 下 `/tmp` 映射到 Windows 临时目录，用 `cygpath -w /tmp/xxx.log` 拿真实路径（Read 工具读不了 `/tmp/...`）。

### 5. 测试/lint 有既有的浮动基线，不要因此卡发布

- `pnpm run test` 在 Windows 上会有 **16~31 个用例失败，数量随运行浮动**（同一份代码两次跑分别是 31 和 16）：集中在 `src/main/skills/*`（路径分隔符/symlink）、`sandbox/*`、`session-attachment-rag/*`、`settings-runtime` 等环境敏感用例
- `pnpm run lint` 有 **9 个既有 error**，全在上游文件（`AgentModePanel.tsx`、`TopPSlider.tsx`、`RemoteDialogWindow.tsx`、`index.css`）

**判定"是不是这次改动引入的"**（三选一，够了）：
1. `grep -rn "<本次改动的符号>" --include='*.test.ts*'` —— 没有测试引用该符号 ⇒ 不可能影响那些子系统
2. 看失败是否落在上面那批已知环境敏感文件里
3. 重跑一次：数量浮动 ⇒ 环境相关，非确定性回归

确认是基线后，**在 release notes 的"已知问题"里写实测数字**（不要照抄上一版的旧数字），并按 skill 约定向用户报告、由用户决定是否继续发布。

### 6. tag 必须落在 custom/main 的历史上

发布前/后校验：

```bash
git merge-base --is-ancestor v1.23.0-custom.N HEAD && echo "OK" || echo "tag 不在分支历史上！"
```

**真实案例**：`v1.23.0-custom.2` 的 tag 指向 `bc5584f6`，而分支上是 `0bdcb3bc`（同提交信息、同父提交，差 4 个文档文件）——打 tag 后又 amend 了发布提交，tag 就留在了游离提交上。安装包内容不受影响，但用 tag 做 diff/changelog 会算错基准。**打 tag 之后不要再改写该提交**。

### 7. 发布前不要跑 `pnpm install`

依赖没变时不要跑：`pnpm install` 会重置 `node_modules`，**冲掉 7za shim**（CUSTOM-20260902-003），还可能因仓库改名触发 workspace 软链失效（pitfalls #10）。只有依赖真的变了才装，装完重跑 `manager.sh install` 补 shim。

### 8. 打包一律走 manager.sh

```bash
sh CUSTOMIZATIONS/scripts/manager.sh setup       # NSIS 安装包
sh CUSTOMIZATIONS/scripts/manager.sh artifacts   # 看产物
```

它已内置：7za shim 检查/安装、结束占用产物的 `Chatbox.exe`、electron-builder 失败后 15s 退避重试（防杀软扫描新 exe 锁文件，CUSTOM-20260903-009）。

### 9. 大文件上传

安装包约 234 MB，脚本用 `fs.createReadStream` + `duplex:'half'` 流式上传，不占内存。**必须一并传 `.blockmap`**（差分更新用）。同名资产会先删后传，所以**上传失败直接重跑整条命令即可**，不用手动清理。

## 失败处理与回滚

| 情况 | 处理 |
|---|---|
| tag 已推送、release 上传失败 | 直接重跑 `publish-release.mjs`（幂等） |
| tag 打错提交、尚未推送 | `git tag -d <版本>` 后重新打 |
| tag 已推送但打错 | `git tag -d <版本> && git push origin :refs/tags/<版本>` 后重打；**仅在 release 尚未对外有效时** |
| release 已发布但有严重问题 | **不要删已有 release**，标记 deprecated 并发新版本 |
| 产物字节数与远端不符 | 删除该资产重传（脚本已自动做同名替换） |

## 版本号规范

```
<upstream-version>-custom.<序号>        例：v1.23.0-custom.3
预发布：<upstream-version>-custom.<序号>-beta.1
```

跨大版本升级后序号重置（v1.22.x → v1.23.0 后从 `-custom.1` 起）；大版本首次发布先发 beta 供测试，验证后再发正式版。
