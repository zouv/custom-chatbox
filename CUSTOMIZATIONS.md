---
current_upstream_version: "v1.23.0"
current_upstream_commit: "61191ae783aa629d83b7001634350ac29a7f10d0"
custom_version: "0.0.0-custom.0"
last_merge_date: "2026-09-02"
last_release_version: "v1.23.0-custom.1"
last_release_date: "2026-09-02"
vendor_branch: "vendor/v1.23.x"
upstream_remote: "https://github.com/chatboxai/chatbox.git"
---

# Chatbox 自定义改动清单

> **本文件是 AI Agent 管理自定义改动的核心文件。所有对上游源码的修改必须在此登记。**
>
> **AI Agent 注意**：
> 1. 开发前必须先读取本文件
> 2. 完成改动后必须调用 `chatbox-record-change` skill 更新本文件
> 3. 合并上游时必须根据本文件的"冲突策略"列处理冲突
> 4. 不要删除任何历史条目，标记状态为 deprecated/merged-upstream 即可

---

## 仓库信息

- **上游仓库**：https://github.com/chatboxai/chatbox
- **当前基于上游版本**：{{current_upstream_version}}
- **当前基于上游 Commit**：{{current_upstream_commit}}
- **当前 Vendor 分支**：{{vendor_branch}}
- **最近一次上游合并**：{{last_merge_date}}
- **最近一次发布版本**：{{last_release_version}} ({{last_release_date}})

---

## 冲突策略速查

合并上游时，对冲突文件按以下策略处理（按优先级从高到低）：

| 优先级 | 条件 | 策略 |
|--------|------|------|
| 1 | 文件在 `CUSTOMIZATIONS/src/` 目录下 | `keep-ours`（保留我们的） |
| 2 | 文件在 `CUSTOMIZATIONS/patches/` 目录下 | `keep-ours` |
| 3 | CUSTOMIZATIONS.md 条目标记 `keep-ours` | `keep-ours` |
| 4 | CUSTOMIZATIONS.md 条目标记 `keep-theirs` | `keep-theirs`（使用上游的） |
| 5 | 文件是 `pnpm-lock.yaml` | 接受上游版本后 `pnpm install` 重新生成 |
| 6 | 文件包含 `[CUSTOM-BEGIN]` 标记 | `merge-manual`（按标记块保留自定义代码） |
| 7 | 其他文件 | `merge-manual`（AI 分析后合并） |

---

## 改动清单

| Change ID | 日期 | 类型 | 文件路径 | 功能描述 | 冲突策略 | 状态 |
|-----------|------|------|----------|----------|----------|------|
| CUSTOM-20260902-001 | 2026-09-02 | modified-upstream | packages/chatbox-core/src/domain/settings/settings-schema.ts | 键盘快捷键「显示/隐藏应用窗口」(quickToggle) 预设组合新增 Alt+Shift+Space 选项 | merge-manual | active |
| CUSTOM-20260902-002 | 2026-09-02 | config | electron-builder.yml、package.json、release/app/package.json | 发布 v1.23.0-custom.1：版本号升级为 1.23.0-custom.1；移除上游 open edition 残留的 win.signtoolOptions（其引用的 custom_win_sign.js 签名脚本已被上游删除，保留配置会导致打包失败），改为无签名构建 | merge-manual | active |
| CUSTOM-20260902-003 | 2026-09-02 | script | CUSTOMIZATIONS/scripts/7za-shim.cs、CUSTOMIZATIONS/scripts/7za-shim.exe | 7za shim：修复 Windows 无 symlink 权限时 electron-builder 下载 winCodeSign-2.6.0.7z 解压失败（darwin dylib symlink 退出码 2）导致打包中断的问题。shim 转调真实 7za 并补齐 dylib 文件后返回 0。使用方式：编译后把 shim 复制为 node_modules/7zip-bin/win/x64/7za.exe（原文件改名 7za-real.exe，pnpm install 后需重做） | keep-ours | active |
| CUSTOM-20260902-004 | 2026-09-02 | config | .agents/skills/（chatbox-merge-upstream、chatbox-record-change、chatbox-release）、AGENTS.md | 将 `.trae/skills/` 三个项目 skill 迁移到 `.agents/skills/`（ZCode 原生发现路径，跨工具共享）；`.trae/rules/project_rules.md` 的分支模型、冲突解决规则、合并测试要求合并进 AGENTS.md 后删除 `.trae/` 目录，不再依赖 Trae 私有约定 | keep-ours | active |

**类型说明**：
- `new-file`：新增的自定义文件（放在 CUSTOMIZATIONS/src/ 下）
- `modified-upstream`：修改了上游已有文件
- `config`：配置文件修改（package.json、electron-builder.yml 等）
- `asset`：资源文件（图标、图片等）
- `dependency`：新增/修改依赖包
- `script`：构建脚本/工具脚本

**冲突策略说明**：
- `keep-ours`：始终保留自定义版本，上游改动放弃
- `keep-theirs`：始终使用上游版本，自定义改动放弃
- `merge-manual`：需要 AI 逐块分析合并（默认）

**状态说明**：
- `active`：当前生效中
- `deprecated`：已废弃/被替代
- `merged-upstream`：已被上游原生支持，无需保留
- `needs-migration`：跨大版本升级时需要适配迁移

---

## 变更日志

