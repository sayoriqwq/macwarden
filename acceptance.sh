#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nix shell nixpkgs#koka --command koka -v0 -i"$repo/src" \
  --builddir="$tmp/build/cli" -o "$tmp/macwarden" "$repo/src/macwarden.kk"
nix shell nixpkgs#koka --command koka -v0 -i"$repo/src" \
  --builddir="$tmp/build/core-test" -o "$tmp/macwarden-core-test" \
  "$repo/tests/macwarden-core.kk"
chmod +x "$tmp/macwarden" "$tmp/macwarden-core-test"
"$tmp/macwarden-core-test" >/dev/null
macwarden="$tmp/macwarden"

help=$($macwarden --help)
for command in setup path list show capture; do
  grep -F "  $command" <<<"$help" >/dev/null
done
if grep -Eq '  (init|append)' <<<"$help"; then
  echo 'removed low-level command remains public' >&2
  exit 1
fi
grep -F 'capture <draft.md>' < <($macwarden capture --help) >/dev/null

export HOME="$tmp/home"
export XDG_CONFIG_HOME=relative-xdg
mkdir -p "$HOME" "$tmp/project/nested" "$tmp/elsewhere"
git init -q "$tmp/project"

default=$(cd "$tmp/project/nested" && "$macwarden" setup)
test "$default" = "$(cd "$tmp/project" && pwd -P)/authority"
test -d "$default/observations"
test -d "$default/transitions"
test "$(<"$HOME/.config/macwarden/scopes-dir")" = "$default"

explicit=$($macwarden setup "$tmp/private-authority")
test "$explicit" = "$(cd "$tmp/private-authority" && pwd -P)"
(
  cd "$tmp/elsewhere"
  test "$($macwarden path)" = "$explicit"
)

invalid_record="$explicit/observations/"$'bad\tname.md'
: >"$invalid_record"
if "$macwarden" list >/dev/null 2>&1; then
  echo 'invalid authority record path was silently ignored' >&2
  exit 1
fi
rm "$invalid_record"

observation_template="$repo/skills/mw-capture/references/observation.md"
transition_template="$repo/skills/mw-capture/references/transition.md"

make_observation() {
  local target=$1 id=$2 scope=$3 context=$4 state=$5
  sed -e "s|OBSERVATION_ID|$id|g" \
      -e "s|SCOPE_ID|$scope|g" \
      -e "s|CONTEXT|$context|g" \
      -e "s|STATE|$state|g" \
      "$observation_template" >"$target"
}

append_record() {
  local bundle=$1 record=$2
  printf '\n\n<!-- macwarden:record -->\n\n' >>"$bundle"
  cat "$record" >>"$bundle"
}

make_observation "$tmp/input-before.md" input-before macos-input-selection \
  'Observed before the change.' '- ABC enabled'
make_observation "$tmp/protection-before.md" protection-before hitoolbox-protection \
  'Observed before the change.' '- uchg absent'

grep -F 'captured:' < <($macwarden capture "$tmp/input-before.md") >/dev/null
$macwarden capture "$tmp/protection-before.md" >/dev/null
$macwarden show observations/input-before >"$tmp/shown-input-before.md"
cmp "$explicit/observations/input-before.md" "$tmp/shown-input-before.md"
grep -F 'no changes' < <($macwarden capture "$tmp/shown-input-before.md") >/dev/null

sed -e 's|TRANSITION_ID|remove-abc|g' \
    -e 's|BEFORE_OBSERVATION_ID|input-before|g' \
    -e 's|AFTER_OBSERVATION_ID|input-after|g' \
    -e 's|BEFORE_SCOPE_ID|macos-input-selection|g' \
    -e 's|AFTER_SCOPE_ID|macos-input-selection|g' \
    -e 's|BEFORE_CONTEXT|Observed before the change.|g' \
    -e 's|AFTER_CONTEXT|Read back after the change.|g' \
    -e 's|BEFORE_STATE|- ABC enabled|g' \
    -e 's|AFTER_STATE|- ABC absent|g' \
    -e 's|REASON|Avoid secure-input fallback to ABC.|g' \
    -e 's|CHANGE|Changed the input-source plist and applied uchg.|g' \
    "$transition_template" >"$tmp/transition-base.md"

awk '
  { print }
  $0 == "- input-before" { print "- protection-before" }
  $0 == "- input-after" { print "- protection-after" }
' "$tmp/transition-base.md" >"$tmp/transition.md"

make_observation "$tmp/protection-before-copy.md" protection-before hitoolbox-protection \
  'Observed before the change.' '- uchg absent'
make_observation "$tmp/protection-after.md" protection-after hitoolbox-protection \
  'Read back after the change.' '- uchg present'
append_record "$tmp/transition.md" "$tmp/protection-before-copy.md"
append_record "$tmp/transition.md" "$tmp/protection-after.md"

