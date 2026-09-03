---
current_upstream_version: "v1.23.0"
current_upstream_commit: "61191ae783aa629d83b7001634350ac29a7f10d0"
custom_version: "1.23.0-custom.2"
last_merge_date: "2026-09-02"
last_release_version: "v1.23.0-custom.2"
last_release_date: "2026-09-03"
vendor_branch: "vendor/v1.23.x"
upstream_remote: "https://github.com/chatboxai/chatbox.git"
---

# Chatbox 自定义改动登记

> **本文件是改动登记账本（纯数据）**。机制与规则（冲突策略、标记格式、类型/状态字典、frontmatter 字段职责）见 [`CUSTOMIZATIONS/README.md`](./README.md)。
>
> **两层结构（怎么用）**：
> - **改动总览（按文件）**——查"某个文件现在改了什么、上游合并时怎么处理"：**只读这一节**，每个文件一条，多轮演进已合并为当前状态，无需读历史轮次。
> - **变更日志（按次）**——查"某次改动何时发生、为什么、怎么验证"：按时间倒序的 append-only 流水，只增不改（历史是事实）。
>
> **AI Agent 注意**：
> 1. 开发前读**改动总览**定位相关文件与冲突策略（不必通读变更日志）
> 2. 完成改动后调用 `chatbox-record-change` skill：**总览里已有该文件就更新那一节**（合并描述、追加演进链 id），没有就新增一节；变更日志追加一轮记录
> 3. 合并上游时按总览的冲突策略列处理
> 4. 不要删除历史（总览条目整体废弃时标 deprecated，变更日志永不删改）
> 5. 一致性自检：`sh CUSTOMIZATIONS/scripts/check-registry.sh`（代码标记 ↔ 总览表双向比对）

---

## 仓库信息

- **上游仓库**：https://github.com/chatboxai/chatbox
- **当前基于上游版本**：{{current_upstream_version}}
- **当前基于上游 Commit**：{{current_upstream_commit}}
- **当前 Vendor 分支**：{{vendor_branch}}
- **最近一次上游合并**：{{last_merge_date}}
- **最近一次发布版本**：{{last_release_version}} ({{last_release_date}})

---

## 改动总览（按文件）

> **每个文件一条**：该文件当前生效的全部自定义改动（多轮演进已合并）；「标记」列为代码中 `[CUSTOM-BEGIN]` 的 change-id（即该文件自定义区的当前真相），演进链标注历轮 id。代码位置速查见 [`architecture.md`](./architecture.md) §2。
>
> **状态字典**：`active`（生效中）/ `deprecated`（已废弃）/ `merged-upstream`（上游已原生支持）。**冲突策略**字典见 README.md。

