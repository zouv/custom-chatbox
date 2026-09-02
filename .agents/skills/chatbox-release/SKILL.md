---
name: "chatbox-release"
description: "Build and publish a release of the custom chatbox build to GitHub. Invoke when user asks to build, package, publish, release, or create a new version/tag of the custom chatbox."
---

# Chatbox 自定义版本发布 Skill

本 Skill 用于构建、打包并发布自定义 chatbox 版本到 GitHub Releases。

## 触发条件

- 用户说"发布"、"打包"、"打 release"、"build release"、"publish"
- 需要生成安装包分发给用户
- 需要打一个版本 tag

## 参数收集

1. **版本号**：自定义版本后缀，格式为 `-custom.N`（N 为数字序号）。例如上游 v1.22.3 基础上的第 2 个自定义发布，版本号为 `v1.22.3-custom.2`。
   - 如果用户未指定，从已有 tag 中读取最大序号后 +1。

2. **构建平台**：
   - `current`（默认）：仅构建当前操作系统平台
   - `all`：构建 Windows + macOS + Linux（需要对应平台支持，macOS 构建需要在 Mac 上）
   - 指定平台：`windows` / `mac` / `linux`

3. **是否预发布**：默认否。如需 beta 标记，版本后缀使用 `-custom.N-beta`。

4. **Release 说明内容**：
   - 如果用户没有提供，AI 自动根据 CUSTOMIZATIONS/registry.md 和近期 commit 生成
   - 需要包含：基于的上游版本、本次新增/修复的自定义功能、已知问题

## 前置检查

### 1. 仓库状态检查

```bash
# 必须在 custom/main 分支
git branch --show-current

# 工作区必须干净
git status --porcelain
# 如果有未提交改动，必须先提交或 stash

# 必须在仓库根目录（有 package.json 和 electron-builder.yml）
LS
```

### 2. 版本确认

```bash
# 读取当前基于的上游版本（从 CUSTOMIZATIONS/registry.md 或 package.json）
# 列出已有的 custom tag
git tag -l "v*-custom.*" --sort=-v:refname | head -10
```

### 3. 环境检查

```bash
node --version    # 需要 v20.x - v22.x
pnpm --version    # 需要 v10+
```

### 4. GitHub 认证检查

```bash
# 检查 gh CLI 是否可用并已登录
gh auth status
# 如果未登录：gh auth login
```

如果 `gh` CLI 不可用，提示用户安装（`winget install GitHub.cli`）或使用 GitHub Token 方式。

---

## 执行流程

### 第一步：更新版本号

1. 读取 `package.json` 中的 `version` 字段
2. 确保版本号符合 `<upstream-version>-custom.N` 格式
3. 同时检查 `release/app/package.json`（chatbox 可能有两层 package.json）并同步更新

```bash
# 使用 pnpm version 更新（会自动打 tag，但我们需要手动控制）
# 或者直接编辑 package.json
```

**必须更新的文件**（如果存在）：
- `package.json` → version 字段
- `release/app/package.json` → version 字段（chatbox 的 app 包版本）
- 任何包含版本字符串的配置文件

### 第二步：运行完整检查和构建

```bash
# 安装依赖（确保 lock 文件一致）
pnpm install --frozen-lockfile

# 代码检查
pnpm run lint
# 如果有 lint 错误，修复后再继续；不要跳过

# 运行测试
pnpm run test
# 测试失败时报告给用户，由用户决定是否继续

# 生产构建（不打包，验证构建能通过）
pnpm run build
```

### 第三步：更新 CUSTOMIZATIONS/registry.md 和生成 Release Notes

在 CUSTOMIZATIONS/registry.md 头部更新：
- `last_release_version` 字段
- `last_release_date` 字段
- `custom_version` 字段

自动生成 Release Notes 并落盘到 `CUSTOMIZATIONS/release-notes/<custom-version>.md`（归档，随仓库提交）：

```markdown
## <custom-version> (<date>)

基于上游 chatbox <upstream-version> 的自定义版本。

### 自定义改动

<根据 CUSTOMIZATIONS/registry.md 中所有 active 条目生成>

- **<change-id>**: <功能描述>
  - <详细说明>

### 修复与改进

<近期 commit 中非 custom 前缀的重要修复>

### 已知问题

<如有>

### 下载

- Windows: <安装包文件名>
- macOS: <安装包文件名>
- Linux: <安装包文件名>

---
**完整自定义改动清单**：见 CUSTOMIZATIONS/registry.md
**上游版本**：chatboxai/chatbox@<upstream-version>
```

