---
name: "chatbox-merge-upstream"
description: "Merge upstream chatboxai/chatbox updates into custom repository. Invoke when user asks to sync/merge/update from upstream, upgrade to a new version, or pull upstream changes."
allowed-tools:
  - Read
  - Write
  - SearchReplace
  - Grep
  - Glob
  - LS
  - RunCommand
---

# Chatbox 上游合并 Skill

本 Skill 用于将 chatboxai/chatbox 上游仓库的更新合并到自定义仓库中。**所有跨上游/自定义分支的合并操作必须通过本 Skill 执行，禁止手动 git merge。**

## 触发条件

- 用户说"合并上游"、"更新到最新版本"、"升级到 vX.Y.Z"、"sync upstream"
- 需要将上游的 bugfix/新功能合入自定义版本
- 跨大版本升级（v1.22 → v1.23）
- 用户要求"同步原仓库"

## 参数收集

开始前确认以下信息（从用户输入或通过询问获取）：

1. **目标版本**：要合并到哪个上游版本？
   - tag（如 `v1.22.4`）→ 小版本更新
   - `main` 分支最新 → 跟踪最新
   - 指定 commit hash → 特定提交
   - 如果用户未指定，询问："要合并到哪个上游版本？可以指定 tag（如 v1.22.4）、main 最新、或 commit hash。"

2. **升级类型**：
   - 同大版本线更新（如 v1.22.3 → v1.22.4）→ 走小版本流程
   - 跨大版本升级（如 v1.22.x → v1.23.x）→ 走大版本流程
   - AI 自行判断版本号差异

3. **是否需要构建验证**：默认需要，除非用户明确跳过

## 前置检查

### 1. 确认仓库状态

```bash
# 检查当前分支，必须在 custom/main 上
git branch --show-current

# 检查工作区是否干净（不能有未提交的改动）
git status --porcelain

# 如果有未提交改动，先让用户处理（stash/commit），或者：
git stash push -m "auto-stash before upstream merge $(date -Iseconds)"
```

**如果工作区不干净且无法自动 stash，必须暂停并告知用户。**

### 2. 确认 remote 配置

```bash
git remote -v
# 必须能看到 upstream 指向 https://github.com/chatboxai/chatbox.git
# 如果没有 upstream remote：
git remote add upstream https://github.com/chatboxai/chatbox.git
```

### 3. 读取 CUSTOMIZATIONS.md

```
Read <repo-root>/CUSTOMIZATIONS.md
```

通读所有 `active` 状态的自定义改动条目，特别是 `冲突策略` 列。这是冲突解决的依据。

### 4. 获取上游最新信息

```bash
git fetch upstream --tags
git tag -l "v*" --sort=-v:refname | head -20
```

展示可用的上游版本给用户确认。

---

## 流程 A：小版本更新（同大版本线）

适用于 patch/minor 版本更新（如 v1.22.3 → v1.22.4）。

### A-1. 预检查报告

在执行合并前，输出一份预检查报告：

```
=== 上游合并预检查 ===
当前自定义基线版本：<vendor 分支当前指向的 tag/commit>
目标上游版本：<target>
预计改动文件数：<通过 git diff --stat vendor/vX.Y.x <target> 估算>
自定义改动条目数：<CUSTOMIZATIONS.md 中 active 条目数>
已知冲突风险文件：<对比 CUSTOMIZATIONS.md 中 modified-upstream 的文件与上游变更文件的交集>
```

### A-2. 更新 vendor 分支

```bash
# 切换到对应大版本的 vendor 分支
git checkout vendor/v<major>.<minor>.x

# 快速推进到目标版本（用 merge 而非 reset，保留历史）
git merge --no-edit <target-ref>
# 如果是 tag：git merge --no-edit v1.22.4
# 如果是 main 最新：git merge --no-edit upstream/main

# 推送到 origin
git push origin vendor/v<major>.<minor>.x
```

**如果 vendor 分支不存在（首次合并到此版本线）**：

```bash
# 基于目标版本创建新的 vendor 分支
git checkout -b vendor/v<major>.<minor>.x <target-ref>
git push -u origin vendor/v<major>.<minor>.x
```

### A-3. 合并到 custom/main

```bash
git checkout custom/main

# 创建临时合并分支（避免直接在 custom/main 上出错）
git checkout -b merge/upstream-<version>-$(date +%Y%m%d)

# 执行合并
git merge --no-edit vendor/v<major>.<minor>.x
```

