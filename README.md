# Macwarden

Macwarden is a small Koka CLI and OpenAI Codex plugin for recording verified, mutable host state as ScopeLogs.

```text
ScopeLog = ScopeId + Initial State + List<Transition(Reason, New State)>
```

Each Scope answers one stable question. Its final State is the current local authority, and every change preserves the Reason and complete New State that replaced the previous one.

Macwarden intentionally does not mutate the host, run a daemon, build a semantic index, or treat observations as declarative configuration. Keep real ScopeLogs in a private Git repository; this public repository contains only the mechanism.

## Validate and build

Koka 3 is required. The acceptance entry point builds the core checks and CLI in a temporary directory:

```console
./acceptance.sh
```

Build the executable directly when needed:

```console
nix shell nixpkgs#koka --command koka -v0 -i./src -o macwarden src/scopelog.kk
macwarden setup /path/to/private/scopes
```

## Codex plugin

The repository root is a Codex plugin package containing exactly two Skills:

- `mw-capture` records a verified State or Transition.
- `mw-recall` retrieves the smallest relevant set of ScopeLogs.

The plugin does not install the `macwarden` executable. Put the CLI on `PATH`, configure its private authority once, then install this package through a Codex plugin marketplace.

See [GUIDE.md](GUIDE.md) for the model, CLI contract, plugin specification sources, and workflow details.

## License

[MIT](LICENSE)