| 文件 | 标记（当前） | 演进链 | 当前效果（合并后） | 冲突策略 | 状态 |
|------|-------------|--------|-------------------|---------|------|
| packages/chatbox-core/src/domain/settings/settings-schema.ts | 002/008 | 20260902-001→002→008 | quickToggle 预设新增 Alt+Shift+Space 与 Super+Shift+Space；ShortcutSettingSchema 新增 openThreadHistory（z.string().default('mod+h')）；SettingsSchema 新增 autoNameCopilotThreads（boolean，default false） | merge-manual | active |
| packages/chatbox-core/src/domain/settings/settings-defaults.ts | 002/008 | 002→008 | createDefaultSettings 含 autoNameCopilotThreads: false 与 shortcuts.openThreadHistory: 'mod+h'（与 schema 必须同步） | merge-manual | active |
| packages/chatbox-core/src/application/session/SessionNamingService.ts | 006 | 20260903-002→004→006 | syncAutoTitle 内搭档命名门槛：开关关闭时 copilot 会话跳过 thread 命名；开启时仅"无归档话题的会话首轮"升级 name-and-thread（写 name+threadName），话题轮次保持上游 thread-only；scheduleCopilotAwareNameAndThreadName 放宽 Untitled 写保护 | merge-manual | active |
| packages/chatbox-core/src/application/session/SessionNamingService.test.ts | （测试文件，无标记） | 002→004→006 | 命名门槛/升级/新话题排除共 5 个自定义用例 | keep-ours | active |
| src/renderer/routes/settings/chat.tsx | 002 | 002 | 对话设置→功能：「使用搭档的新话题开启自动命名」开关（默认关） | merge-manual | active |
| src/renderer/components/Shortcut.tsx | 002/008 | 002→008 | formatKey 增加 super→Win（Windows）/Super（Linux）显示映射；ShortcutConfig 新增「历史话题」条目（name: openThreadHistory，只读展示，复用现有 Thread History i18n 键） | merge-manual | active |
| src/renderer/i18n/locales/*/translation.json（14 个） | （无标记，已知缺口） | 002 | 每语言新增 2 个键：Auto-Name New Topics of Copilot Chats 及其描述 | merge-manual | active |
| src/main/main.ts | 004 | 004 | registerShortcuts 记录注册结果日志、失败经 shortcut-registration-failed 推渲染层、窗口 focus 自愈重试（lastQuickToggleRegistrationFailed） | merge-manual | active |
| src/preload/index.ts | 004 | 004 | 暴露 onShortcutRegistrationFailed（createListener） | merge-manual | active |
| src/shared/electron-types.ts | 004 | 004 | ElectronIPC 接口加 onShortcutRegistrationFailed | merge-manual | active |
| src/renderer/platform/interfaces.ts | 004 | 004 | Platform 接口加 onShortcutRegistrationFailed（可选） | merge-manual | active |
| src/renderer/platform/desktop_platform.ts | 004 | 004 | DesktopPlatform 实现 onShortcutRegistrationFailed | merge-manual | active |
| src/renderer/hooks/useShortcut.tsx | 004/008 | 004→008 | 订阅 shortcut-registration-failed 弹 toast（带设置跳转）；读设置改用 getSettingsSnapshot；keyboardShortcut 新增 isShortcutPressed(openThreadHistory) → openThreadHistoryDrawer（经 sessionQueryBridge 取 session、isThreadHistoryAvailable 判定后设 showThreadHistoryDrawerAtom=true） | merge-manual | active |
| packages/chatbox-react/src/stores/createSettingsStore.ts | 005 | 005 | service.subscribe 回声改函数式合并（保留 action 方法，防 state 被整体替换丢 action） | merge-manual | active |
| src/renderer/stores/settingsStore.ts | 005 | 005 | 新增 getSettingsSnapshot()：action 可用走 getSettings()，否则直接读 state 字段（命令式读设置的唯一合法入口） | merge-manual | active |
| src/renderer/stores/sessionHelpers.ts | 005 | 005 | initEmptyChatSession 容错读设置（getSettings 不可用时读 state） | merge-manual | active |
| src/renderer/stores/session/messages.ts | 005 | 005 | submitNewUserMessageUnlocked 读设置改 getSettingsSnapshot（防生成链中断） | merge-manual | active |
| src/renderer/stores/session/generation.ts | 005 | 005 | 同上（genMessageContext 内） | merge-manual | active |
| src/renderer/stores/session/session-settings.ts | 005 | 005 | 同上（getSessionSettings 内） | merge-manual | active |
| src/renderer/stores/session/tools-builder.ts | 005 | 005 | 3 处裸调用改 getSettingsSnapshot | merge-manual | active |
| src/renderer/components/InputBox/useModelToolCapabilities.ts | 005 | 005 | 同上 | merge-manual | active |
| src/renderer/stores/imageGenerationActions.ts | 005 | 005 | 同上 | merge-manual | active |
| src/renderer/packages/context-management/summary-generator.ts | 005 | 005 | 3 处同上 | merge-manual | active |
| src/renderer/packages/model-calls/command-explanation.ts | 005 | 005 | 同上 | merge-manual | active |
| src/renderer/packages/model-setting-utils/util.ts | 005 | 005 | 同上（setState 保留原样） | merge-manual | active |
| src/renderer/pages/RemoteDialogWindow.tsx | 005 | 005 | 同上 | merge-manual | active |
| src/renderer/setup/storage_clear.ts | 005 | 005 | 同上 | merge-manual | active |
| 6 个测试文件（mock settingsStore） | （测试文件，无标记） | 005 | agent-harness / tools-builder / streaming-message / useModelToolCapabilities / command-explanation / storage_clear 的 vi.mock 补 getSettingsSnapshot 导出 | keep-ours | active |
| src/shared/defaults.test.ts | （测试文件，无标记） | 008 | shortcuts 键断言补 openThreadHistory（= 'mod+h'） | keep-ours | active |
| electron-builder.yml | 20260902-002 | 20260902-002 | 移除上游残留 win.signtoolOptions（无签名构建） | merge-manual | active |
| .gitignore | 20260903-001 | 20260903-001 | 忽略 .zcode/plans/（ZCode 会话本地计划文档） | keep-ours | active |
| CUSTOMIZATIONS/scripts/（manager.sh、build-unpacked.bat、build-setup.bat、7za-shim.*、init-repo.ps1、list-custom.ps1、check-registry.sh） | （纯自定义目录，逐文件标记非必需） | 20260902-003→003→007→009 | 本地操作与打包脚本套件：manager.sh 统一入口；两个 bat 打 unpacked/Setup 包（electron-builder 失败后 15s 退避重试×3，防杀软扫描新 exe 锁文件致 rcedit 失败）；7za shim 修 winCodeSign 解压；check-registry 一致性自检 | keep-ours | active |
| CUSTOMIZATIONS/（README.md、architecture.md、registry.md、docs/pitfalls.md） | （纯自定义目录） | 20260902-005→006→007 | 自定义机制（规则/账本）+ AI 协作文档（代码地图/坑点库） | keep-ours | active |
| AGENTS.md、.agents/skills/* | （纯自定义文件） | 20260902-004→005→006 | 会话级硬约束+工作流+skills（merge-upstream/record-change/release） | keep-ours | active |

---

## 变更日志

### 2026-09-03 - CUSTOM-20260903-009
- **功能**：修复 unpacked/Setup 打包间歇性失败（rcedit「Unable to commit changes」）
- **改动文件**：CUSTOMIZATIONS/scripts/build-unpacked.bat、CUSTOMIZATIONS/scripts/build-setup.bat、CUSTOMIZATIONS/docs/pitfalls.md（新增坑点 #9）
- **详细说明**：
  - 现象：`manager.sh unpacked` 在 rcedit 给新写出的 win-unpacked\Chatbox.exe 写版本信息时报 `Fatal error: Unable to commit changes`，electron-builder 内部 3 次快速重试全败中止；`--skip-build` 重跑仍失败（builder 每次都重新复制新 exe）
  - 根因（node 脚本模拟时序复现）：electron-builder 复制完 200MB 新 exe 立即调 rcedit；火绒实时防护扫描刚落盘的 exe 并短暂持锁（实测窗口 0.6s~5s 不等），rcedit 写入被拒。electron-builder 自带重试间隔毫秒级，全落在扫描窗口内。手动跑 rcedit 永远成功（锁已释放），不能以此排除。9/2 两次打包成功、9/3 失败符合杀软启发式判定的波动性
  - 修复：两个 bat 的 electron-builder 调用外包重试循环——失败后等 15s 重跑整个 builder（最多 3 轮），15s 远超扫描窗口，必过；代码注释标记 CUSTOM-20260903-009。根治方案（用户手动）：仓库目录加入火绒信任区
  - 排查中排除的假设：Chatbox 进程占用（脚本已 taskkill 且无进程）、磁盘空间（59G 可用）、只读属性（A）、父进程拦截（node spawn 同款命令成功）、electron-builder 特殊执行方式（builder 经 app-builder.exe 执行，node 模拟同参数亦成功——差异只在时序）
- **验证方式**：改后 `build-unpacked.bat --skip-build` 重跑 `[SUCCESS] unpacked build finished`（本轮一遍过）；rcedit `--get-version-string` 确认 FileDescription/ProductName 已写入产物；启动 win-unpacked 主窗口正常响应；临时复现脚本已清理
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-008
- **功能**：新增 Ctrl/Cmd+H 快捷键直接打开会话「历史话题」抽屉（此前只能经右上角 … 菜单进入）
- **改动文件**：packages/chatbox-core/src/domain/settings/settings-schema.ts、packages/chatbox-core/src/domain/settings/settings-defaults.ts、src/renderer/hooks/useShortcut.tsx、src/renderer/components/Shortcut.tsx、src/shared/defaults.test.ts
- **详细说明**：
  - 需求：用户希望键盘快捷打开"历史话题"侧边面板，并在 设置→键盘快捷键 可见
  - 实现：ShortcutSettingSchema 新增 `openThreadHistory`（z.string().default('mod+h')，`mod` 约定与 newChat mod+n / dialogOpenSearch mod+k 一致，Windows 上实际是 Ctrl+H、macOS 上 ⌘+H；settings-defaults.ts 同步默认值）；useShortcut 的 keyboardShortcut 中用既有 `isShortcutPressed` 匹配后调 `openThreadHistoryDrawer()`——取当前路由 session（fallback currentSessionIdAtom）、经 rendererApplication.sessionQueryBridge.getSession 拉取、`isThreadHistoryAvailable(session, resolveSessionMode(getSessionAgentModeEntry(...)))` 判定（与 Toolbar/ThreadHistoryDrawer 同一门槛：work 模式且无归档话题的会话没有抽屉可开，静默不响应）、通过则设 jotai `showThreadHistoryDrawerAtom=true` 打开抽屉
  - 设置页：Shortcut.tsx 的 ShortcutConfig items 在「New Thread」后新增「历史话题」条目（name: 'openThreadHistory'，无 options → 只读展示，与 New Chat 等条目一致）；label 复用现有 i18n 键 "Thread History"（14 语言均已存在），**无需新增翻译**（避免 002 轮的 14 语言联动成本）
  - 兼容性：应用内快捷键（window keydown），不经主进程 globalShortcut，无注册失败/占用问题；老 config.json 无该字段时 hydrate 的 deepmerge(defaults) + zod .default() 双重补默认值，迁移无需 bump SETTINGS_PERSIST_VERSION（加字段属向后兼容，短路过期策略与 autoNameCopilotThreads 002 轮同法）
  - 主进程 registerShortcuts 只管 quickToggle（窗口显隐），无需改动
- **验证方式**：`npx tsc --noEmit -p tsconfig.json` 0 错误；vitest：defaults.test 12 测（含新增 openThreadHistory 键与值断言）、mode-policy 9 测、ThreadHistoryDrawer 1 测、settings 域 11 测、createSettingsStore/RendererSettingsEffects 全过；biome 5 个改动文件无新增诊断（useShortcut 4 个 warning 与改动前基线一致，import 排序错误已修复）；手测路径：`pnpm run dev` → 会话内按 Ctrl+H 打开抽屉、… 菜单行为不变、Work 模式会话按 Ctrl+H 无响应
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-007
- **功能**：registry.md 账本结构重组——改动总览按文件聚合（多轮演进合并），解决按次记录的冗余与"前改后改实际没改"不可读问题
- **改动文件**：CUSTOMIZATIONS/registry.md、CUSTOMIZATIONS/scripts/check-registry.sh（新增）、CUSTOMIZATIONS/README.md、.agents/skills/chatbox-record-change/SKILL.md、11 个 005 改动文件（补 CUSTOM-20260903-005 标记）
- **详细说明**：
  - 动机（用户反馈）：按次记录的改动清单在多轮修同一问题时生成多条记录，累计后需完整扫描并人工消解"A改B又改回A"的冗余
  - 新结构两层：**改动总览（按文件）**——每文件一节，「标记」列=代码中 [CUSTOM-BEGIN] 的当前 change-id（演进链如 002→004→006），「当前效果」为多轮合并后的现状描述（被后续轮次取代的旧描述已删除）；**变更日志（按次）**——原 180 行 append-only 历史原样保留，负责追溯"何时/为何/怎么验证"
  - 新增 check-registry.sh 双向校验：§1 代码有 CUSTOM 标记但总览未登记 → MISSING-IN-DOC；§2 总览登记的 modified-upstream 文件缺标记 → NO-MARKER / FILE-NOT-FOUND；聚合行（目录/（文件列表））与通配行（locales/*/translation.json）按前缀匹配；纯自定义路径（CUSTOMIZATIONS/、.agents/、AGENTS.md、.gitignore）与测试文件豁免标记要求。退出码 0/1，登记后必须跑到全绿
  - 校验顺带发现并修复真实缺口：005 那 11 个改动文件（messages/generation/session-settings/tools-builder/useModelToolCapabilities/imageGenerationActions/summary-generator/command-explanation/model-setting-utils/RemoteDialogWindow/storage_clear）当时只改调用方式没打标记——已全部补上（import getSettingsSnapshot 行上下标记），全绿（28 个含标记文件一一对应）
  - 记录流程同步更新：record-change skill 重写（总览按文件合并更新 + 日志按次追加 + 第五步强制 check-registry 全绿）；README.md 新增"两层结构"说明、铁律与类型字典相应调整
  - 上游合并影响：总览表由代码标记镜像生成，合并冲突时以"代码标记实际状态"为准重建总览行