### A-4. 处理冲突

**这是 AI Agent 最关键的步骤。严格按以下优先级处理：**

#### 阶段 1：自动解析（根据 CUSTOMIZATIONS.md 冲突策略）

对于每个冲突文件，运行冲突检测并根据策略处理：

```bash
# 列出所有冲突文件
git diff --name-only --diff-filter=U
```

对每个冲突文件：

1. **查找 CUSTOMIZATIONS.md 中的冲突策略**：
   - 如果该文件对应条目标记为 `keep-ours`：
     ```bash
     git checkout --ours <file>
     git add <file>
     ```
   - 如果标记为 `keep-theirs`：
     ```bash
     git checkout --theirs <file>
     git add <file>
     ```
   - 如果标记为 `merge-manual` 或未标记 → 进入阶段 2

2. **对于全新自定义文件被上游新增同名文件覆盖**：
   - 检查是否是 `CUSTOMIZATIONS/src/` 下的文件 → 必然是 `keep-ours`
   - 检查是否是配置文件（package.json、electron-builder.yml 等）→ 需要手动合并

#### 阶段 2：智能手动合并（AI 分析）

对于 `merge-manual` 的文件，AI 必须：

1. **读取冲突文件的完整内容**（使用 Read 工具）
2. **查找所有 `[CUSTOM-BEGIN]` 标记**：
   - 标记包裹的区域必须保留（我们的自定义代码）
   - 标记外的区域优先使用上游版本（`theirs`）
3. **逐块分析**：
   - 先取上游版本作为基础
   - 然后将 `[CUSTOM-BEGIN]...[CUSTOM-END]` 块插入到对应位置
   - 如果标记位置在上游版本中已被重构/移动，根据上下文（函数名、类名）找到新位置
4. **使用 SearchReplace 工具精确修复冲突标记**：
   - 删除 `<<<<<<<`, `=======`, `>>>>>>>` 冲突标记
   - 替换为合并后的正确代码

#### 阶段 3：无法自动处理的冲突

如果遇到以下情况，**暂停合并**并向用户报告：

- 上游完全重构了某个被大量自定义修改的模块（找不到 `[CUSTOM-BEGIN]` 标记的对应位置）
- package.json/pnpm-lock.yaml 存在复杂依赖冲突
- 配置文件（electron-builder.yml、tsconfig.json 等）存在结构性冲突
- CUSTOMIZATIONS.md 自身存在冲突（必须人工决策）

报告格式：
```
=== 需要人工决策的冲突 ===
文件：<path>
原因：<为什么 AI 无法自动解决>
建议：<提供两个选项的关键差异，让用户选择>
上游改动概要：<该文件上游改了什么>
我们的自定义概要：<CUSTOMIZATIONS.md 中记录了什么>
```

### A-5. 合并后验证

解决所有冲突后：

```bash
# 确认没有遗留冲突标记
git diff --name-only --diff-filter=U
# 必须为空

# 安装依赖（上游可能更新了依赖）
pnpm install

# 代码检查
pnpm run lint

# 构建验证
pnpm run build
```

如果 lint 或 build 失败，AI 必须修复错误（参考 CUSTOMIZATIONS.md 了解哪些是自定义代码需要适配）。修复后再继续。

### A-6. 更新 CUSTOMIZATIONS.md 并完成合并

```bash
# 检查所有 active 条目是否仍然有效
# 对于在新版本中失效的改动，将状态更新为 needs-migration 或 deprecated

# 提交合并
git add -A
git commit -m "merge(upstream): merge upstream <version> into custom/main

- Upstream version: <version>
- Merge date: <date>
- Conflicts resolved: <list of files with conflict resolution summary>
- Custom changes preserved: <list of change-ids that were preserved>"

# 合并回 custom/main
git checkout custom/main
git merge --no-ff merge/upstream-<version>-<date> -m "merge(upstream): integrate upstream <version>"
git branch -d merge/upstream-<version>-<date>
git push origin custom/main vendor/v<major>.<minor>.x
```

---

## 流程 B：大版本升级（跨 major/minor）

适用于大版本跨越（如 v1.22.x → v1.23.x）。大版本升级**不做直接 merge**，而是使用 cherry-pick 方式。

### B-1. 预检查报告

输出大版本差异报告：

