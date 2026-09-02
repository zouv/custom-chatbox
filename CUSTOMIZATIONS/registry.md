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

> **本文件是改动登记账本（纯数据）**。机制与规则（冲突策略、标记格式、类型/状态字典、frontmatter 字段职责）见 [`CUSTOMIZATIONS/README.md`](./README.md)。
>
> **AI Agent 注意**：
> 1. 开发前必须先读取本文件
> 2. 完成改动后必须调用 `chatbox-record-change` skill 更新本文件
> 3. 合并上游时按 `CUSTOMIZATIONS/README.md` 的冲突策略速查处理冲突
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

## 改动清单

| Change ID | 日期 | 类型 | 文件路径 | 功能描述 | 冲突策略 | 状态 |
|-----------|------|------|----------|----------|----------|------|
| CUSTOM-20260902-001 | 2026-09-02 | modified-upstream | packages/chatbox-core/src/domain/settings/settings-schema.ts | 键盘快捷键「显示/隐藏应用窗口」(quickToggle) 预设组合新增 Alt+Shift+Space 选项 | merge-manual | active |
| CUSTOM-20260902-002 | 2026-09-02 | config | electron-builder.yml、package.json、release/app/package.json | 发布 v1.23.0-custom.1：版本号升级为 1.23.0-custom.1；移除上游 open edition 残留的 win.signtoolOptions（其引用的 custom_win_sign.js 签名脚本已被上游删除，保留配置会导致打包失败），改为无签名构建 | merge-manual | active |
| CUSTOM-20260902-003 | 2026-09-02 | script | CUSTOMIZATIONS/scripts/7za-shim.cs、CUSTOMIZATIONS/scripts/7za-shim.exe | 7za shim：修复 Windows 无 symlink 权限时 electron-builder 下载 winCodeSign-2.6.0.7z 解压失败（darwin dylib symlink 退出码 2）导致打包中断的问题。shim 转调真实 7za 并补齐 dylib 文件后返回 0。使用方式：编译后把 shim 复制为 node_modules/7zip-bin/win/x64/7za.exe（原文件改名 7za-real.exe，pnpm install 后需重做） | keep-ours | active |
| CUSTOM-20260902-004 | 2026-09-02 | config | .agents/skills/（chatbox-merge-upstream、chatbox-record-change、chatbox-release）、AGENTS.md | 将 `.trae/skills/` 三个项目 skill 迁移到 `.agents/skills/`（ZCode 原生发现路径，跨工具共享）；`.trae/rules/project_rules.md` 的分支模型、冲突解决规则、合并测试要求合并进 AGENTS.md 后删除 `.trae/` 目录，不再依赖 Trae 私有约定 | keep-ours | active |
| CUSTOM-20260902-005 | 2026-09-02 | config | CUSTOMIZATIONS/README.md（新增）、CUSTOMIZATIONS/registry.md（自根目录 CUSTOMIZATIONS.md 迁移）、CUSTOMIZATIONS/release-notes/v1.23.0-custom.1.md（归档）、AGENTS.md、.agents/skills/*/SKILL.md、CUSTOMIZATIONS/scripts/init-repo.ps1、CUSTOMIZATIONS/scripts/list-custom.ps1 | CUSTOMIZATIONS 机制重组：规则与账本分离。新建 CUSTOMIZATIONS/README.md 作为规则唯一完整版（冲突策略表、类型/状态字典、frontmatter 字段职责表、标记格式）；registry.md 瘦身为纯账本（frontmatter+改动清单+变更日志，历史条目未改）；根目录 AGENTS.md 精简为会话级硬约束+指针；发布说明归档到 release-notes/ 子目录；三个 skill 与两个脚本的路径引用同步更新；删除 record-change 中"frontmatter 由脚本维护"的虚假声明 | keep-ours | active |
| CUSTOM-20260903-001 | 2026-09-03 | config | .gitignore | gitignore 新增 `.zcode/plans/` 忽略规则（带 [CUSTOM] 标记包裹）：ZCode 会话本地生成的计划文档不提交。注意只忽略 plans 子目录，`.zcode/` 下其他路径（skills/commands/config.json）是 ZCode 工作区级共享配置，将来可能使用，保留跟踪 | keep-ours | active |

**类型/冲突策略/状态字典**：见 [`CUSTOMIZATIONS/README.md`](./README.md) 的"条目类型与状态字典"与"冲突策略速查"两节。

---

## 变更日志

### 2026-09-03 - CUSTOM-20260903-001
- **功能**：gitignore 忽略 ZCode 会话本地计划文档
- **改动文件**：.gitignore、CUSTOMIZATIONS/registry.md
- **详细说明**：ZCode 在计划模式下会在 `.zcode/plans/` 生成会话本地 plan 文档（如 plan-sess_*.md），属工具临时产物而非项目内容。新增 `.zcode/plans/` 忽略规则（用 [CUSTOM-BEGIN]/[CUSTOM-END] 标记包裹）。特意只忽略 plans 子目录而不忽略整个 `.zcode/`：`.zcode/skills/`、`.zcode/commands/`、`.zcode/config.json` 是 ZCode 工作区级共享配置路径，将来团队共享 skill/命令/MCP 配置时会用到，应保留 git 跟踪
- **验证方式**：`git check-ignore -v .zcode/plans/plan-sess_*.md` 命中 `.gitignore:205` 规则；`git status` 不再显示 `.zcode/` 未跟踪目录
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-02 - CUSTOM-20260902-005（CUSTOMIZATIONS 机制重组：规则与账本分离）
- **功能**：解决规则文档与仓库文件混杂、规则五处重复维护的问题，确立"一处规则、一处账本、一处代码"结构
- **改动文件**：CUSTOMIZATIONS/README.md（新增）、CUSTOMIZATIONS/registry.md（git mv 自根目录 CUSTOMIZATIONS.md）、CUSTOMIZATIONS/release-notes/v1.23.0-custom.1.md（git mv 自 CUSTOMIZATIONS/ 根）、AGENTS.md、.agents/skills/chatbox-record-change/SKILL.md、.agents/skills/chatbox-merge-upstream/SKILL.md、.agents/skills/chatbox-release/SKILL.md、CUSTOMIZATIONS/scripts/init-repo.ps1、CUSTOMIZATIONS/scripts/list-custom.ps1
- **详细说明**：
  - 根目录 CUSTOMIZATIONS.md 原身兼三职（规则文档+frontmatter 元数据+账本），且与 AGENTS.md、三个 SKILL.md 存在大量逐条重复。重组后：规则唯一完整版为 CUSTOMIZATIONS/README.md；registry.md 只保留 frontmatter、改动清单表、变更日志（历史条目一字未改）；根目录 AGENTS.md 精简为会话级硬约束+指针
  - 三个 SKILL.md 中 35 处 CUSTOMIZATIONS.md 路径引用批量更新为 CUSTOMIZATIONS/registry.md；删除 Trae 遗留的 allowed-tools frontmatter 字段（ZCode 忽略、易误导）
  - chatbox-record-change 中"frontmatter 由脚本维护"为虚假声明（实际仅 init-repo.ps1 初始化时写 4 个字段，其余由 merge/release skill 手动更新），改为指向 README.md 的 frontmatter 字段职责表
  - chatbox-release 的 release notes 落盘路径明确为 CUSTOMIZATIONS/release-notes/<version>.md，与既有实践对齐
  - init-repo.ps1：模板查找改为同目录 registry.md，目录创建加 release-notes/，移除在新结构下无意义的脚本自复制逻辑；list-custom.ps1：frontmatter 读取路径同步更新
  - 上游合并无冲突风险：CUSTOMIZATIONS/ 与 .agents/ 均为纯自定义路径，上游不存在同名文件
- **验证方式**：全仓库 grep 确认无指向根目录 CUSTOMIZATIONS.md 的残留引用（registry.md 历史日志中的旧路径为历史事实，保留）；git status 显示 rename 状态；biome check 改动文件无诊断
- **基于上游版本**：v1.23.0 (61191ae7)

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

