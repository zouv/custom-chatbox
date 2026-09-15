# 历史坑点 / Pitfalls

> **这是什么**：本仓库（chatbox-custom）开发与排查中**踩过的坑**的沉淀。新会话动手前先扫一眼标题，
> 避免重复踩坑。每条写清：现象 → 根因 → 解法 → 验证方式。
>
> **维护铁律**：每解决一个"反复折腾才定位到"的问题，就来这里加一条（一次没定位到就解决的不算坑）。
> 配套：代码位置反查见 [`../architecture.md`](../architecture.md)。

---

## 1. settings store state 丢失 action →「发消息无回复 / getSettings is not a function」

- **日期**：2026-09-03（CUSTOM-20260903-005，前后修了三次才闭环）
- **现象**：
  1. 修改设置后新建对话报 `TypeError: settingsStore.getState(...).getSettings is not a function`（initEmptyChatSession）；
  2. 搭档会话发消息「发出无返回」——用户消息已入库，assistant 消息永远不出现（首启窗口期尤其容易触发，重启自愈）。
- **根因**：settings store 的 state 在某条未定位路径下被整体替换，`getSettings/setSettings/hydrate` 等 action 方法丢失。生成链上 16 处裸 `.getSettings()` 调用会抛 TypeError；关键一处在 `messages.ts submitNewUserMessageUnlocked`——位于 insertMessage(user) **之后**、insertMessage(assistant) **之前**，异常被 withSessionGenerationLock 吞掉 → user 消息入库、assistant 消息永不插入。**同一根因的两种表现，第一次只修了可见的那处，漏了生成链——这是修了三次的原因**。
- **解法（三层防御，缺一不可）**：
  1. `createSettingsStore` 的 `service.subscribe` 回声改为函数式合并 `internalSetState((current) => ({ ...current, ...settings }))`；
  2. 新增 `getSettingsSnapshot()`（`src/renderer/stores/settingsStore.ts`）：action 可用走 `getSettings()`，否则直接返回 state 字段；
  3. **全仓禁用裸 `settingsStore.getState().getSettings()`**——命令式读设置一律 `getSettingsSnapshot()`（新增时 grep 一遍确认）。
- **教训**：
  - 同一类 TypeError 在多个调用点出现时，**第一反应应该是全仓 grep 同模式调用**，而不是只修报错栈里那一处；
  - "改配置后出现"的故障要想到状态被写坏，隔离复现不出来不代表不存在（真实应用存在打包分块/初始化顺序差异）；
  - 排查"发出无回复"：先查 IndexedDB 里该会话的 messages（user 在不在、assistant 在不在），断点立刻清晰。
- **验证**：1420+ 相关测试全过；CDP 直连打包版复测发消息正常。

## 2. 多实例共用 userData → IndexedDB 永久损坏（UnknownError: Internal error）

- **日期**：2026-09-03（排查问题 1 时自己踩的）
- **现象**：渲染进程一切 `indexedDB.open()` 抛 `UnknownError: Internal error`，连 `deleteDatabase` 也失败；所有会话读写报 `SessionRepositoryError: initialize`；leveldb LOG 无新条目。
- **根因**：两个 dev 实例（同 userData `xyz.chatboxapp.ce`）并发 + `taskkill /F` 强杀，Chromium IndexedDB 后端进入损坏态。**dev 模式没有 single-instance lock（只有打包版有）**，双开无任何提示。
- **解法**：杀光所有 Chatbox/electron 进程 → 重命名/删除 `<userData>/IndexedDB` 目录 → 重启自动重建（**数据会丢**；重要数据先备份该目录，其中 `file__0.indexeddb.leveldb` 是会话数据）。
- **教训**：
  - 调试时**绝不同时跑两个实例**；杀 dev 用 `TaskStop`/Ctrl+C 而非 `taskkill /F`（后者留给打包版）；
  - 排查时的"环境噪音"要先排除掉再下结论——本次 IndexedDB 损坏差点误导根因判断；
  - 用户机器上如果报"会话全没了/打不开"，优先怀疑这个：恢复 `IndexedDB.bak-*` 目录即可。

