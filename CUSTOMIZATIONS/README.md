# CUSTOMIZATIONS —— 自定义开发机制说明

本目录是本仓库所有自定义开发内容的唯一家园。规则以本文档为唯一完整版（single source of truth），根目录 `AGENTS.md` 只保留会话级硬约束摘要。

## 目录结构

```
CUSTOMIZATIONS/
├── README.md        # 本文件：机制与规则完整版（唯一规则源）
├── registry.md      # 账本：frontmatter 元数据 + 改动清单 + 变更日志
├── release-notes/   # 各自定义版本的发布说明归档
├── src/             # 新增的自定义源码（独立模块，通过入口挂载）
├── patches/         # 对上游文件的补丁
└── scripts/         # 项目辅助脚本（init-repo / list-custom / sync-vendor 等）
```

核心约定：**一处规则（README.md）、一处账本（registry.md）、一处代码（src/）**。规则改动只改本文件；改动登记只写 registry.md；自定义代码优先放 src/。

## 必须遵守的铁律

1. **开发前先读 `registry.md`**：了解已有自定义改动，避免重复或破坏已有修改。
2. **改动后必须登记**：完成任何自定义功能/修改后，调用 `chatbox-record-change` skill 更新 `registry.md`。
3. **不删除历史条目**：即使改动被回滚，条目标记为 `deprecated` 而不是删除。
4. **禁止手动 git merge/rebase**：跨上游合并必须走 `chatbox-merge-upstream` skill；禁止 rebase 改写 custom/main 历史。

## change-id 与代码标记

每个逻辑改动分配唯一 id：`CUSTOM-YYYYMMDD-NNN`（日期+序号），不可复用（同一标记块内追加修改除外）。

修改上游文件时，改动区域必须用标记包裹：

```
// [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述>
... 自定义代码 ...
// [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
```

合并上游时：标记外的区域优先使用上游版本；`[CUSTOM-BEGIN]...[CUSTOM-END]` 块必须保留，上游重构导致位置漂移时按函数/组件名找新位置。

## 冲突策略速查

合并上游时，对冲突文件按以下策略处理（按优先级从高到低）：

| 优先级 | 条件 | 策略 |
|--------|------|------|
| 1 | 文件在 `CUSTOMIZATIONS/src/` 目录下 | `keep-ours`（保留我们的） |
| 2 | 文件在 `CUSTOMIZATIONS/patches/` 目录下 | `keep-ours` |
| 3 | registry.md 条目标记 `keep-ours` | `keep-ours` |
| 4 | registry.md 条目标记 `keep-theirs` | `keep-theirs`（使用上游的） |
| 5 | 文件是 `pnpm-lock.yaml` | 接受上游版本后 `pnpm install` 重新生成 |
| 6 | 文件包含 `[CUSTOM-BEGIN]` 标记 | `merge-manual`（按标记块保留自定义代码） |
| 7 | 其他文件 | `merge-manual`（AI 分析后合并） |

- `keep-ours`：始终保留自定义版本，上游改动放弃
- `keep-theirs`：始终使用上游版本，自定义改动放弃
- `merge-manual`：需要 AI 逐块分析合并（默认）

`registry.md` 自身冲突必须人工决策后手动合并，并检查 frontmatter 合法性。本文件（README.md）策略为 `keep-ours`。

## 条目类型与状态字典

registry.md 改动清单的类型（type）字段：

- `new-file`：新增的自定义文件（放在 CUSTOMIZATIONS/src/ 下）
- `modified-upstream`：修改了上游已有文件
- `config`：配置文件修改（package.json、electron-builder.yml 等）
- `asset`：资源文件（图标、图片等）
- `dependency`：新增/修改依赖包
- `script`：构建脚本/工具脚本

状态（status）字段：

- `active`：当前生效中
- `deprecated`：已废弃/被替代
- `merged-upstream`：已被上游原生支持，无需保留
- `needs-migration`：跨大版本升级时需要适配迁移

## registry.md frontmatter 字段职责

| 字段 | 更新时机 | 负责方 |
|---|---|---|
| `current_upstream_version` / `current_upstream_commit` | 上游合并后 | chatbox-merge-upstream |
| `vendor_branch` | 上游合并后（跨版本线时） | chatbox-merge-upstream |
| `last_merge_date` | 上游合并后 | chatbox-merge-upstream |
| `last_release_version` / `last_release_date` | 发布后 | chatbox-release |
| `custom_version` | 发布后 | chatbox-release |
| `upstream_remote` | 首次 clone 初始化 | init-repo.ps1 |

## 辅助脚本

```bash
# 初始化仓库（首次 clone 后）
pwsh ./CUSTOMIZATIONS/scripts/init-repo.ps1 -BaseVersion v1.22.3

# 查看当前自定义改动（读 registry.md 的 vendor_branch 定位基线）
pwsh ./CUSTOMIZATIONS/scripts/list-custom.ps1

# 同步 vendor 分支到指定版本
pwsh ./CUSTOMIZATIONS/scripts/sync-vendor.ps1 -Version v1.22.4 -Push
```
