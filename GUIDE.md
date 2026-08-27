# Macwarden 导读

Macwarden 用一个很小的 Koka CLI 维护 ScopeLog。每个 Scope 回答一个长期稳定的业务问题；文件最后一个 State 是该 Scope 已确认的当前状态。

```text
ScopeLog = ScopeId + Initial State + List<Transition(Reason, New State)>
         = S0 --R1--> S1 --R2--> ... --Rn--> Sn
```

State 与 Reason 都是 opaque Markdown。CLI 只保护固定标题、非空内容、Scope 匹配和 Transition 拓扑，不判断文字是否真实、完整或语义相等。

## 构建与验收

需要 Koka 3。仓库的公开验收入口会在临时目录构建名为 `macwarden` 的可执行文件：

```console
./acceptance.sh
```

该入口在临时 build 目录分别编译无框架的 Koka core checks 与 `macwarden`，先执行 core laws，再通过隔离的 HOME、XDG 配置、Git 仓库和 Scope 目录检查 CLI 黑盒边界，不接触用户已有 authority。Shell 只保留 setup 与持久 authority、三种 capture、list/show、拒绝写入及 tracked residue scan；parse/render、拓扑、显式 domain error 与 rollback payload identity 直接由 Koka 验证。

手动构建时把 application 模块的输出命名为 `macwarden`。Codex 插件只分发 Agent Skills，不包含 CLI、runtime 或 installer wrapper。使用 Skill 前，另行构建或安装 `macwarden`，确保命令在 `PATH` 中，并运行一次 `macwarden setup`。

## 一次性设置 authority

每个用户只有一个 active ScopeLog 目录。首次使用先运行：

```console
macwarden setup
```

无参数时，Macwarden 找到当前 Git 工作区根目录并选择其中的 `scopes/`。也可以向 `setup` 提供一个明确目录。两种形式都会创建或验证目录、canonicalize 为绝对路径，并打印最终 authority。

选择结果存放在 absolute `XDG_CONFIG_HOME` 下；未设置或值为 relative path 时使用 home 的标准 `.config` 目录。配置文件只保存 authority 的绝对路径。工作目录变化不会改变选择，只有再次运行 `setup` 才会切换它；V1 没有 profile。

`macwarden path` 显示当前选择。尚未设置时，其余操作会停止并给出一条可直接执行的 setup 指引，不会猜测目录。

## 高层 CLI

先以实际程序为准：

```console
macwarden --help
macwarden capture --help
```

`list` 只列出稳定 Scope ID，不读取所有正文。`show` 接受一个或多个精确 ID，返回完整 canonical ScopeLog；每个日志自身保留受保护的 `# Scope:` 起始标题，因此多日志边界明确。CLI 不提供语义搜索，候选选择由 Agent 完成。

`capture` 只消费明确的 Markdown 文件，不从 prose 推断字段。它覆盖三种操作：

- 新 Scope 只有已确认的当前 State：建立 initial State。
- 新 Scope 同时有可信 Before State、Reason、After State：一次完成 initial State 与第一条 Transition。
- 已有 Scope 有一个 Reason 与 self-contained New State：追加一条 Transition。

组合含糊、缺输入、body 为空或包含保留结构标题时，CLI 在写入前拒绝。成功输出 Scope、canonical 路径及 initialized/appended 结果，调用方再用 `show` 验证最终 State。当前参数名与组合规则只由 `macwarden capture --help` 维护，本文不缓存它们。

低层 `init` 与 `append` 仍保留，用于直接操作同一个 configured authority；日常 Agent 流程使用 `capture`。

## Codex 插件

仓库根目录是名为 `macwarden` 的 Codex 插件；`.codex-plugin/plugin.json` 直接指向现有 `skills/`，因此 Skill source 只有一份：

- `skills/mw-capture/SKILL.md`
- `skills/mw-recall/SKILL.md`

插件不声明 MCP server、app、hook 或其他能力。配置一个包含该插件的 marketplace source 后，用当前 CLI 安装：

```console
codex plugin marketplace add MARKETPLACE_SOURCE
codex plugin add macwarden@MARKETPLACE
```

安装后开始新的 Codex session，再使用 `mw: capture ...` 或 `mw: recall ...`。插件不会安装 `macwarden` 命令；其独立 prerequisite 见“构建与验收”。

本 package contract 于 2026-08-27 按以下 OpenAI 官方来源核对：

- [Build plugins](https://developers.openai.com/plugins/build/plugins)
- [Agent Skills](https://developers.openai.com/codex/skills)
- [`openai/codex` plugin validator at `e363b08c9175ac1cbe5893615dd2cb9ddf95043b`](https://github.com/openai/codex/blob/e363b08c9175ac1cbe5893615dd2cb9ddf95043b/codex-rs/skills/src/assets/samples/plugin-creator/scripts/validate_plugin.py)

本地验证版本为 `codex-cli 0.146.0`（官方 tag `rust-v0.146.0`，commit `e363b08c9175ac1cbe5893615dd2cb9ddf95043b`）。

### `mw: capture [optional scope hint]`

Capture 只使用当前任务或对话。它先确认 authority 并读取实时 CLI help；有 hint 时先检查该 Scope，否则从 cheap inventory 中选择最小候选集。随后将上下文蒸馏为稳定 Scope、核心 Reason 与 self-contained current State。新 Scope 若拥有可信 Before/Reason/After，会保留这条 Transition。

显式前缀提供写入 Macwarden 的 authority。Skill 只在 Scope 或事实会被缺失、冲突信息实质改变时提问。它通过临时 Markdown 调用 CLI，并在读回 canonical ScopeLog、确认 intended current State 后才完成。

### `mw: recall [optional semantic query]`

Recall 优先使用前缀后的 query；没有 suffix 时使用当前请求或上下文。它从 `list` 的稳定 ID 语义选择最小候选集，再以 `show` 读取完整日志，首选候选不能回答时才扩大。

纯检索只返回相关 current State、Reasons、约束和 Scope identity。若同一请求包含明确修改指令，Recall 在已记录约束下协作；信息不足就说明缺口并交还控制。经授权工作产生 verified new host state 时，它通过指向 model-invoked Capture Skill 的单一 context pointer 闭环，不复制 Capture workflow，也不要求第二个前缀。

两条流程都以 configured ScopeLogs 和当前上下文为边界，不建立 embedding、vector index 或网络检索层。

## canonical grammar 与 Koka 边界

一个文件由固定标题组成：一个 Scope heading、一个 initial State，随后是零个或多个 Transition Reason/State 对。State 数始终比 Transition 数多一。

production code 只有两个工程层。pure core 拥有 `ScopeId`、`State`、`Reason`、`Transition`、`ScopeLog` ADT、显式 domain errors、smart constructors，以及 total parse/render/append transformation；它不接触 filesystem、environment、process、config 或 CLI。Old State 由前驱 State 推导，Current State 由最后一个 State 推导，因此不存重复字段。

body 作为原始字符串保留；`make-state` 与 `make-reason` 只以 trim 判断 blank，成功值仍携带原字符串。整行 `## State`、`## Transition` 或 `# Scope: ...` 会被拒绝，普通 Markdown、Unicode、尾随空格和 inline 标题仍可保留。

application/CLI 层只使用 Koka 标准 filesystem、environment、path、process 与 exception effects，以既有 `<fsys,exn>` 边界负责 configured authority、文件读取写入、command behavior，并把 core error 转成 CLI exception。可执行入口与 dispatch 留在同一层，无第三个 production wrapper。没有 custom effect、generic schema、host adapter、background capture、semantic index 或自动 host mutation。