### 2026-09-02 - CUSTOM-20260902-004（skill 迁移与规则整合）
- **功能**：脱离 Trae 私有目录约定，skill 迁入标准发现路径
- **改动文件**：.agents/skills/chatbox-merge-upstream/SKILL.md、.agents/skills/chatbox-record-change/SKILL.md、.agents/skills/chatbox-release/SKILL.md（自 .trae/skills/ git mv 迁移，内容未改）、AGENTS.md、CUSTOMIZATIONS.md；删除 .trae/rules/project_rules.md 与 .trae/ 目录
- **详细说明**：
  - `.trae/skills/` 是 Trae 工具的私有路径，ZCode/Claude/Cursor 等其他 Agent 工具无法原生发现。`.agents/skills/` 是跨工具共享的工作区级 skill 标准路径（ZCode 发现顺序中的工作区第 5 级，Claude/Codex 等亦兼容该约定）
  - 三个 skill 的 SKILL.md 内容未改动，frontmatter 的 `allowed-tools`（Trae 专用字段）被 ZCode 忽略，无害
  - project_rules.md 中 AGENTS.md 未覆盖的独有规则已合并进 AGENTS.md：完整分支模型表（upstream/main、vendor、custom/main、feature、release）、上游合并冲突解决规则（keep-ours/keep-theirs/merge-manual/pnpm-lock 处理）、合并与发布前的测试要求
  - AGENTS.md 的必读文件清单移除 .trae 引用；项目结构速查和 Skills 触发条件表补充 .agents/skills/ 说明
  - 注意：上游合并时 `.trae/` 与 `.agents/` 均非上游文件，无冲突风险；本条目 keep-ours 防止误删
- **验证方式**：`find . -name SKILL.md` 确认三个 skill 位于 .agents/skills/ 下；全仓库 grep 无 `.trae` 残留引用；`git status` 显示 rename 状态
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-02 - CUSTOM-20260902-002 / CUSTOM-20260902-003（发布 v1.23.0-custom.1）
- **功能**：发布 v1.23.0-custom.1 安装包
- **改动文件**：electron-builder.yml、package.json、release/app/package.json、CUSTOMIZATIONS/scripts/7za-shim.cs、CUSTOMIZATIONS/scripts/7za-shim.exe、CUSTOMIZATIONS/release-notes-v1.23.0-custom.1.md
- **详细说明**：
  - 版本号：package.json 与 release/app/package.json 的 version 更新为 `1.23.0-custom.1`（electron-builder 产物名使用 release/app 的 version）
  - 移除 electron-builder.yml 中残留的 `win.signtoolOptions`：上游 v1.23.0 open edition 已删除 custom_win_sign.js（Azure Key Vault 签名脚本）但配置残留，导致打包失败；本环境无签名证书，改为无签名构建
  - 打包环境问题修复：本机（Windows 非管理员、未开启开发者模式）解压 electron-builder 的 winCodeSign-2.6.0.7z 缓存时 7za 因无 symlink 权限报错退出（exit 2）。用 csc.exe 编译了 CUSTOMIZATIONS/scripts/7za-shim.cs 为 7za-shim.exe，安装到 node_modules/7zip-bin/win/x64/7za.exe（真实 7za 改名 7za-real.exe 由 shim 转调），shim 在解压后把失败的 darwin dylib symlink 用目标文件副本补齐并返回 0。注意：`pnpm install` 会重置 node_modules，需重新安装 shim（编译命令：`csc -out:CUSTOMIZATIONS\scripts\7za-shim.exe CUSTOMIZATIONS\scripts\7za-shim.cs`，然后 `cp CUSTOMIZATIONS/scripts/7za-shim.exe node_modules/7zip-bin/win/x64/7za.exe`，`mv node_modules/7zip-bin/win/x64/7za.exe node_modules/7zip-bin/win/x64/7za-real.exe` 先行）
  - 产物：release/build/Chatbox-1.23.0-custom.1-Setup.exe（NSIS，x64+arm64 合一，约 234MB）+ .blockmap（差分更新用）；未签名，Windows SmartScreen 可能告警
  - gh CLI 不可用，GitHub Release 需手动创建
- **验证方式**：pnpm run build 通过；产物生成于 release/build/ 并通过 electron-builder 全流程（NSIS 打包、blockmap 生成）
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-02 - CUSTOM-20260902-001
- **功能**：键盘快捷键「显示/隐藏应用窗口」新增 Alt+Shift+Space 预设组合
- **改动文件**：packages/chatbox-core/src/domain/settings/settings-schema.ts
- **详细说明**：在 `shortcutToggleWindowValues` 数组中新增 `'Alt+Shift+Space'`（插入在 'Alt+Space' 之后）。该数组同时作为渲染层设置页下拉框（src/renderer/components/Shortcut.tsx）的选项来源和 zod 校验枚举（`ShortcutToggleWindowValueSchema`），主进程注册（src/main/main.ts 的 normalizeShortcut）对 Alt/Shift/Space 无需转换，Electron accelerator 原生支持该组合。改动区域已用 [CUSTOM-BEGIN]/[CUSTOM-END] 标记包裹。
- **验证方式**：`pnpm run dev` 后在 设置 → 键盘快捷键 → 显示/隐藏应用窗口 下拉框中选择 Alt+Shift+Space，按该组合键验证窗口显示/隐藏；`npx vitest run src/shared/defaults.test.ts`（12 通过）；biome check 改动文件无诊断
- **基于上游版本**：v1.23.0 (61191ae7)

### _(初始创建)_
- 基于上游 chatbox 创建自定义分支
- 初始化 CUSTOMIZATIONS 目录结构和追踪体系

