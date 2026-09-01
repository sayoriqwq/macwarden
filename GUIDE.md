# Macwarden 导读

领域词汇和不变量以 [CONTEXT.md](CONTEXT.md) 为准。Macwarden 本身只做两件事：保存 immutable Observation/Transition records，并让 Capture/Recall Skills 围绕这些记录形成闭环。

```text
mw-capture → Core → authority → mw-recall → verified host work → mw-capture
```

## 构建与验收

需要 Koka 3。唯一公开验收入口在隔离临时目录构建 Core checks 与 CLI，不读取或修改用户 authority：

```console
./acceptance.sh
```

手动构建：

```console
nix shell nixpkgs#koka --command koka -v0 -i./src -o macwarden src/macwarden.kk
```

## Authority

首次使用：

```console
macwarden setup [AUTHORITY_DIR]
```

省略目录时使用当前 Git 根目录下的 `authority/`。选择保存为绝对路径，后续工作目录不会改变它。Authority 只有两个 canonical record 目录：

```text
authority/
  observations/<id>.md
  transitions/<id>.md
```

现有文件永不覆盖。CLI 先校验整个 draft，再以 atomic no-replace 方式写新的 Observations，持久同步 `observations/` 后才写 Transitions；因此失败不会留下引用不存在 Observation 的 Transition。若 record 已 link 但 durability 无法确认，错误会指出该 immutable record 可能已经存在，重试前应先用 `show` 核对。Git-backed authority 由 Capture Skill 在 readback 后提交。

`list`、`show` 与 `capture` 都先把目录内容打开为一个经过验证的 Authority：persisted bytes 必须 canonical，record identity 必须与路径一致、identity 必须唯一、所有 Transition references 必须指向已存在的 Observation。文件系统枚举顺序不影响验证结果。

## CLI

实时 contract 以程序为准：

```console
macwarden --help
macwarden capture --help
```

- `path`：显示 configured authority。
- `list`：列出 `observations/<id>` 与 `transitions/<id>` selectors。
- `show <selector>...`：读取并验证 canonical records。
- `capture <draft.md>`：整体校验并追加一个或多个 records。

CLI 不提供语义搜索。Recall Skill 根据 selector 和 Transition references 选择最小记录集。

Draft 直接拼接 canonical records，分隔线为 `<!-- macwarden:record -->`。它没有独立 schema。稳定输入骨架只有：

- [Observation template](skills/mw-capture/references/observation.md)
- [Transition template](skills/mw-capture/references/transition.md)

Transition template 同时携带完整 Before/After Observations。已有 Before 必须与 authority 中相同 identity 的 record 完全一致；Core 将其视为 idempotent 输入，只写真正新增的 records。多个 Scope 通过重复 Observation block 和 reference 行表达。

## Skills

插件只包含：

- `mw-capture`：把当前证据蒸馏成一个 draft，调用 CLI，并验证/提交新增 records。
- `mw-recall`：沿 references 读取相关历史，以当前 host readback 重新计算工作；验证完成后调用 Capture 闭环。

Skills 判断事实质量；程序只判断结构、引用完整性和 append-only identity。Observation 不是“最新状态”指针，Change 也不是命令流。

Canonical record 的正文跟随用户语言；中文请求使用中文，ID、路径、命令和选项名保持原样。Recall 将同一批 records 临时组织为用户语言的审计视图，不保存第二份报告或真源。

## Koka 边界

Production seam 只有两个 module：

```text
src/macwarden/core.kk  pure Core façade
src/macwarden.kk       CLI, configured authority, filesystem adapter
```

Core 的 implementation 按职责组织在 `src/macwarden/core/`：`record.kk` 只维护单条 record 的领域类型与 canonical grammar；`authority.kk` 维护集合不变量、查询与 append-only capture plan；`error.kk` 定义公开 failure contract。Typed failure flow 留在各自 implementation module 内，不形成新的外部 seam，caller 只 import `macwarden/core`。

`Authority` 是 opaque validated value。CLI 只把目录读成 `AuthorityEntry`，并执行 Core 返回的 `PlannedWrite`；它不解析 record，也不自行验证 graph。Core 是唯一 record grammar authority。CLI 使用 Koka 标准 effects；`macwarden-inline.c` 只提供 atomic no-replace publication 与目录 durability barrier。没有 Repository abstraction、第三个 production seam、transaction manager、Capture record、semantic index、host mutation 或 recovery program。

## Codex 插件

`.codex-plugin/plugin.json` 直接分发现有 `skills/`，不安装 CLI。安装插件前需单独把 `macwarden` 放入 `PATH` 并完成一次 `setup`。

本 package contract 于 2026-08-27 依据 OpenAI 的 [Build plugins](https://developers.openai.com/plugins/build/plugins) 与 [Agent Skills](https://developers.openai.com/codex/skills) 核对。
