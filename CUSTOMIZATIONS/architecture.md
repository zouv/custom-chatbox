# 代码链路图谱 · chatbox-custom

> **本文件的目的**：给 AI（及人类）一份「读这一份就能定位代码」的导航地图，
> 避免每次改动/排查都全量扫描源码，节省上下文与 token。
>
> **维护铁律**：改了代码结构（新增函数 / 移动逻辑 / 改数据流 / 改接口），必须同步更新本文件。
> **体量铁律**：超过 ~400 行即拆分——保留 §0 / §0.5 / §1，各模块细节拆到 `docs/arch/<module>.md`。
>
> **配套**：历史坑点见 [`docs/pitfalls.md`](./docs/pitfalls.md)；改动账本见 [`registry.md`](./registry.md)。

---

## 0. 一句话架构

Electron + React + TypeScript：**主进程**（src/main）管窗口/托盘/全局快捷键/IPC/sandbox；
**渲染进程**（src/renderer）是全部业务 UI，会话数据存 **IndexedDB**（localforage `chatboxstore`）、
设置存**主进程文件**（config.json，经 IPC）；可复用领域逻辑在 `packages/chatbox-core`（SessionService / NamingService 等）、
React 绑定在 `packages/chatbox-react`。

```
renderer (React, hash 路由 /#/session/:id)
   │  useSessionList / sessionQueryBridge (React Query)
   ▼
chatbox-react (createChatApplication: 组装 store + service + hooks)
   ▼
chatbox-core  SessionService / SessionWriteCoordinator / SessionNamingService / ThreadService
   ▼
CurrentSessionRepository (renderer adapter) ── IndexedDB(localforage) + meta 分页
设置: RendererSettingsStorage ──IPC setStoreValue──▶ main store-node(electron-store→config.json)
快捷键/托盘/更新: main.ts ──IPC──▶ preload(contextBridge) ──▶ renderer platform
```

技术栈 / 关键约束：pnpm（禁 npm/yarn）；Biome；Vitest；vitest 项目级 include 限 `src/**`、`packages/**`；
上游同步走 `chatbox-merge-upstream` skill（禁手动 merge vendor）。

---

## 0.5 任务作用域路由（先定范围，避免污染上下文）

| 任务类型 | 该读（仅限） | 可忽略 | 入口 |
|---|---|---|---|
| 会话/话题自动命名 | `SessionNamingService.ts` + `auto-title.ts` + `session-ui-effects.ts` | UI 组件、main | §2.1 |
| 发消息链路（发了没回复/生成失败） | `messages.ts` → `generation.ts` → `GenerationService`（core） | 设置页、导出 | §2.2 |
| 设置读写（settings store 相关） | `createSettingsStore.ts`、`settingsStore.ts`(renderer)、`RendererSettingsEffects.ts` | 业务组件 | §2.3 |
| 全局快捷键 | `main.ts(registerShortcuts)`、`Shortcut.tsx`、`useShortcut.tsx` | 生成/会话 | §2.4 |
| 新建会话/新建话题 | `routes/index.tsx`、`sessionHelpers.ts(initEmptyChatSession)`、`ThreadService.ts` | main | §2.5 |
| 打包/发布 | `CUSTOMIZATIONS/scripts/*`、`electron-builder.yml`、`.erb/scripts/*` | 全部业务代码 | §2.6 |
| 搭档（Copilot）相关 | `routes/index.tsx`、`agent-harness.ts`、`copilotStore.ts` | 打包脚本 | §2.7 |

> 定位优先级：**函数名 grep > 本表**。表过期时以代码为准并顺手订正本表。

---

## 1. 文件职责速查

| 文件/目录 | 职责 | 何时改它 |
|---|---|---|
| `src/main/main.ts` | 主进程入口：窗口、托盘、全局快捷键注册、IPC 注册 | 快捷键/托盘/新 IPC 通道 |
| `src/main/store-node.ts` | electron-store 封装；config.json 读写与自动备份 | 设置持久化问题 |
| `src/preload/index.ts` | contextBridge：IPC 通道白名单 + 事件订阅 | 新增 main→renderer 推送 |
| `src/shared/electron-types.ts` | ElectronIPC 接口（invoke + on* 事件） | 同上（preload/renderer/main 三处同步改） |
| `src/renderer/app/renderer-application.ts` | 渲染端组合根：createRendererApplication + settings-runtime 门面 | 应用装配/初始化顺序 |
| `src/renderer/stores/settingsStore.ts` | settings 门面（zustand store + `getSettingsSnapshot` 安全访问） | 设置读取方式 |
| `src/renderer/stores/session/` | 会话 store：crud/messages/generation/threads/naming/forks | 会话与消息流 |
| `src/renderer/presentation/session/session-ui-effects.ts` | session-updated 事件 → 自动命名触发 | 命名触发时机 |
| `packages/chatbox-core/src/application/session/` | SessionService / **SessionNamingService** / ThreadService / WriteCoordinator | 会话领域逻辑（命名规则改这里） |
| `packages/chatbox-core/src/session/auto-title.ts` | 命名资格判定（resolveAutoTitleAction / threadName 语义） | 命名触发条件 |
| `packages/chatbox-react/src/stores/createSettingsStore.ts` | settings zustand store 工厂（subscribe 回声、setState 桥接） | store state/action 行为 |
| `packages/chatbox-core/src/domain/settings/settings-schema.ts` | Settings zod schema（含 CUSTOM 快捷键枚举/ openThreadHistory、autoNameCopilotThreads） | 新设置字段 |
| `packages/chatbox-core/src/domain/settings/settings-defaults.ts` | createDefaultSettings | 同上（默认值必须同步） |
| `src/renderer/routes/settings/chat.tsx` | 设置→对话设置页（功能开关区） | 新开关 UI |
| `src/renderer/routes/settings/hotkeys.tsx` + `components/Shortcut.tsx` | 快捷键设置页与键位显示 | 快捷键 UI（含 openThreadHistory 条目） |
| `src/renderer/i18n/locales/*/translation.json` | 14 种语言翻译（**bat 脚本禁忌见 pitfalls #6**） | 新 UI 文案 |

