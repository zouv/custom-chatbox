# Chatbox 自定义开发项目规则

## 本工作区用途

本工作区用于管理基于 chatboxai/chatbox 仓库的自定义二次开发。当 AI Agent 在此工作区执行任务时，必须遵循本规则。

## 仓库结构约定

```
chatbox-custom/                ← chatbox 仓库本地 clone 目录（待初始化）
├── .trae/                     ← AI Agent 配置（项目级 skills、规则）
├── CUSTOMIZATIONS.md          ← 【核心】自定义改动清单（机器可读）
├── CUSTOMIZATIONS/            ← 自定义代码隔离目录
│   ├── src/                   ← 新增的自定义源码
│   ├── patches/               ← 对上游文件的补丁（标注化修改）
│   └── scripts/               ← 项目辅助脚本
├── src/                       ← 上游源码（尽量少改）
└── ...                        ← 上游其他文件
```

## Git 分支模型

| 分支 | 用途 | 谁可以写入 |
|------|------|-----------|
| `upstream/main` | 跟踪上游 chatboxai/chatbox 的 main 分支 | 只读（仅 sync 脚本可更新） |
| `vendor/<version-line>` | 上游版本基线（如 `vendor/v1.22.x`） | 只读（仅 sync 脚本可更新） |
| `custom/main` | 自定义开发主分支 | AI Agent 开发合并 |
| `feature/<name>` | 功能开发分支 | AI Agent 临时分支 |
| `release/<tag>` | 发布分支 | release skill 管理 |

**remote 配置**：
- `origin` → 你的 GitHub 自定义仓库
- `upstream` → https://github.com/chatboxai/chatbox.git

## AI Agent 开发铁律

1. **先读 CUSTOMIZATIONS.md**：任何开发任务开始前，必须先读取根目录的 `CUSTOMIZATIONS.md`，了解已有自定义改动，避免重复造轮子或破坏已有修改。

2. **自定义代码隔离优先**：
   - 优先在 `CUSTOMIZATIONS/src/` 下新增独立模块，通过入口文件挂载，不要直接修改上游源码
   - 必须修改上游文件时，在改动处用 `// [CUSTOM-BEGIN] <change-id>` 和 `// [CUSTOM-END]` 标记包裹
   - 每个自定义改动必须在 `CUSTOMIZATIONS.md` 中登记条目

3. **禁止直接操作 git merge/rebase**：所有合并操作必须通过 `chatbox-merge-upstream` skill 执行，不要手动执行 `git merge` 处理跨分支/跨上游合并。

4. **自定义改动必须记录**：每次完成一个自定义功能/修改，必须调用 `chatbox-record-change` skill 更新 `CUSTOMIZATIONS.md`。

5. **冲突解决确定性规则**（合并时遇到冲突必须遵循）：
   - 若文件在 `CUSTOMIZATIONS.md` 的冲突策略中标注为 `keep-ours` → 保留自定义版本
   - 若标注为 `keep-theirs` → 使用上游版本
   - 若标注为 `merge-manual` 或未标注 → 读取该文件相关自定义条目，逐项判断后手动合并，**合并后必须测试**
   - `CUSTOMIZATIONS.md` 本身的冲突 → 必须手动合并，合并后检查 JSON/YAML frontmatter 合法性

6. **测试验证要求**：合并完成后、发布前必须运行：
   - `pnpm install`（依赖可能有变化）
   - `pnpm run lint`
   - `pnpm run build`
   - `pnpm run test`（如有）

## CUSTOMIZATIONS.md 格式规范

该文件是 AI Agent 理解自定义改动的"地图"，必须保持结构化、机器可解析。格式详见文件内注释。

## 可用 Skills

| Skill | 触发场景 |
|-------|---------|
| `chatbox-record-change` | 完成一个自定义改动后，登记到 CUSTOMIZATIONS.md |
| `chatbox-merge-upstream` | 需要合并上游新版本/指定分支到自定义仓库时 |
| `chatbox-release` | 需要打包构建并发布 release 到 GitHub 时 |

## 构建命令速查

```bash
pnpm install                    # 安装依赖
pnpm run dev                    # 开发模式
pnpm run build                  # 生产构建
pnpm run package                # 打包当前平台
pnpm run package:all            # 打包所有平台
pnpm run lint                   # 代码检查
pnpm run test                   # 运行测试
```

## 注意事项

- chatbox 使用 GPLv3 协议，二次分发必须保持开源
- chatbox 使用 pnpm（不是 npm/yarn），所有包管理操作必须用 pnpm
- Node.js 版本要求 v20.x - v22.x
- 本仓库是 Electron + React + TypeScript + Vite 技术栈