- **验证方式**：`sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿（exit 0）；`npx tsc --noEmit -p tsconfig.json` 0 错误（补标记未破坏模块）；vitest 抽查（stores + tools-builder）59 测全过
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-006
- **功能**：搭档自动命名范围修正（新话题不再触发会话改名）+ AI 协作文档体系建立
- **改动文件**：packages/chatbox-core/src/application/session/SessionNamingService.ts、SessionNamingService.test.ts、CUSTOMIZATIONS/architecture.md（新增）、CUSTOMIZATIONS/docs/pitfalls.md（新增）、CUSTOMIZATIONS/README.md、AGENTS.md
- **详细说明**：
  - 命名范围修正：CUSTOM-20260903-004 的升级条件（action==='thread' && copilotId && autoNameCopilotThreads）未区分"会话首轮"与"话题轮次"。会话内点"新话题"（ThreadService.refreshContextAndCreateNew 归档旧对话、threadName 重置 ''）后再发消息，又满足 'thread' 条件 → 会话名再次被 AI 命名覆盖。修正：升级条件加 `!(session.threads?.length)`——threads 非空（有过归档话题）时保持上游 thread-only 路径（只命名 threadName 话题标签，不动会话名），与不用搭档的会话语义完全一致；判定"首轮"用 threads 是否为空而非 threadName（threadName='' 哨兵在 New-Thread/clear/晋升等多种操作后都出现，见 pitfalls #4）。标记从 004 更新为 006（同文件演进）
  - 文档体系（参考 zgame/vibe-coding-starter 的 AI 协作文档做法，适配本仓库实际）：
    - `CUSTOMIZATIONS/architecture.md`（代码链路图谱，面向 AI）：§0 一句话架构+数据流图、§0.5 任务作用域路由表（7 类任务该读/忽略哪些文件）、§1 文件职责速查表、§2 任务→代码位置反查表（命名链路/发送链路/设置/快捷键/新建会话/打包/搭档七模块，按函数名定位不依赖行号，含自愈规则）、§3 重点链路详解（搭档命名/发送生成链/设置回声三条高频链路：需求语义+关键坑+正确实现+调用链）、§4 数据契约铁律（IndexedDB 键结构、settings 走 IPC、threadName='' 哨兵语义、userData 路径）
    - `CUSTOMIZATIONS/docs/pitfalls.md`（历史坑点库）：沉淀 8 条（settings store 丢 action 三次返工教训、多实例共用 userData 损坏 IndexedDB、copilot 命名写 threadName 不可见、New-Thread 重复命名、electron-builder UPDATE_CHANNEL、Windows bat 三个解析坑、快捷键注册静默失败、新增设置字段三处联动+14 语言），每条格式：现象→根因→解法→教训
    - 接入：CUSTOMIZATIONS/README.md 目录结构与铁律加两条（写代码前先读 architecture、排查前先扫 pitfalls）；根 AGENTS.md 加"工作流"节（先读图谱定范围→按函数名定位→只读作用域内代码）与"文档更新职责"表（四类改动各更新哪份文档）
    - 未照搬 vibe-coding-starter 的全部文件：ROADMAP/CHANGELOG/HANDOFF 不引入——本仓库改动跟踪已由 registry.md 承担（账本+变更日志），两套机制若并存会造成同一信息两处维护（见变更日志下方的体系评估）；architecture+pitfalls 与 registry 三者职责正交（怎么找代码 / 怎么避坑 / 改了什么），无重叠
- **验证方式**：`npx vitest run .../SessionNamingService.test.ts` 24 测全过（新增用例：threads 含归档话题时只调度 thread key、不调度 name key）；`tsc --noEmit -p packages/chatbox-core/tsconfig.json` 0 错误；biome service 文件无诊断（测试文件 ! 断言为预存风格）
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-005（二次扩展）
- **功能**：修复"搭档会话发消息无返回"（用户 14:44-14:47 四个会话发出消息无 assistant 回复）
- **改动文件**：src/renderer/stores/settingsStore.ts（新增 getSettingsSnapshot）、src/renderer/stores/session/messages.ts、generation.ts、session-settings.ts、tools-builder.ts、src/renderer/hooks/useShortcut.tsx、src/renderer/components/InputBox/useModelToolCapabilities.ts、src/renderer/stores/imageGenerationActions.ts、src/renderer/packages/context-management/summary-generator.ts、model-calls/command-explanation.ts、model-setting-utils/util.ts、src/renderer/pages/RemoteDialogWindow.tsx、src/renderer/setup/storage_clear.ts、6 个测试 mock（agent-harness、tools-builder、streaming-message、useModelToolCapabilities、command-explanation、storage_clear）
- **详细说明**：
  - 排查过程（用 Electron CDP 连打包版 win-unpacked + 用户真实数据）：用户 14:44-14:47 的四个"双语搜索"搭档会话在 IndexedDB 里均为"user 消息存在、0 条 assistant 消息"——用户消息插入成功后生成链中断；同环境 15:40 重发消息完全正常（联网搜索+回复正常），说明是**首启窗口期的状态性故障**而非 CUSTOM 代码逻辑错误。期间发现并排除了环境噪音：调试时双开 dev 实例+强杀导致本地 IndexedDB leveldb 损坏（UnknownError，删除重建后恢复，用户数据完整备份并已恢复）
  - 根因：与用户上一条报的 "TypeError: settingsStore.getState(...).getSettings is not a function"（initEmptyChatSession 崩溃）同根——settings store 的 state 在某条路径下被整体替换导致 action 丢失。上次 005 修复只防御了 initEmptyChatSession 和 subscribe 回声；但生成链上还有 16 处裸 `.getSettings()` 调用。关键的一处在 messages.ts submitNewUserMessageUnlocked：调用点位于 insertMessage(用户消息) **之后**、insertMessage(assistant 空消息) **之前**——state 坏时抛 TypeError，用户消息已持久化但 assistant 消息永不插入，异常被 withSessionGenerationLock 吞掉，界面表现即"发出对话没有返回"。为什么"使用搭档就触发"：新建搭档会话路径上 InputBox/useModelToolCapabilities 等在发送前读 settings 的裸调用先崩，阻断更早
  - 修复（三层防御）：1) createSettingsStore subscribe 回声改函数式合并（已在上一轮做）；2) 新增 `getSettingsSnapshot()`（src/renderer/stores/settingsStore.ts）——action 可用时走 `getSettings()`，否则直接返回 state 字段（state 本身就是 merge 后的 settings 快照，字段齐全）；3) 生成链路 16 处裸调用全部替换为 getSettingsSnapshot()（messages/generation/session-settings/tools-builder/useShortcut/useModelToolCapabilities/imageGenerationActions/summary-generator×3/command-explanation/model-setting-utils/RemoteDialogWindow/storage_clear）
  - "state 被谁替换"未能静态定位（隔离复现含真实 config.json 载荷均无法重现，zustand 对象参数默认浅合并且保留 action）；防御性修复保证无论替换者是谁，关键链路不再可能因此中断。如后续再次出现崩溃类症状，优先排查 hydrate/迁移期间的多实例并发
- **验证方式**：`npx tsc --noEmit -p tsconfig.json` 0 错误；vitest：session 套件 294 测、renderer/stores 503 测、setup 36 测、components（InputBox/chat/session）286 测、packages（context-management/model-*）301 测全过（6 个 mock settingsStore 的测试文件补 getSettingsSnapshot 导出）；biome 改动文件无新增诊断；Electron CDP 实测：dev 与打包版各建搭档会话发消息均正常返回
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-005
- **功能**：修复"修改配置后 TypeError: settingsStore.getState(...).getSettings is not a function"崩溃
- **改动文件**：packages/chatbox-react/src/stores/createSettingsStore.ts、src/renderer/stores/sessionHelpers.ts
- **详细说明**：
  - 现象：打包版应用里修改任意设置（快捷键/搭档命名开关等）后，新建对话首页渲染时 initEmptyChatSession 抛 "getSettings is not a function"，整页报错。上游代码（chatbox-react 的 createSettingsStore），非本次自定义改动引入的文件，但被用户操作触发
  - 分析：settings store 的 state = {...settings 字段, setSettings/getSettings/hydrate/destroy 动作}。SettingsService.publish 时 subscribe 回调把裸 Settings 对象（不含动作方法）传给 zustand 原始 setState。用真实 SettingsService+createSettingsStore+用户 config.json 载荷做隔离复现（含 hydrate/setSettings/setState 函数式/shortcuts 整体替换等多路径）均无法在单 store 场景复现崩溃（zustand setState 对象参数默认浅合并且保留 action），说明真实应用里存在使 state 被整体替换的路径（不排除打包分块/模块求值顺序差异）
  - 修复采取双层防御：1) createSettingsStore 的 subscribe 回调改为函数式合并 `internalSetState((current) => ({ ...current, ...settings }))`，显式保留 action 方法，无论 state 曾被如何替换，服务端回声都会修复 state；2) initEmptyChatSession 容错读取——state 本身就是合并后的 settings 快照，getSettings 动作不可用时直接读 state 字段，保证新建对话页永不因该问题崩溃
  - 两处均用 CUSTOM-20260903-005 标记包裹
- **验证方式**：新增临时复现测试（真实 SettingsService + 用户 config.json 载荷 + hydrate + 快捷键/开关修改 + 函数式 setState，运行后已清理）；`npx vitest run packages/chatbox-react/src/stores/ packages/chatbox-core/src/application/session/SessionNamingService.test.ts` 26 测全过；`npx tsc --noEmit -p tsconfig.json` 0 错误；biome 改动文件无新增诊断（sessionHelpers.ts:741 的 noUnusedFunctionParameters 为预存问题，改动前即存在）；需重新打包（sh CUSTOMIZATIONS/scripts/manager.sh setup）后实测：改设置→新建对话不再报错
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-004
- **功能**：修复 CUSTOM-20260903-002 的两个用户反馈问题（快捷键设置后无效、搭档话题自动命名无可见效果）
- **改动文件**：src/main/main.ts、src/preload/index.ts、src/shared/electron-types.ts、src/renderer/platform/interfaces.ts、src/renderer/platform/desktop_platform.ts、src/renderer/hooks/useShortcut.tsx、packages/chatbox-core/src/application/session/SessionNamingService.ts、packages/chatbox-core/src/application/session/SessionNamingService.test.ts
- **详细说明**：
  - 问题 1（快捷键无效）根因：设置持久化正常（config.json 已验证），但 `globalShortcut.register()` 失败是静默的——返回 false（accelerator 被其他应用占用，如官方版 Chatbox/PowerToys/输入法）或抛异常（accelerator 字符串非法）时，原代码忽略返回值、只把异常写日志文件，用户完全无感知。修复：registerShortcuts 记录注册结果到 main.log（成功/失败均记）、失败时经新 IPC 通道 `shortcut-registration-failed` 推送渲染层、preload/electron-types/Platform 接口/desktop_platform 逐层暴露 `onShortcutRegistrationFailed`、useShortcut hook 订阅并弹 toast（文案含失败的 accelerator 与"可能被其他应用占用"，附"设置"按钮跳转 /settings/hotkeys）；另加自愈机制：注册失败后标记 lastQuickToggleRegistrationFailed，窗口 focus 事件时重试（占用方可能已退出）。注意：本机 9/3 曾同时运行官方版 Chatbox（xyz.chatboxapp.app，09:38-10:34 存活）与 dev 版，两者默认快捷键都是 Alt+`，先注册者独占、后者静默失败——这是用户"Alt+` 也不生效"的最可能直接原因，修复后至少能看到 toast 并在官方版退出后自动恢复
  - 问题 2（搭档话题自动命名无效果）根因：逻辑链完整且开关已生效（config.json 验证 autoNameCopilotThreads=true），命名也确实会跑——但 copilot 会话的 name=搭档名（非 'Untitled'），resolveAutoTitleAction 走 'thread' 路径，只写 threadName；而侧边栏会话列表和顶部标题栏显示的都是 session.name（搭档名），生成的话题名只能在不显眼的对话内话题标签上看到，用户视角"没有任何变化"。修复：syncAutoTitle 中当 action='thread' 且 copilot 会话且开关开启时，改调度 'name-and-thread' 路径（name 与 threadName 一起写，侧边栏/标题栏立即可见改名）；新增私有方法 scheduleCopilotAwareNameAndThreadName，将写保护从"仅 name==='Untitled' 可写"放宽为"Untitled 或 copilot 自动命名会话可写"，避免 generate 的 canWrite 守卫拒绝写入。开关关闭时行为不变（完全跳过）
  - 两个修复均用 CUSTOM-20260903-004 标记包裹；CUSTOM-20260903-002 的旧标记在 SessionNamingService 中被本标记替换（同文件演进），settings-schema/defaults/UI 的 002 标记保留不动