---

## 2. 任务 → 代码位置反查

### 2.1 会话/话题自动命名

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 命名触发门槛（何时调度 AI 命名） | `SessionNamingService.syncAutoTitle` | CUSTOM 块在此：copilot 会话首轮升级 name-and-thread 的判定（threads 为空才升级） |
| 命名资格（Untitled/threadName 语义） | `resolveAutoTitleAction`（auto-title.ts） | `name==='Untitled'` → session-and-thread；否则 threadName 待填 → thread |
| 写回（只写 threadName 还是连 name） | `SessionNamingService.writeGeneratedName` | mode: 'name-and-thread' \| 'thread' |
| 命名用哪个模型 | `SessionNamingService.buildSettings` | 优先 globalSettings.threadNamingModel |
| 事件入口（消息持久化后触发） | `registerSessionUiEffects`（session-ui-effects.ts）→ `syncSessionAutoTitle` | 只信 meta!=null 且非 hidden 的 session-updated |
| 渲染端包装 | `stores/session/naming.ts` | namingService 单例在此组装 |

### 2.2 发消息链路（排查"发出无回复"必读）

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 发送入口（用户+assistant 消息插入顺序） | `submitNewUserMessageUnlocked`（messages.ts） | **user 消息 insert 后、assistant 消息 insert 前**的任何抛错都会造成"发出无回复"（见 pitfalls #1） |
| 生成编排 | `_generateWithoutSessionLock`（generation.ts）→ `currentGenerationService.orchestrate` | 生成锁 withSessionGenerationLock 包裹 |
| 生成核心（core） | `GenerationService.orchestrate` | agent-mode 建议调用在首条消息时 |
| 生成锁 | `withSessionGenerationLock`（@chatbox/core/generation） | 异常会被锁的 catch 部分吞掉——排查时看渲染 console |
| 流式持久化 | `persistStreamingMessage` / `updateStreamingCache`（messages.ts） | 2s 节流 |

### 2.3 设置读写

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 加新设置字段 | `SettingsSchema`（settings-schema.ts）+ `createDefaultSettings` + UI + 14 语言翻译 | 字段放 SettingsSchema 层（不进 GlobalSessionSettingsSchema）则不随会话下发 |
| 命令式读设置（**必须用安全访问器**） | `getSettingsSnapshot()`（stores/settingsStore.ts） | 严禁 `settingsStore.getState().getSettings()` 裸调用（pitfalls #1） |
| store 回声 | `createSettingsStore` 内 `service.subscribe` | 现为函数式合并保 action |
| 设置→主进程联动 | `RendererSettingsEffects.start`（subscribe 后 ensureShortcutConfig/proxy/autoLaunch） | 只在值变化时触发 |
| 持久化路径 | `SettingsService.updateSettings` → RendererSettingsStorage → IPC `setStoreValue` | config.json，10 分钟自动备份 |

### 2.4 全局快捷键

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 预设组合列表 | `shortcutToggleWindowValues`（settings-schema.ts） | 同时是 UI 下拉与 zod 枚举 |
| 键位显示映射 | `formatKey`（components/Shortcut.tsx） | Windows 上 `super`→Win 需显式映射 |
| 主进程注册 | `registerShortcuts`（main.ts） | 只管 quickToggle 窗口显隐；结果已记录日志；失败经 `shortcut-registration-failed` 推送渲染层 toast |
| 自愈重试 | `retryQuickToggleRegistrationIfFailed` + mainWindow 'focus' 事件 | 注册被占后焦点恢复时重试 |
| 渲染层通知 | `useShortcut.tsx` 里 `platform.onShortcutRegistrationFailed` 订阅 | |
| 应用内快捷键（key 值 mod+X） | `useShortcut.keyboardShortcut` → `isShortcutPressed` | openThreadHistory（mod+h，打开历史话题抽屉）等都在渲染层 keydown 处理，不走主进程 |
| 历史话题抽屉开关 | `openThreadHistoryDrawer`（useShortcut.tsx）→ `showThreadHistoryDrawerAtom` | 经 `sessionQueryBridge.getSession` + `isThreadHistoryAvailable` 判定（与 Toolbar 同门槛） |