```bash
# 创建新 vendor 分支
git fetch upstream --tags
git checkout -b vendor/v<new-major>.<new-minor>.x <target-version>

# 统计上游改动规模
git diff --stat vendor/v<old-major>.<old-minor>.x vendor/v<new-major>.<new-minor>.x

# 分析我们的自定义提交
git log --oneline vendor/v<old-major>.<old-minor>.x..custom/main
```

报告：
```
=== 大版本升级预检查 ===
当前版本线：vendor/v<old>.x（基于 v<old-base>）
目标版本线：vendor/v<new>.x（基于 <target>）
上游改动文件数：<count>
上游改动规模：<additions> / <deletions> 行
待迁移自定义提交数：<count>
自定义改动中影响上游变更文件的：<count> 个（需重点关注）
```

**向用户确认**：大版本升级改动较大，是否继续？建议列出来可能需要重新适配的自定义改动。

### B-2. 创建新的 custom 分支

```bash
git checkout -b custom/main-v<new> vendor/v<new-major>.<new-minor>.x
```

### B-3. Cherry-pick 自定义提交

按照 CUSTOMIZATIONS.md 中记录的顺序，**逐个 cherry-pick 自定义提交**：

```bash
# 获取所有自定义提交的列表（从旧 vendor 分叉点到旧 custom/main）
git log --oneline --reverse vendor/v<old>.x..custom/main
```

对每个提交：

```bash
git cherry-pick <commit-hash>
```

如果 cherry-pick 产生冲突：
1. 优先参考 `[CUSTOM-BEGIN]` 标记定位自定义代码位置
2. 上游可能重构了文件结构，根据函数/组件名找到新位置
3. 如果该自定义功能在新版本中已被原生支持，跳过该 cherry-pick 并将 CUSTOMIZATIONS.md 中对应条目标记为 `merged-upstream`
4. 如果无法解决，记录该提交并暂停，向用户报告

### B-4. 适配修复

Cherry-pick 完成后：

```bash
pnpm install
pnpm run lint
pnpm run build
```

修复所有编译错误和 lint 错误。对于上游 API 变更导致的自定义代码失效，逐个适配并更新 CUSTOMIZATIONS.md 中对应条目的"基于上游版本"字段。

### B-5. 切换主分支

```bash
# 备份旧 custom/main
git branch -m custom/main custom/main-v<old>-archive

# 将新分支设为 custom/main
git branch -m custom/main-v<new> custom/main

# 更新 CUSTOMIZATIONS.md 头部的当前版本信息
# 添加一条升级记录到变更日志

git push origin custom/main vendor/v<new-major>.<new-minor>.x --force-with-lease
git push origin custom/main-v<old>-archive
```

---

## 合并后收尾

无论流程 A 还是 B，完成后必须：

1. **更新 CUSTOMIZATIONS.md 头部元数据**：
   - `current_upstream_version` 字段更新为新版本
   - `last_merge_date` 更新为当前日期
   - 添加一条合并记录

2. **输出合并报告**：
   ```
   === 上游合并完成 ===
   合并目标：<target version>
   合并分支：vendor/v<major>.<minor>.x → custom/main
   冲突文件数：<N>
   自动解决：<N> 个（根据冲突策略）
   手动解决：<N> 个（AI 分析处理）
   需要人工决策：<N> 个（如有）
   构建验证：通过/失败
   自定义改动保留：<N> 个 active 条目
   推送状态：已推送到 origin
   ```

3. **运行一次完整测试**（如果有测试用例）：
   ```bash
   pnpm run test
   ```

## 紧急回滚

如果合并后发现严重问题：

```bash
# 回到合并前的状态
git reflog show custom/main  # 找到合并前的 commit
git reset --hard <commit-before-merge>
git push origin custom/main --force-with-lease
```

## 重要约束

1. **永远不要在 custom/main 上直接 merge**：必须通过临时 `merge/upstream-*` 分支进行。
2. **永远不要用 rebase 处理上游合并**：rebase 会改写自定义提交历史，破坏 CUSTOMIZATIONS.md 的追踪。
3. **vendor 分支上不做任何自定义修改**：vendor 分支是上游的纯净镜像，只接受来自 upstream 的 merge。
4. **pnpm-lock.yaml 冲突处理**：发生冲突时，先接受上游版本，然后删除 node_modules 重新 `pnpm install` 生成新的 lock 文件，不要手动编辑 lock 文件。
5. **不要删除 CUSTOMIZATIONS.md 中的任何历史条目**：跨版本升级时需要参考所有历史改动。
