## 重要

每次回复开头都要先喊一声"啊唯"

## 项目概述

本项目是基于 chatboxai/chatbox 的自定义二次开发版本。AI Agent 在本仓库工作时，必须严格遵循以下规则。

## 必读文件（开始任何任务前）

1. **CUSTOMIZATIONS/README.md**——自定义开发机制的完整规则（冲突策略、标记格式、frontmatter 职责）
2. **CUSTOMIZATIONS/registry.md**——自定义改动登记账本
3. **README.md**——项目说明

## 工作流（写代码 / 排查问题前）

1. **先读 `CUSTOMIZATIONS/architecture.md`**：按 §0.5 任务作用域路由表确定该读哪些文件、忽略哪些；用 §2 任务→代码位置表按**函数名**定位（不依赖行号），只读作用域内的函数。图谱过期时以代码为准并顺手订正。
2. **排查 bug 前先扫 `CUSTOMIZATIONS/docs/pitfalls.md` 标题**：历史坑点（IndexedDB 损坏、settings store 丢 action、bat 中文注释等）避免重复踩；解决新坑后回写一条。
3. 命令式读设置**必须用 `getSettingsSnapshot()`**（`src/renderer/stores/settingsStore.ts`），严禁裸 `settingsStore.getState().getSettings()`（见 pitfalls #1）。

## 技术栈

- Electron + React + TypeScript + Vite
- 包管理器：pnpm（**不要使用 npm 或 yarn**）
- Node.js：v20.x - v22.x
- 代码规范：Biome
- 测试：Vitest
- 协议：GPLv3（二次分发必须开源）

## 构建命令

```bash
pnpm install        # 安装依赖（必须用 pnpm）
pnpm run dev        # 开发模式（热重载）
pnpm run build      # 生产构建
pnpm run package    # 打包当前平台
pnpm run package:all # 打包所有平台
pnpm run lint       # Biome 代码检查
pnpm run test       # Vitest 测试
```

## Git 分支规则

| 分支 | 用途 | 谁可以写入 |
|------|------|-----------|
| `upstream/main` | 跟踪上游 chatboxai/chatbox | 只读（仅 sync 脚本可更新） |
| `vendor/<version-line>` | 上游版本基线 | 只读（仅 sync 脚本可更新） |
| `custom/main` | 自定义开发主分支 | AI Agent 开发合并 |
| `feature/<name>` | 功能开发分支 | AI Agent 临时分支 |
| `release/<tag>` | 发布分支 | release skill 管理 |

- **remote**：`origin` → 自定义 GitHub 仓库；`upstream` → https://github.com/chatboxai/chatbox.git
- **禁止操作**：
  - 禁止手动 `git merge` 合并 vendor 到 custom/main（必须通过 `chatbox-merge-upstream` skill）
  - 禁止 `git rebase` 改写 custom/main 的历史
  - 禁止直接 push 到 vendor 分支

## 自定义代码规范（硬约束）

1. **代码隔离优先**：新功能尽量放在 `CUSTOMIZATIONS/src/` 下，通过独立模块挂载
2. **修改上游文件时必须加标记**：
   ```
   // [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - 描述
   ... 自定义代码 ...
   // [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
   ```
3. **每次改动必须记录**：完成后调用 `chatbox-record-change` skill 更新 CUSTOMIZATIONS/registry.md
4. **不要删除 registry.md 中的历史条目**（标记 deprecated 即可）
5. **合并冲突**：按 CUSTOMIZATIONS/README.md 的冲突策略速查处理（keep-ours / keep-theirs / merge-manual / pnpm-lock 重新生成）
6. **合并上游完成后、发布前**必须运行 `pnpm install && pnpm run lint && pnpm run build && pnpm run test`

## AI Skills 触发条件

Skill 定义位于 `.agents/skills/`（ZCode 原生发现路径，Claude/Cursor 等工具亦可通过 `.agents` 约定读取）。

| Skill | 何时调用 |
|-------|---------|
| `chatbox-record-change` | 完成任何自定义功能/修改后 |
| `chatbox-merge-upstream` | 用户要求合并上游/升级版本/同步原仓库时 |
| `chatbox-release` | 用户要求打包/发布/打 release/生成安装包时 |

详细触发场景见各 skill 的 `.agents/skills/<name>/SKILL.md`。

## 项目结构速查

```
src/main/        # Electron 主进程
src/renderer/    # React 渲染进程（UI）
src/preload/     # Electron preload
src/shared/      # 共享工具
packages/chatbox-core/   # 领域逻辑（SessionService/NamingService 等）
packages/chatbox-react/  # React 绑定（createChatApplication/settings store）
CUSTOMIZATIONS/  # 自定义开发内容（规则、账本、代码地图、坑点库、代码、脚本）
├── README.md    # 机制与规则唯一完整版
├── architecture.md  # 代码链路图谱（AI 加速索引）
├── registry.md  # 改动登记账本
├── docs/pitfalls.md  # 历史坑点沉淀
├── release-notes/
├── src/ patches/ scripts/
.agents/skills/  # AI Agent 项目级 skills
```

## 文档更新职责（改完代码必须同步）

| 改动类型 | 更新哪里 |
|---------|---------|
| 任何自定义功能/修改 | `CUSTOMIZATIONS/registry.md`（record-change skill） |
| 新增/移动函数、改数据流或接口 | `CUSTOMIZATIONS/architecture.md`（§1 职责表 / §2 反查表 / §3 链路） |
| 解决了一个反复折腾才定位的问题 | `CUSTOMIZATIONS/docs/pitfalls.md`（现象→根因→解法→教训） |
| 机制/规则变更 | `CUSTOMIZATIONS/README.md` |

## 代码风格

- 不添加注释（除非用户明确要求）
- 遵循现有代码风格
- 使用 TypeScript 严格模式
- 提交前运行 `pnpm run lint`