### 2.5 新建会话/新建话题

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 新会话初始（含搭档） | `routes/index.tsx`：session state + `createPersistedChatSession` | copilot 会话：name=搭档名、threadName=''、copilotId |
| 空会话工厂 | `initEmptyChatSession`（sessionHelpers.ts） | 已用 getSettingsSnapshot 容错 |
| 会话内新话题 | `startNewThread`（threads.ts）→ `ThreadService.refreshContextAndCreateNew` | 归档旧对话进 threads、threadName 置 '' |
| 会话创建（core） | `SessionService.createSession` | threadName 默认 ''（pending 语义） |

### 2.6 打包/发布

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 本地打包 | `CUSTOMIZATIONS/scripts/manager.sh`（unpacked/setup）| bat 全 ASCII（pitfalls #6） |
| electron-builder 配置 | `electron-builder.yml` | UPDATE_CHANNEL=alpha 必须注入 |
| 版本号 | `release/app/package.json` 的 version | 产物名用它 |
| 正式发布 | `chatbox-release` skill | 本地脚本不含 git/release 操作 |

### 2.7 搭档（Copilot）

| 我要改的东西 | 关键函数 / 锚点 | 备注 |
|---|---|---|
| 新建会话选搭档 | `routes/index.tsx`（search 参数 copilotId/copilot + selectedCopilot effect） | |
| 生成时记忆/人格 | `agent-harness.ts`（getCopilotMemorySelection、resolveSessionPromptContextSnapshot） | 上游代码 |
| 搭档列表存储 | `stores/copilotStore.ts`（myCopilotsAtom，IndexedDB 'myCopilots'） | |

---

## 3. 重点链路详解（高频改动区）

### 3.1 搭档会话自动命名（本次自定义核心）

- **需求语义**：`autoNameCopilotThreads` 开启时，搭档会话**首轮对话**用 threadNamingModel 生成话题名并**同时写 name+threadName**（侧栏可见）；后续 New-Thread 轮次回到上游行为（只写 threadName，不动会话名）；关闭时完全跳过命名。
- **关键坑**：resolveAutoTitleAction 对 copilot 会话永远返回 'thread'（name 非 Untitled）——若只写 threadName，侧栏/标题（读 session.name）看不到任何变化；但无条件升级 session-and-thread 会让 New-Thread 也改会话名。
- **正确实现**：`syncAutoTitle` 中 `action==='thread' && copilotId && autoNameCopilotThreads && !(session.threads?.length)` 才升级；写保护用 `scheduleCopilotAwareNameAndThreadName`（mayWriteSessionName 放宽到 copilot 会话）。
- **调用链**：`persistStreamingMessage` → session-updated 事件 → `session-ui-effects` → `syncSessionAutoTitle` → `SessionNamingService.syncAutoTitle` → schedule(1s) → `generate`（threadNamingModel.chat）→ `writeGeneratedName`。

### 3.2 发送→生成链（排查"发出无回复"）

- **需求语义**：user 消息 insert → assistant 空消息 insert(generating) → orchestrate → 流式回写。
- **关键坑**：`submitNewUserMessageUnlocked` 中两段 insert 之间的任何同步抛错（尤其读 settings）会静默中断链路——用户消息已入库、assistant 消息永远不出现。
- **正确实现**：链上读设置一律 `getSettingsSnapshot()`；新增代码不要在这两段 insert 之间插入可抛错的调用。
- **调用链**：`InputBox.handleSubmit` → `submitNewUserMessage`（锁+guard）→ `submitNewUserMessageUnlocked` → `generate` → `GenerationService.orchestrate`。

### 3.3 设置 store 事件回声

- **需求语义**：UI setSettings → service.updateSettings → publish → subscribe 回声合并进 zustand store。
- **关键坑**：回声直接 `setState(裸对象)` 曾导致 action 方法丢失（'getSettings is not a function'）。
- **正确实现**：回声用函数式更新 `internalSetState((current) => ({ ...current, ...settings }))`。
- **调用链**：见 §0 架构图设置线。

---

## 4. 数据/契约铁律

- 会话数据在 IndexedDB `chatboxstore`（keyvaluepairs store，键 `session:<id>`）；**多个 Electron 实例共用同一 userData 会损坏该库**（见 pitfalls #2）。
- settings 只存主进程 config.json（renderer 经 IPC `setStoreValue`/`getStoreValue`，键 'settings'）。
- `threadName === ''` 是「待命名」哨兵；`undefined` 表示历史字段缺失（会触发 backfill）。**写 '' 而非 undefined**。
- userData 目录：`%APPDATA%/xyz.chatboxapp.ce`（productName 决定）；main 日志在 `<userData>/logs/main.log`。