output=$($macwarden capture "$tmp/transition.md")
grep -F 'observations/input-after' <<<"$output" >/dev/null
grep -F 'observations/protection-after' <<<"$output" >/dev/null
grep -F 'transitions/remove-abc' <<<"$output" >/dev/null

printf '%s\n' \
  observations/input-after \
  observations/input-before \
  observations/protection-after \
  observations/protection-before \
  transitions/remove-abc >"$tmp/expected-list"
$macwarden list >"$tmp/actual-list"
cmp "$tmp/expected-list" "$tmp/actual-list"

$macwarden show transitions/remove-abc >"$tmp/shown-transition"
grep -F -- '- protection-before' "$tmp/shown-transition" >/dev/null
grep -F -- '- protection-after' "$tmp/shown-transition" >/dev/null
$macwarden show observations/input-after observations/protection-after >"$tmp/shown-after"
test "$(grep -c '^# Observation: ' "$tmp/shown-after")" = 2

cp "$explicit/observations/input-before.md" "$tmp/before-conflict"
make_observation "$tmp/conflict.md" input-before macos-input-selection \
  'Changed evidence.' '- ABC absent'
if "$macwarden" capture "$tmp/conflict.md" >/dev/null 2>&1; then
  echo 'immutable record conflict was accepted' >&2
  exit 1
fi
cmp "$tmp/before-conflict" "$explicit/observations/input-before.md"

awk '/<!-- macwarden:record -->/ { exit } { print }' "$transition_template" |
  sed -e 's|TRANSITION_ID|dangling|g' \
      -e 's|BEFORE_OBSERVATION_ID|missing|g' \
      -e 's|AFTER_OBSERVATION_ID|input-before|g' \
      -e 's|REASON|Reason|g' \
      -e 's|CHANGE|Change|g' >"$tmp/dangling.md"
if "$macwarden" capture "$tmp/dangling.md" >/dev/null 2>&1; then
  echo 'dangling Transition was accepted' >&2
  exit 1
fi
test ! -e "$explicit/transitions/dangling.md"

grep -F 'no changes' < <($macwarden capture "$tmp/input-before.md") >/dev/null

race_pids=()
for index in 1 2 3 4 5 6 7 8; do
  make_observation "$tmp/race-$index.md" concurrent-record concurrency \
    "Concurrent capture $index." "- winner: $index"
  (
    while [[ ! -e "$tmp/race-start" ]]; do :; done
    "$macwarden" capture "$tmp/race-$index.md"
  ) >"$tmp/race-$index.out" 2>&1 &
  race_pids+=("$!")
done
: >"$tmp/race-start"
race_successes=0
for pid in "${race_pids[@]}"; do
  if wait "$pid"; then
    race_successes=$((race_successes + 1))
  fi
done
test "$race_successes" = 1
$macwarden show observations/concurrent-record >"$tmp/race-winner.md"
test "$(grep -c '^# Observation: concurrent-record$' "$tmp/race-winner.md")" = 1

order_writer_pids=()
order_reader_pids=()
for index in 1 2 3 4 5 6 7 8 9 10 11 12; do
  sed \
    -e "s/TRANSITION_ID/order-$index/g" \
    -e "s/BEFORE_OBSERVATION_ID/order-before-$index/g" \
    -e "s/AFTER_OBSERVATION_ID/order-after-$index/g" \
    -e "s/BEFORE_SCOPE_ID/order-scope-$index/g" \
    -e "s/AFTER_SCOPE_ID/order-scope-$index/g" \
    -e "s/BEFORE_CONTEXT/Observed before concurrent capture $index./g" \
    -e "s/AFTER_CONTEXT/Observed after concurrent capture $index./g" \
    -e "s/BEFORE_STATE/- before: $index/g" \
    -e "s/AFTER_STATE/- after: $index/g" \
    -e "s/REASON/Concurrent transition $index./g" \
    -e "s/CHANGE/Applied concurrent transition $index./g" \
    "$transition_template" >"$tmp/order-$index.md"
  (
    while [[ ! -e "$tmp/order-start" ]]; do :; done
    "$macwarden" capture "$tmp/order-$index.md"
  ) >"$tmp/order-writer-$index.out" 2>&1 &
  order_writer_pids+=("$!")
  (
    while [[ ! -e "$tmp/order-start" ]]; do :; done
    "$macwarden" list >/dev/null
  ) >"$tmp/order-reader-$index.out" 2>&1 &
  order_reader_pids+=("$!")
done
: >"$tmp/order-start"
for pid in "${order_writer_pids[@]}" "${order_reader_pids[@]}"; do
  wait "$pid"
done

if git -C "$repo" grep -nE '(/Users/[[:alnum:]_.-]+/|/home/[[:alnum:]_.-]+/)' -- .; then
  echo 'tracked machine-specific path found' >&2
  exit 1
fi
if git -C "$repo" grep -nEi 'wacom|device[-_ ]mapping' -- . ':!acceptance.sh'; then
  echo 'tracked device-mapping residue found' >&2
  exit 1
fi

printf 'Macwarden acceptance passed\n'
