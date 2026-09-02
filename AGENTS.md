## 重要

每次回复开头都要先喊一声"啊唯"

## 项目概述

本项目是基于 chatboxai/chatbox 的自定义二次开发版本。AI Agent 在本仓库工作时，必须严格遵循以下规则。

## 必读文件（开始任何任务前）

1. **CUSTOMIZATIONS.md**（仓库根目录）——自定义改动清单，必须先读
2. **README.md**——项目说明

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
| `upstream/main` | 跟踪上游 chatboxai/chatbox 的 main 分支 | 只读（仅 sync 脚本可更新） |
| `vendor/<version-line>` | 上游版本基线（如 `vendor/v1.22.x`） | 只读（仅 sync 脚本可更新） |
| `custom/main` | 自定义开发主分支 | AI Agent 开发合并 |
| `feature/<name>` | 功能开发分支 | AI Agent 临时分支 |
| `release/<tag>` | 发布分支 | release skill 管理 |

- **remote**：
  - `origin` → 你的自定义 GitHub 仓库
  - `upstream` → https://github.com/chatboxai/chatbox.git
- **禁止操作**：
  - 禁止手动 `git merge` 合并 vendor 到 custom/main（必须通过 `chatbox-merge-upstream` skill）
  - 禁止 `git rebase` 改写 custom/main 的历史
  - 禁止直接 push 到 vendor 分支

## 上游合并冲突解决规则

合并上游遇到冲突时必须遵循（按优先级从高到低，与 CUSTOMIZATIONS.md 的冲突策略速查一致）：

- 文件在 `CUSTOMIZATIONS.md` 冲突策略中标注为 `keep-ours` → 保留自定义版本
- 标注为 `keep-theirs` → 使用上游版本
- 标注为 `merge-manual` 或未标注 → 读取该文件相关自定义条目，逐项判断后手动合并，**合并后必须测试**
- `CUSTOMIZATIONS.md` 本身冲突 → 必须手动合并，合并后检查 frontmatter 合法性
- `pnpm-lock.yaml` → 接受上游版本后 `pnpm install` 重新生成

## 合并/发布前测试要求

合并上游完成后、发布前必须运行：

```bash
pnpm install        # 依赖可能有变化
pnpm run lint
pnpm run build
pnpm run test       # 如有
```

## 自定义代码规范

1. **代码隔离优先**：新功能尽量放在 `CUSTOMIZATIONS/src/` 下，通过独立模块挂载
2. **修改上游文件时必须加标记**：
   ```
   // [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - 描述
   ... 自定义代码 ...
   // [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
   ```
3. **每次改动必须记录**：完成后调用 `chatbox-record-change` skill 更新 CUSTOMIZATIONS.md
4. **不要删除 CUSTOMIZATIONS.md 中的历史条目**（标记 deprecated 即可）

## AI Skills 触发条件

Skill 定义位于 `.agents/skills/`（ZCode 原生发现路径，Claude/Cursor 等工具亦可通过 `.agents` 约定读取）。

| Skill | 何时调用 |
|-------|---------|
| `chatbox-record-change` | 完成任何自定义功能/修改后 |
| `chatbox-merge-upstream` | 用户要求合并上游/升级版本/同步原仓库时 |
| `chatbox-release` | 用户要求打包/发布/打 release/生成安装包时 |

详细触发场景见各 skill 的 `.agents/skills/<name>/SKILL.md`。

## 辅助脚本

```bash
# 初始化仓库（首次 clone 后）
pwsh ./CUSTOMIZATIONS/scripts/init-repo.ps1 -BaseVersion v1.22.3

# 查看当前自定义改动
pwsh ./CUSTOMIZATIONS/scripts/list-custom.ps1

# 同步 vendor 分支到指定版本
pwsh ./CUSTOMIZATIONS/scripts/sync-vendor.ps1 -Version v1.22.4 -Push
```

## 项目结构速查

```
src/main/        # Electron 主进程
src/renderer/    # React 渲染进程（UI）
src/preload/     # Electron preload
src/shared/      # 共享工具
CUSTOMIZATIONS/  # 自定义代码（新增文件放这里）
.agents/skills/  # AI Agent 项目级 skills
```

## 代码风格

- 不添加注释（除非用户明确要求）
- 遵循现有代码风格
- 使用 TypeScript 严格模式
- 提交前运行 `pnpm run lint`
