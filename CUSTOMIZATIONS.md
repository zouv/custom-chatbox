---
current_upstream_version: "v1.23.0"
current_upstream_commit: "61191ae783aa629d83b7001634350ac29a7f10d0"
custom_version: "0.0.0-custom.0"
last_merge_date: "2026-09-02"
last_release_version: ""
last_release_date: ""
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

### 2026-09-02 - CUSTOM-20260902-001
- **功能**：键盘快捷键「显示/隐藏应用窗口」新增 Alt+Shift+Space 预设组合
- **改动文件**：packages/chatbox-core/src/domain/settings/settings-schema.ts
- **详细说明**：在 `shortcutToggleWindowValues` 数组中新增 `'Alt+Shift+Space'`（插入在 'Alt+Space' 之后）。该数组同时作为渲染层设置页下拉框（src/renderer/components/Shortcut.tsx）的选项来源和 zod 校验枚举（`ShortcutToggleWindowValueSchema`），主进程注册（src/main/main.ts 的 normalizeShortcut）对 Alt/Shift/Space 无需转换，Electron accelerator 原生支持该组合。改动区域已用 [CUSTOM-BEGIN]/[CUSTOM-END] 标记包裹。
- **验证方式**：`pnpm run dev` 后在 设置 → 键盘快捷键 → 显示/隐藏应用窗口 下拉框中选择 Alt+Shift+Space，按该组合键验证窗口显示/隐藏；`npx vitest run src/shared/defaults.test.ts`（12 通过）；biome check 改动文件无诊断
- **基于上游版本**：v1.23.0 (61191ae7)

### _(初始创建)_
- 基于上游 chatbox 创建自定义分支
- 初始化 CUSTOMIZATIONS 目录结构和追踪体系

