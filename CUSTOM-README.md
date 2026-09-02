# Chatbox 自定义版本

这是基于 [chatboxai/chatbox](https://github.com/chatboxai/chatbox) 的自定义二次开发仓库。

## AI Agent 开发须知

本仓库通过 `.trae/rules/project_rules.md` 和 `.trae/skills/` 下的 skill 来管理开发流程，AI Agent 在执行任务时会自动加载这些规则。

核心文件：
- **CUSTOMIZATIONS.md**：自定义改动清单（机器可读，AI 合并时的依据）
- **CUSTOMIZATIONS/**：自定义代码隔离目录
  - `src/`：新增的自定义源码
  - `patches/`：对上游的补丁
  - `scripts/`：辅助脚本（init-repo、sync-vendor、list-custom）
- **.trae/rules/project_rules.md**：项目规则（AI 必须遵循）
- **.trae/skills/**：AI Skills（chatbox-record-change / chatbox-merge-upstream / chatbox-release）

## 分支结构

| 分支 | 用途 |
|------|------|
| `upstream/main` | 上游 main 分支镜像 |
| `vendor/vX.Y.x` | 上游版本基线（纯净镜像） |
| `custom/main` | 自定义开发主分支 |
| `feature/*` | 功能开发分支 |

## 常用命令

```bash
# 初始化（首次 clone 后）
pwsh ./CUSTOMIZATIONS/scripts/init-repo.ps1 -BaseVersion v1.22.3

# 查看自定义改动
pwsh ./CUSTOMIZATIONS/scripts/list-custom.ps1

# 同步 vendor 分支
pwsh ./CUSTOMIZATIONS/scripts/sync-vendor.ps1 -Version v1.22.4 -Push

# 开发模式
pnpm run dev

# 构建
pnpm run build
pnpm run package
```

## 工作流程

1. **开发**：在 `custom/main` 上或从其拉出 feature 分支开发
2. **记录**：完成改动后 AI 自动调用 `chatbox-record-change` skill 更新 CUSTOMIZATIONS.md
3. **合并上游**：需要更新时调用 `chatbox-merge-upstream` skill
4. **发布**：调用 `chatbox-release` skill 构建并发布到 GitHub Releases
