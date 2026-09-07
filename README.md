# Macwarden

Macwarden is a small Koka CLI and Codex plugin for recording verified mutable host state as immutable Observations and Transitions.

```text
Observation = ObservationId + ScopeId + Context + State
Transition  = TransitionId + Before[] + Reason + Change + After[]
```

The CLI validates structure and append-only identity. The Skills judge evidence quality, recall relevant history, and close verified host work with a new capture. Macwarden does not mutate the host, infer current state, run a daemon, build an index, or store recovery programs.

## Validate and build

```console
./acceptance.sh
nix shell nixpkgs#koka --command koka -v0 -i./src -o macwarden src/macwarden.kk
macwarden setup /path/to/project
```

The plugin contains `mw-capture` and `mw-recall`; it does not install the CLI. See [CONTEXT.md](CONTEXT.md) for the domain and [GUIDE.md](GUIDE.md) for operation.

## License

[MIT](LICENSE)