## 3. copilot 会话自动命名「看不见」（threadName 写了但 UI 不变）

- **日期**：2026-09-03（CUSTOM-20260903-002/004）
- **现象**：开关开启、命名也跑了，但侧栏/标题栏毫无变化。
- **根因**：copilot 会话 `name=搭档名`（非 Untitled），`resolveAutoTitleAction` 走 `'thread'` 路径只写 `threadName`；而**侧栏（SessionItem）和标题栏（Header）显示的都是 `session.name`**，`threadName` 只出现在对话内话题标签（MessageList 的 ThreadLabel）上。
- **解法**：见 architecture.md §3.1——首轮升级 name-and-thread 同写两字段。
- **教训**：改"显示逻辑"相关功能前，先确认 UI 实际读的是哪个字段（本例 `session.name` vs `threadName` 的分工是上游隐含契约）。

## 4. copilot 命名无条件升级 → New-Thread 也会改会话名（本轮修复）

- **日期**：2026-09-03（CUSTOM-20260903-006）
- **现象**：已有对话的会话里点「新话题」再发消息，会话名又被自动命名覆盖（用户期望只有新建会话的首句触发）。
- **根因**：升级条件只看 `copilotId && autoNameCopilotThreads`，没区分「会话首轮」与「话题轮次」。New-Thread 会归档旧对话（threads+1）并重置 threadName=''，又满足 'thread' 条件。
- **解法**：升级条件加 `!(session.threads?.length)`——只有从未归档过话题的会话（首轮）才升级。
- **教训**：`threadName=''` 哨兵在 New-Thread/clear/晋升等多种操作后都会出现，**判定「首轮」要用 threads 是否为空，别用 threadName**。

## 5. electron-builder `--publish never` 仍要求 UPDATE_CHANNEL 环境变量

- **日期**：2026-09-03（CUSTOM-20260903-003 打包脚本）
- **现象**：打包中途报 `cannot expand pattern "${env.UPDATE_CHANNEL}": env UPDATE_CHANNEL is not defined`。
- **根因**：electron-builder.yml 的 `publish.channel` 引用 `${env.UPDATE_CHANNEL}`，配置展开发生在 publish 判定**之前**。
- **解法**：打包命令统一 `cross-env UPDATE_CHANNEL=alpha electron-builder build --publish never`（与 package.json 的 package script 一致）。

## 6. Windows bat 脚本的三个解析坑

- **日期**：2026-09-03（build-unpacked.bat / build-setup.bat）
- **坑点**：
  1. **bat 内不能写中文注释/文案**：`chcp 65001` 切码页后 cmd 重读批处理文件的偏移会错乱，中文 rem 行被拆断当命令执行（表现为 `'build，直接用现有产物打包' is not recognized`）。参考项目 bat 全 ASCII 正是为此。**bat 一律纯英文**；中文说明写在 manager.sh（bash）或 md 文档里。
  2. **if 块内 echo 文本含未转义括号**：`echo [1/2] Skipping build (--skip-build).` 在 `if ... ( ... )` 块内会报 `. was unexpected at this time.`——需写 `^(--skip-build^)`。
  3. cmd 下 `find` 可能被 Git Bash 的 Unix find 抢占导致遍历盘符卡死（参考项目注释），计数用纯 for 循环。
- **教训**：bat 改完必须真实跑一遍（`--skip-build --config bogus.yml` 干跑最快）。

## 7. 快捷键注册静默失败（globalShortcut.register 返回 false 被忽略）