- **验证方式**：`npx vitest run packages/chatbox-core/src/application/session/`（9 文件 66 测全过，含新增 2 用例：开启后 name 与 threadName 均改为生成名、关闭时 chat 不被调用且 name/threadName 原样）；`npx tsc --noEmit -p tsconfig.json` 0 错误；biome check 8 个改动文件无新增诊断（44 警告与改动前基线一致）；快捷键链路需 `pnpm run dev` 手测：正常注册时 main.log 出现 "shortcut [windowQuickToggle] registered"，被占用时弹 toast
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-003
- **功能**：本地操作与打包脚本套件（manager.sh + build-unpacked.bat + build-setup.bat）
- **改动文件**：CUSTOMIZATIONS/scripts/manager.sh（新增）、CUSTOMIZATIONS/scripts/build-unpacked.bat（新增）、CUSTOMIZATIONS/scripts/build-setup.bat（新增）
- **详细说明**：
  - 参考用户另一项目 zgame/app-usage-tracker 的 manager.sh / ci.bat / publish.bat 脚本风格（统一入口 + 分步 bat + 状态输出 + 环境自检），为 chatbox 自定义版写一套本地操作脚本，全部位于 CUSTOMIZATIONS/scripts/（纯新增文件，上游无同名文件）
  - manager.sh（Git Bash 执行，`sh CUSTOMIZATIONS/scripts/manager.sh <command>`）：install（pnpm install + 自动装 7za shim）、dev/build/lint/test（透传 pnpm）、unpacked/setup（转发到对应 bat）、artifacts（列产物）、clean（清 out/dist/release 产物）；自动 cd 到仓库根、前置 require_cmd 检查、kill 运行中的 Chatbox.exe
  - build-unpacked.bat：electron-builder `--dir --win` 打目录免安装包，产物 release/build/win-unpacked/Chatbox.exe；build-setup.bat：NSIS Setup 包，产物 release/build/Chatbox-\<version\>-Setup.exe（版本号从 release/app/package.json 读取，与 electron-builder artifactName 一致），完成后输出产物路径与大小
  - 两个 bat 的公共设计：`--skip-build` 跳过 pnpm run build（用现有产物重打包，调试打包流程用）；其余参数透传给 electron-builder；打包前自动检查/安装 7za shim（CUSTOM-20260902-003，检测 7za-real.exe 是否存在，缺失时用 CUSTOMIZATIONS/scripts/7za-shim.exe 补装）；taskkill 结束 Chatbox.exe 防产物占用；失败路径 exit /b 1 保证 CI 串联
  - 三个环境坑（实测踩到并修复）：1) bat 内不能用中文注释——chcp 65001 下 cmd 重读批处理文件偏移错乱，把 rem 中文行拆断当命令执行（参考项目 bat 全 ASCII 正是此因），两 bat 最终纯英文；2) if 块内 echo 文本含未转义 `)` 会中断 cmd 括号解析（`. was unexpected`），`--skip-build` 提示语需写成 `^(--skip-build^)`；3) electron-builder.yml 的 publish.channel 引用 `${env.UPDATE_CHANNEL}`，`--publish never` 也会因缺该环境变量中止，bat 内用 cross-env UPDATE_CHANNEL=alpha 注入（与 package.json 的 package script 行为一致）
  - 正式发布（GitHub Release、版本号、release notes）仍走 chatbox-release skill，本套件只覆盖本地打包