### 第四步：打包构建

根据目标平台执行打包：

```bash
# 当前平台打包
pnpm run package

# 所有平台打包（需要多平台构建环境）
pnpm run package:all
```

构建产物通常在 `release/build/` 或 `dist/` 目录下（参考 electron-builder.yml 的配置）。

```bash
# 确认构建产物
LS release/build/
# 或
LS dist/
# 或
LS out/
```

**记录生成的安装包文件路径**（用于上传）。

打包完成后进行**最小验证**：
- Windows：确认生成了 `.exe` 安装包
- macOS：确认生成了 `.dmg`（或 `.zip`）
- Linux：确认生成了 `.AppImage`（或 `.deb`）

### 第五步：提交版本变更和打 Tag

```bash
# 提交版本号更新
git add package.json release/app/package.json
git commit -m "chore(release): bump version to <custom-version>"

# 打 annotated tag
git tag -a "<custom-version>" -m "Release <custom-version>

Based on upstream chatbox <upstream-version>

Custom changes:
- <change-id-1>: <desc>
- <change-id-2>: <desc>
..."

# 推送到 origin
git push origin custom/main
git push origin "<custom-version>"
```

### 第六步：创建 GitHub Release

```bash
# 创建 release 并上传所有构建产物
gh release create "<custom-version>" \
  <build-artifact-paths> \
  --title "<custom-version>" \
  --notes-file CUSTOMIZATIONS/release-notes/<custom-version>.md \
  --target custom/main
```

如果是预发布版本，添加 `--prerelease` 参数。

构建产物路径示例（Windows）：
- `release/build/Chatbox Setup <version>.exe`
- `release/build/win-unpacked/` （不上传，只上传安装包）
- `release/build/*.blockmap`（差量更新用，一并上传）

### 第七步：验证发布

1. 在浏览器中打开 release 页面确认上传成功
2. 下载安装包验证文件大小和完整性
3. 输出发布报告

```
=== Release 发布完成 ===
版本：<custom-version>
基于上游：<upstream-version>
Tag：<custom-version>（已推送）
Release URL：https://github.com/<owner>/<repo>/releases/tag/<custom-version>
构建产物：
- <filename> (<size>)
- <filename> (<size>)
```

---

## 版本号规范

```
<upstream-version>-custom.<sequence>
例如：v1.22.3-custom.1, v1.22.3-custom.2
```

大版本升级后序号重置：
- 从 v1.22.x 升级到 v1.23.0 后，第一个发布为 `v1.23.0-custom.1`

预发布版本：
- Beta 版：`v1.22.3-custom.1-beta.1`

---

## 重要约束

1. **不要跳过 lint/build 检查**：发布前必须通过所有检查
2. **不要在有未提交改动时发布**：工作区必须干净
3. **Tag 必须是 annotated tag**（`-a` 参数），不要使用 lightweight tag
4. **构建产物不要提交到 git**：确保 `.gitignore` 中包含了 `release/build/`、`dist/`、`out/` 等目录
5. **不要手动修改 pnpm-lock.yaml**：依赖问题通过 `pnpm install` 自动解决
6. **大版本首次发布**：跨大版本升级后的第一个发布，标记为 beta（`-custom.1-beta.1`）供测试，验证后再发正式版
7. **发布失败回滚**：
   - 如果 tag 已创建但 release 上传失败：删除本地和远程 tag 后重试
     ```bash
     git tag -d <version>
     git push origin :refs/tags/<version>
     ```
   - 如果 release 已发布但发现严重问题：标记为 deprecated 并发新版本，不要删除已有 release

## 构建产物目录参考

chatbox 使用 electron-builder，默认输出目录（以实际 electron-builder.yml 配置为准）：
- Windows: `release/build/` 下的 `.exe` 文件
- macOS: `release/build/` 下的 `.dmg` / `.zip` 文件
- Linux: `release/build/` 下的 `.AppImage` / `.deb` 文件

**实际路径必须通过读取 `electron-builder.yml` 或查看 `package.json` 中的 `build` 字段确认**，不要硬编码。
