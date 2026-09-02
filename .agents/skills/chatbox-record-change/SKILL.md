---
name: "chatbox-record-change"
description: "记录自定义改动到 CUSTOMIZATIONS/registry.md。Invoke when AI agent completes a custom feature, bugfix, or any modification to upstream code, to register the change for future merge tracking."
---

# Chatbox 自定义改动记录 Skill

本 Skill 用于在 AI Agent 完成一次自定义开发后，将改动结构化记录到 `CUSTOMIZATIONS/registry.md` 文件中。**每次完成自定义修改后必须调用本 Skill**。

## 触发条件

- 完成一个自定义功能开发（feature）
- 完成一个自定义 Bug 修复
- 对上游源码做了任何非新增文件的修改
- 修改了 CUSTOMIZATIONS/ 下的自定义模块
- 用户明确要求"记录这个改动"

## 执行流程

### 第一步：确认仓库位置

如果当前工作目录不是 chatbox 仓库根目录，通过用户确认或查找包含 `package.json`（含 "chatbox" 关键字）和 `CUSTOMIZATIONS/registry.md` 的目录来定位。

### 第二步：分析本次改动

运行以下命令获取本次改动的详细信息：

```bash
# 获取最近的改动文件列表（相对于当前 HEAD，如果有未提交的改动则看工作区）
git diff --name-only HEAD
git diff --name-only --cached
git diff --name-only

# 如果是已提交的功能分支合并，查看 feature 分支与 custom/main 的差异
# git diff --name-only custom/main...<feature-branch>

# 获取新增的文件
git ls-files --others --exclude-standard
```

对每个改动文件，判断：

1. **文件类型**：`new-file`（全新自定义文件）/ `modified-upstream`（修改了上游已有文件）/ `config`（配置文件修改）/ `asset`（资源文件）
2. **改动目的**：功能名/Bug修复/配置调整等
3. **改动范围**：描述具体改了什么（简要但精确）
4. **上游版本依赖**：基于哪个上游版本做的改动
5. **冲突策略**：`keep-ours` / `keep-theirs` / `merge-manual`（默认 `merge-manual`，除非明确知道策略）

### 第三步：读取现有 CUSTOMIZATIONS/registry.md

```bash
Read <repo-root>/CUSTOMIZATIONS/registry.md
```

**必须完整理解现有条目格式**后再追加，保持格式一致。

### 第四步：为上游文件修改添加标记（如果修改了上游文件）

对于 `modified-upstream` 类型的文件，**必须**在代码中用标记包裹自定义改动区域。

标记格式：

```typescript
// 单行修改或块开始：
// [CUSTOM-BEGIN] <change-id> - <简要描述>
... 自定义代码 ...
// [CUSTOM-END] <change-id>
```

其中 `<change-id>` 格式为 `CUSTOM-YYYYMMDD-NNN`（日期+序号），例如 `CUSTOM-20260902-001`。

如果是在已有标记块内追加修改，复用已有 change-id，不要创建新标记。

### 第五步：更新 CUSTOMIZATIONS/registry.md

在 `CUSTOMIZATIONS/registry.md` 的 `## 改动清单` 表格中追加新条目，每个条目包含：

```markdown
| <change-id> | <日期> | <类型> | <文件路径> | <功能描述> | <冲突策略> | <状态> |
```

在文档末尾的变更日志区追加一条：

```markdown
### <日期> - <change-id>
- **功能**：<功能名称>
- **改动文件**：<文件列表>
- **详细说明**：<改了什么、为什么改、注意事项>
- **验证方式**：<如何验证这个改动有效>
- **基于上游版本**：<tag 或 commit hash>
```

**状态字段说明**：
- `active`：当前生效中的改动
- `merged-upstream`：该改动已被上游采纳，无需保留
- `deprecated`：已废弃/被替代的改动
- `needs-migration`：跨大版本升级时需要手动迁移的改动

### 第六步：提交 CUSTOMIZATIONS/registry.md 更新

```bash
git add CUSTOMIZATIONS/registry.md
git add <被标记的修改文件>
git commit -m "docs(custom): record change <change-id> - <简要描述>"
```

**注意**：如果 CUSTOMIZATIONS/registry.md 更新和功能代码在同一个功能分支上，一起提交即可；如果是补录，单独提交。

## 重要约束

1. **不得删除已有条目**：即使改动被回滚，条目标记为 `deprecated` 而不是删除，保留历史记录供跨版本迁移参考。
2. **change-id 不可复用**：每个逻辑改动分配唯一 id，即使同一文件多次修改也要不同 id（除非是在已有标记块内补充）。
3. **路径使用相对路径**：从仓库根目录开始，如 `src/renderer/components/ChatInput.tsx`。
4. **描述使用中文**（除非用户明确要求英文）。
5. **frontmatter 字段不要随意改动**：各字段的更新时机与负责方见 `CUSTOMIZATIONS/README.md` 的"frontmatter 字段职责"表；本 skill 只负责表格与变更日志，不更新 frontmatter。

## 输出要求

执行完本 Skill 后，向用户报告：
- 新增了哪些 change-id
- 涉及哪些文件
- 冲突策略设置是什么
- CUSTOMIZATIONS/registry.md 当前总条目数