- **验证方式**：`sh CUSTOMIZATIONS/scripts/manager.sh help`/`artifacts`/未知命令（exit 2）正常；`build-setup.bat --skip-build --config bogus.yml` 干跑验证参数解析与失败路径 exit=1；真实打包跑通两种包：unpacked（win-unpacked/Chatbox.exe 约 201MB）与 Setup（Chatbox-1.23.0-custom.1-Setup.exe 约 245MB + blockmap，NSIS x64+arm64）；manager.sh unpacked/setup 转发 --skip-build 均成功回显产物
- **基于上游版本**：v1.23.0 (61191ae7)

### 2026-09-03 - CUSTOM-20260903-002
- **功能**：快捷键新增 Win+Shift+Space 预设；搭档对话新话题自动命名开关
- **改动文件**：packages/chatbox-core/src/domain/settings/settings-schema.ts、packages/chatbox-core/src/domain/settings/settings-defaults.ts、packages/chatbox-core/src/application/session/SessionNamingService.ts、packages/chatbox-core/src/application/session/SessionNamingService.test.ts、src/renderer/routes/settings/chat.tsx、src/renderer/components/Shortcut.tsx、src/renderer/i18n/locales/{en,zh-Hans,zh-Hant,ja,ko,de,fr,es,it-IT,pt-PT,ru,ar,sv,nb-NO}/translation.json
- **详细说明**：
  - 快捷键：`shortcutToggleWindowValues` 数组新增 `'Super+Shift+Space'`（与 CUSTOM-20260902-001 的 Alt+Shift+Space 合并到同一标记块）。Electron accelerator 用 `Super` 表示 Windows 键；主进程 `normalizeShortcut`（src/main/main.ts）无需转换直接透传，`isValidShortcut` 的修饰键列表已含 `super`。渲染层 Shortcut.tsx 的 `formatKey` 补充了 `super` → Win（Windows）/Super（Linux）的显示映射（macOS 无该映射，显示原文 Super）
  - 搭档话题自动命名：上游机制为——Copilot 会话创建时 `name`=搭档名、`threadName=''`（待命名），首次回复成功后 `resolveAutoTitleAction` 返回 `'thread'` 并调度 `scheduleThreadName`（用 threadNamingModel 生成、只写 threadName）；显示层优先展示 threadName，因此话题名会覆盖搭档名。本改动在 `SessionNamingService.syncAutoTitle` 中加了门槛：`action === 'thread'` 且 `session.copilotId` 存在且 `autoNameCopilotThreads !== true` 时直接 return，即默认关闭时搭档话题保持搭档名；`'session-and-thread'`（name 仍为 Untitled 的会话，如从话题晋升的新会话）不受影响，`autoGenerateTitle` 总开关与 backfill 逻辑也不受影响
  - 设置项：SettingsSchema 新增 `autoNameCopilotThreads: z.boolean().default(false)`（位于 SettingsSchema 层、不在 GlobalSessionSettingsSchema，纯全局设置不随会话下发）；settings-defaults.ts 同步默认值；设置 UI 开关放在 设置→对话设置→功能 小节、「自动生成聊天标题」之后，带说明文案；14 个语言文件均补充两条翻译键（`Auto-Name New Topics of Copilot Chats` 及其描述）
  - 注意：该开关只控制"首次回复后的 AI 命名"；用户手动改名（Header 编辑）不受影响。上游合并时若 syncAutoTitle 被重构，按函数名找新位置重放该 if 块
- **验证方式**：`npx vitest run packages/chatbox-core/src/application/session/SessionNamingService.test.ts`（21 过，含新增的 copilot 门槛用例：默认关闭跳过、开启调度、Untitled Copilot 不受影响）；`npx tsc --noEmit -p tsconfig.json` 与 `-p packages/chatbox-core/tsconfig.json` 无错误；biome check 全部改动文件无新增诊断（已 apply organizeImports 修复）；全套 vitest 4078 过 / 26 败——失败项（src/main/skills、session-attachment-rag、sandbox 等路径分隔符/环境类）在改动前的干净树上同样失败，与本次改动无关
- **基于上游版本**：v1.23.0 (61191ae7)

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

