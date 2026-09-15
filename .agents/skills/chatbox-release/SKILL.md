---
name: "chatbox-release"
description: "Build and package the custom chatbox installer (version bump, lint/build, electron-builder). Invoke when user asks to build, package, or make an installer of the custom chatbox. 发布到 GitHub 请用 chatbox-publish skill."
---

# Chatbox 自定义版本打包 Skill

本 Skill 用于把自定义 chatbox 源码**构建打包成安装包**，终点是 `release/build/Chatbox-<版本>-Setup.exe`。

**发布到 GitHub（提交 / tag / Release / 上传产物）已拆到 `chatbox-publish` skill** —— 打完包后走那边。

## 触发条件

- 用户说"打包"、"打个包"、"生成安装包"、"build"、"package"、"打 release 包"
- 需要生成安装包分发给用户

> 用户说"发布到 GitHub / 上传 release"时，本 skill 只负责打出包，发布走 `chatbox-publish`。

## 参数收集

1. **版本号**：格式 `<上游版本>-custom.N`（N 为序号），例如 `v1.23.0-custom.3`。
   - 用户未指定时，从已有 tag 读最大序号 +1：`git tag -l "v*-custom.*" --sort=-v:refname | head -5`
   - **必须在打包前定好**——版本号内嵌在产物文件名（`Chatbox-<版本>-Setup.exe`）和 exe 资源里

2. **构建平台**：
   - `current`（默认）：仅构建当前操作系统平台
   - `all`：构建 Windows + macOS + Linux（需要对应平台支持，macOS 构建需要在 Mac 上）

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

### 4. 产物占用检查

```bash
taskkill //F //IM Chatbox.exe    # 成品被占用会导致打包失败（manager.sh 会自动做）
```

> GitHub 认证检查已随发布流程移到 `chatbox-publish`。

---

## 执行流程

### 第一步：更新版本号

1. 读取 `package.json` 中的 `version` 字段
2. 确保版本号符合 `<upstream-version>-custom.N` 格式
3. 同时检查 `release/app/package.json`（chatbox 可能有两层 package.json）并同步更新

**直接编辑文件，不要用 `pnpm version`**（它会自动 commit + 打 lightweight tag，与 `chatbox-publish` 的 annotated tag 流程冲突）。

**必须更新的文件**：
- `package.json` → version 字段
- `release/app/package.json` → version 字段（决定 electron-builder 产物文件名）

### 第二步：运行检查与构建

```bash
# ⚠️ 不要无条件跑 pnpm install：它会重置 node_modules，冲掉 7za shim
#   （CUSTOM-20260902-003），还可能触发 workspace 软链失效（pitfalls #10）。
#   只有依赖真的变了才装，装完跑 `manager.sh install` 补 shim。

pnpm run lint     # 有 9 个既有 error（全在上游文件），只看有没有新增
pnpm run test     # Windows 上有 16~31 个浮动失败（上游环境敏感用例）

pnpm run build    # 生产构建
```

**两条硬经验**：

1. **别用管道看结果**：`pnpm run test 2>&1 | tail -60` 的退出码是 `tail` 的，**测试失败也返回 0**。一律重定向到文件再读：
   ```bash
   pnpm run test > /tmp/t.log 2>&1; echo "EXIT=$?"   # 看 EXIT 判断成败
   grep -E "^ FAIL|Test Files|Tests " /tmp/t.log     # 再提取失败清单
   ```
2. **失败先判定是否基线**（判定方法见 `chatbox-publish` skill 坑点 5）：确认与本次改动无关后，把**实测数字**报给用户，由用户决定是否继续。

### 第三步：打包构建

> 打包前确认版本号已改（`package.json` + `release/app/package.json`），否则产物名仍是旧版本。
> 更新 registry frontmatter 和写 release notes 属于发布环节，见 `chatbox-publish` skill。

**一律走 manager.sh**（已内置 7za shim 检查、结束占用产物的 `Chatbox.exe`、electron-builder 失败后 15s 退避重试×3 防杀软锁文件）：

```bash
sh CUSTOMIZATIONS/scripts/manager.sh setup       # NSIS 安装包（推荐）
sh CUSTOMIZATIONS/scripts/manager.sh unpacked    # 免安装目录包
pnpm run package:all                             # 多平台（需对应平台环境）
sh CUSTOMIZATIONS/scripts/manager.sh artifacts   # 看产物
```

产物目录：`release/build/`（由 `electron-builder.yml` 的 `directories.output` 决定，不要硬编码）。

**最小验证**：

```bash
sh CUSTOMIZATIONS/scripts/manager.sh artifacts
powershell -NoProfile -Command "(Get-Item 'release\build\Chatbox-<版本>-Setup.exe').VersionInfo.FileVersion"
# 应输出与版本号一致，例如 1.23.0-custom.3
```

打包耗时约 5~10 分钟。**开成后台任务、输出重定向到日志文件**，轮询关键行，不要用管道（见第二步的硬经验 1）。

### 第四步：交接给 chatbox-publish

打包完成后，后续的 commit / tag / push / GitHub Release 创建与产物上传**全部走 `chatbox-publish` skill**，本 skill 到此为止。

快速衔接：

```bash
# 产物自检
sh CUSTOMIZATIONS/scripts/manager.sh artifacts
powershell -NoProfile -Command "(Get-Item 'release\build\Chatbox-<版本>-Setup.exe').VersionInfo.FileVersion"

# 然后调用 chatbox-publish skill（或直接跑它的脚本）
node CUSTOMIZATIONS/scripts/publish-release.mjs v<版本> --dry-run
```

> 为什么拆分：本机没有 `gh` CLI，发布改走 Git Credential Manager token + GitHub REST API（已封装成 `CUSTOMIZATIONS/scripts/publish-release.mjs`），与打包的构建环境关注点完全不同。详见 `chatbox-publish` skill 的"坑点与经验"。

---

## 版本号规范

格式 `<上游版本>-custom.<序号>`（如 `v1.23.0-custom.3`），跨大版本升级后序号重置。完整规范（含 beta 预发布与 tag 规则）见 `chatbox-publish` skill。

---

## 重要约束

1. **不要跳过 lint/build**：打包前构建必须通过；lint/test 的既有失败按第二步的方法判定，把实测数字报给用户
2. **版本号先于打包**：`package.json` 与 `release/app/package.json` 两处都改
3. **构建产物不要提交到 git**：`.gitignore` 已含 `release/build/`、`dist/`、`out/`
4. **不要手动修改 pnpm-lock.yaml**：依赖问题用 `pnpm install` 解决
5. **不要跑无谓的 `pnpm install`**：会冲掉 7za shim（见第二步）
6. **打包由用户明确发起**：流程中止（构建失败、产物异常）时停下报告
7. **commit / tag / push 不在本 skill 范围**：全部走 `chatbox-publish`

## 构建产物目录参考

chatbox 使用 electron-builder，默认输出目录（以实际 electron-builder.yml 配置为准）：
- Windows: `release/build/` 下的 `.exe` 文件
- macOS: `release/build/` 下的 `.dmg` / `.zip` 文件
- Linux: `release/build/` 下的 `.AppImage` / `.deb` 文件

**实际路径必须通过读取 `electron-builder.yml` 或查看 `package.json` 中的 `build` 字段确认**，不要硬编码。
