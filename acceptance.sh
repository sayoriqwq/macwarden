#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nix shell nixpkgs#koka --command koka -v0 -i"$repo/src" \
  --builddir="$tmp/build/cli" -o "$tmp/macwarden" "$repo/src/scopelog.kk"
nix shell nixpkgs#koka --command koka -v0 -i"$repo/src" \
  --builddir="$tmp/build/core-test" -o "$tmp/scopelog-core-test" "$repo/tests/scopelog-core.kk"
chmod +x "$tmp/macwarden" "$tmp/scopelog-core-test"
"$tmp/scopelog-core-test" >/dev/null
macwarden="$tmp/macwarden"

help=$($macwarden --help)
for command in setup path list show capture init append; do
  grep -F "  $command" <<<"$help" >/dev/null
done
grep -F -- '--before FILE' < <($macwarden capture --help) >/dev/null

export HOME="$tmp/home"
export XDG_CONFIG_HOME=relative-xdg
mkdir -p "$HOME" "$tmp/project/nested" "$tmp/elsewhere"
git init -q "$tmp/project"

default=$(cd "$tmp/project/nested" && "$macwarden" setup)
test "$default" = "$(cd "$tmp/project" && pwd -P)/scopes"
test "$(<"$HOME/.config/macwarden/scopes-dir")" = "$default"

explicit=$($macwarden setup "$tmp/authority")
test "$explicit" = "$(cd "$tmp/authority" && pwd -P)"
(
  cd "$tmp/elsewhere"
  test "$($macwarden path)" = "$explicit"
)

printf '%s' $'### Current\n\n- Value: café  \n- Note: inline `## State`' > "$tmp/current.md"
output=$($macwarden capture current-only --state "$tmp/current.md")
grep -F 'initialized Scope current-only:' <<<"$output" >/dev/null

printf '%s' $'### Policy\n\n- Mode: shared\n' > "$tmp/before.md"
printf '%s' $'Selected focused mode.\n' > "$tmp/reason.md"
printf '%s' $'### Policy\n\n- Mode: focused\n' > "$tmp/after.md"
output=$($macwarden capture workspace-policy --before "$tmp/before.md" \
  --reason "$tmp/reason.md" --state "$tmp/after.md")
grep -F 'initialized and appended Scope workspace-policy:' <<<"$output" >/dev/null

printf '%s' $'Reconfirmed the current value.\n' > "$tmp/current-reason.md"
printf '%s' $'### Current\n\n- Value: confirmed  ' > "$tmp/current-next.md"
output=$($macwarden capture current-only --reason "$tmp/current-reason.md" \
  --state "$tmp/current-next.md")
grep -F 'appended Scope current-only:' <<<"$output" >/dev/null

(
  cd "$tmp/elsewhere"
  printf '%s\n' current-only workspace-policy > "$tmp/expected-list"
  "$macwarden" list > "$tmp/actual-list"
  cmp "$tmp/expected-list" "$tmp/actual-list"
  "$macwarden" show current-only > "$tmp/actual-show"
  { cat "$explicit/current-only.md"; printf '\n'; } > "$tmp/expected-show"
  cmp "$tmp/expected-show" "$tmp/actual-show"
  test "$("$macwarden" show current-only workspace-policy | grep -c '^# Scope: ')" = 2
)

cp "$explicit/current-only.md" "$tmp/before-rejection"
if "$macwarden" capture current-only --state "$tmp/current-next.md" >/dev/null 2>&1; then
  echo 'invalid capture was accepted' >&2
  exit 1
fi
cmp "$tmp/before-rejection" "$explicit/current-only.md"

if git -C "$repo" grep -nE '(/Users/[[:alnum:]_.-]+/|/home/[[:alnum:]_.-]+/)' -- .; then
  echo 'tracked machine-specific path found' >&2
  exit 1
fi
if git -C "$repo" grep -nEi 'wacom|device[-_ ]mapping' -- . ':!acceptance.sh'; then
  echo 'tracked device-mapping residue found' >&2
  exit 1
fi

printf 'Macwarden acceptance passed\n'