- **日期**：2026-09-03（CUSTOM-20260903-004）
- **现象**：设置 Win+Shift+Space 后按了没反应，改回 Alt+\` 也没反应，无任何报错。
- **根因**：`globalShortcut.register()` 被其他应用占用时返回 false，原代码不检查返回值；本机当时官方版 Chatbox 与自定义版**同时运行**且默认快捷键相同（Alt+\`），先注册者独占。另外两版 Chatbox 的 userData 不同但快捷键是系统级的，互不可见。
- **解法**：注册结果写 main.log + 失败时经 IPC `shortcut-registration-failed` 推渲染层弹 toast + 窗口 focus 时自愈重试。
- **教训**：测快捷键前先确认没有另一个 Chatbox 在跑（任务管理器查 Chatbox.exe/electron.exe）。

## 8. 新增设置字段的三处联动 + i18n 全语言

- **日期**：2026-09-03（autoNameCopilotThreads）
- **坑点**：
  1. schema（settings-schema.ts）与 defaults（settings-defaults.ts）**必须同时加**，缺 defaults 会导致 `pnpm run dev` 首启 parse 报缺字段（catch 兜底后行为不一致）；
  2. 开关 UI 文案用 `t('key')`，**14 个语言文件都要加键**（`src/renderer/i18n/locales/*/translation.json`，键放 "Auto-Generate Chat Titles" 旁边）；缺键时界面直接显示英文原文；
  3. 全局设置放 `SettingsSchema` 层（不要进 `GlobalSessionSettingsSchema`，否则会随会话下发并与会话设置合并）。

## 9. 杀软实时扫描锁住刚写出的 exe → rcedit「Unable to commit changes」

- **日期**：2026-09-03（CUSTOM-20260903-009，unpacked/setup 打包失败）
- **现象**：`manager.sh unpacked` 打包到 rcedit 步骤报 `⨯ cannot execute cause=exit status 1, errorOut=Fatal error: Unable to commit changes`，electron-builder 内部 3 次快速重试全部失败中止。日志里紧邻的步骤是 `updating asar integrity executable resource` 与 `[copy-ripgrep]/[patch-libsql]/[runtime-deps]`，容易误判为这些 patch 出错。
- **根因**：electron-builder 每次打包都从 `node_modules/electron/dist/electron.exe` 复制一份新的 200MB `win-unpacked\Chatbox.exe`，随后**立即**用 rcedit 写版本信息/图标。本机火绒安全（HipsDaemon/usysdiag/wsctrl 等）对刚落盘的 exe 做实时扫描并短暂持有句柄，rcedit 打开写入被拒 → "Unable to commit changes"。electron-builder 自带的重试间隔极短（毫秒级），全部落在扫描窗口内。
- **复现与定位**（node 脚本模拟同款时序）：copyFileSync 完成 → 零延迟 spawn rcedit → 稳定复现同样报错；隔 ~3-5 秒再跑则成功。锁窗口实测 0.6s~5s 不等（取决于杀软当时是否触发扫描）。手动单独跑 rcedit 永远成功（此时锁早释放），**不能用"手动能过"排除此因**。
- **解法**：
  1. `build-unpacked.bat` / `build-setup.bat` 的 electron-builder 调用外包一层重试：失败后等 15s 再跑整个 builder（最多 3 轮），扫描窗口是瞬时的，退避重试必过（标记 CUSTOM-20260903-009）；
  2. 一劳永逸：把仓库目录（至少 `release\build\` 与 `node_modules\electron\dist\`）加入火绒信任区。
- **教训**：
  - "文件无法写入"类打包错误先想文件锁，再想权限；新写出的 exe 是杀软最感兴趣的目标；
  - 排查手法：手动复现同一条失败命令 + 模拟原始时序（刚写出文件立刻操作），两者结果不同就指向"时间窗"而非"命令本身"；
  - taskkill 杀 Chatbox.exe 只防"成品被占用"，防不了"新 exe 落盘被扫描"——两回事。
- **验证**：加退避重试后 `--skip-build` 重跑 `[SUCCESS] unpacked build finished`；rcedit `--get-version-string` 确认 FileDescription/ProductName 已写入；启动 win-unpacked 主窗口正常。

## 10. 仓库目录改名/移动 → pnpm workspace 软链指向旧路径，构建/打包报「resolve import @chatbox/core」失败

- **日期**：2026-09-07
- **现象**：`build-unpacked.bat` 在 `[1/2] pnpm run build` 的 build:main 阶段报
  `Rollup failed to resolve import "@chatbox/core/domain/settings" from "src/shared/defaults.ts"`，脚本 exit 1。`--skip-build` 直接跑 electron-builder 阶段却正常——说明问题在 build 不在打包。同时 tsc 报大量 `Module has no exported member 'Settings'/'SessionSettings'`，vitest 报 `Cannot find package '@chatbox/core/domain/settings'`，三者同一根因。
- **根因**：仓库从旧路径 `costom-chat-box` 改名/移动到 `custom-chatbox` 后，`node_modules/@chatbox/core` 与 `node_modules/@chatbox/react` 两个 workspace 软链仍指向旧路径 `/d/Git/zgithub/costom-chat-box/packages/...`（已不存在），`@chatbox/core` 整体解析不到，连锁拉崩依赖它的 `src/shared/defaults.ts` 与 tsc 类型解析。
- **解法**：`CI=true pnpm install` 重建 workspace 链接（指向当前路径）。注意两点：1) 直接 `ln -s` 不可靠——Windows 无符号链接权限（`$MSYS` 为空）时 MSYS 会把 `ln -s` 退化成**目录复制**，反而更糟，应交给 pnpm；2) pnpm 检测到 node_modules 状态异常会提示 `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`，非交互环境加 `CI=true` 放行。`pnpm install` 过程中 `release/app` 项目的 postinstall（electron-rebuild 报 `Unable to find electron's version number`）会失败——这是无关报错，electron-builder 打包时 `ensure-app-deps.cjs` 会自行 `npm ci` 重建 release/app，不影响构建/打包。
- **验证**：`pnpm run build` exit 0；`build-unpacked.bat`（不带 --skip-build）端到端 `[SUCCESS] unpacked build finished`。
- **教训**：`@chatbox/core` 等 workspace 包解析失败时，先 `ls -la node_modules/@chatbox/` 看软链指向的**绝对路径是否仍是当前目录**——仓库 move/rename/clone 到新路径后这是高发点。

## 11. 管道吃掉退出码 → 测试失败被误报为「通过」

- **日期**：2026-09-15（发 v1.23.0-custom.3 时踩的）
- **现象**：`pnpm run test 2>&1 | tail -60` 跑完，日志里有失败堆栈，但命令退出码是 **0**；据此向用户报告"测试通过（exit 0）"，实际那次有 31 个用例失败。差点带着"全绿"的结论去发布。
- **根因**：管道的退出码取**最后一个命令**（`tail`）的退出码，前面 `pnpm run test` 的失败被吞掉；bash 默认不开 `pipefail`。跑打包/测试这类"必须要看退出码"的长命令时，为了看尾部输出而加 `| tail` 是最顺手的写法，也是最容易踩的。
- **解法**：
  1. 一律**重定向到文件**再读，退出码单独取：`pnpm run test > /tmp/t.log 2>&1; echo "EXIT=$?"`
  2. 或者显式 `set -o pipefail`（仅 bash；Git Bash 下可用）
  3. 长任务顺便开后台 + 日志文件 + 轮询关键行（`grep -E "^ FAIL|Test Files|Tests " /tmp/t.log`），既拿得到中途进度，也不丢退出码
- **教训**：
  - **"看输出的管道"和"看退出码"不能同时要**——加了管道，退出码就不再是原命令的了；
  - 报告"测试/构建通过"之前，先确认自己拿到的究竟是哪个进程的退出码；
  - 输出里明明有 `FAIL` 却报通过时，第一反应应该是查退出码来源，而不是相信自己刚写的管道。
- **验证**：重跑改为重定向后 `EXIT=1`，与日志里的 `Tests 16 failed | 4102 passed` 一致。

## 12. 打 tag 后 amend 提交 → 已发布的 tag 悬在游离提交上

- **日期**：2026-09-15（发 v1.23.0-custom.3 时排查历史发现，问题产生于 custom.2 发布时）
- **现象**：`git merge-base --is-ancestor v1.23.0-custom.2 HEAD` 返回非 0，`git branch -a --contains v1.23.0-custom.2` 输出为空——**已发布的 tag 不属于任何分支**。对比发现：tag 指向 `bc5584f6`，分支上是 `0bdcb3bc`，两者提交信息、父提交（`d6b04c12`）都相同，tree 差 4 个文档文件（AGENTS.md + 3 个 SKILL.md）。
- **根因**：打 tag（并发布）之后，又 `git commit --amend`（或等效改写）了那个发布提交。原提交被新提交取代，tag 仍指向旧的那份。
- **解法**：
  1. **tag 创建后不要再改写被 tag 的提交**——要补文档就追加新提交，不要 amend；
  2. 发布前用 `git merge-base --is-ancestor <tag> HEAD` 校验（`publish-release.mjs` 已内置该检查并告警）；
  3. 已推送的 tag 要修正只能 `git tag -f` + `git push -f origin <tag>`，对外可见，需用户确认后再做。
- **影响面**：本例中两版 `package.json` 版本号相同，安装包内容一致，**用户侧无影响**；但用 tag 做 diff / 生成 changelog / 回滚都会以错误的提交为基准（本次生成 release notes 时就差点用错基准）。
- **教训**：tag 是"已发布事实"的锚点，不是随手能挪的标签。发布流程里 tag 应当是最后一步不可变的动作。
- **验证**：`v1.23.0-custom.3` 发布后 `git merge-base --is-ancestor v1.23.0-custom.3 HEAD` 通过，tag 与远端一致（`git ls-remote --tags origin`）。

## 13. fork 仓库里 gh 默认认「上游仓库」→ 不带 `-R` 的命令全打到上游

- **日期**：2026-09-15（装好 gh 2.100.0 后首次使用）
- **现象**：在仓库根目录（`origin` = 自己的 fork）跑 `gh release view v1.23.0-custom.3` 报 `release not found`——而该 release 明明存在（REST API 与浏览器都能看到）。`gh repo view --json nameWithOwner` 输出的是 **`chatboxai/chatbox`**，不是 `zouv/custom-chatbox`。
- **根因**：本仓库有两个 remote（`origin`=自己的 fork、`upstream`=chatboxai/chatbox）。**gh 检测到 fork 关系后会优先选用上游作为 base 仓库**——这是 gh 为 PR 场景设计的默认（在 fork 里默认往上游提 PR）。于是所有不带 `-R/--repo` 的 gh 命令都解析到了上游。
- **影响**：`gh release create` / `gh issue create` 这类**写操作会打到错误仓库**。本例中 token 没有 chatboxai/chatbox 的写权限，会以报错收场；但这属于必须防住的危险默认——若哪天 token 权限变化或换人操作，后果就不是报错了。
- **解法**：
  ```bash
  gh repo set-default zouv/custom-chatbox      # 写入 .git/config 的 remote.origin.gh-resolved=base
  gh repo view --json nameWithOwner            # 验证输出 zouv/custom-chatbox
  ```
  该设置**仅本地生效、不随仓库提交**，所以**新克隆的仓库需要重跑一次**。应急也可在单条命令后加 `-R zouv/custom-chatbox`。
- **教训**：
  - fork 仓库里用 gh，"当前仓库"是 **gh 自己算出来的**，不等于 git 当前目录对应的 origin；凡是写操作的 gh 命令，先用 `gh repo view --json nameWithOwner` 确认目标；
  - 排查"东西明明在却找不到"类问题：先确认工具查的是不是同一个目标（本例中 API 看得到、gh 看不到，差异就在仓库解析）。
- **验证**：`gh repo set-default` 后 `gh repo view --json nameWithOwner` 输出 `zouv/custom-chatbox`，`gh release view v1.23.0-custom.3` 正常列出 title/tag/author 与两个资产。
