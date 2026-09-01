module tests/macwarden-core

import macwarden/core

fun fail-test(message : string) : exn a
  throw("Macwarden core check failed: " ++ message)

fun check(condition : bool, message : string) : exn ()
  if !condition then fail-test(message)

fun right(result : either<domain-error,a>, message : string) : exn a
  match result
    Left(err) -> fail-test(message ++ ": " ++ render-error(err))
    Right(value) -> value

fun expect-error(result : either<domain-error,a>, expected : string, message : string) : exn ()
  match result
    Left(err) -> check(render-error(err) == expected, message ++ ": " ++ render-error(err))
    Right(_) -> fail-test(message ++ ": accepted invalid input")

val separator = "\n\n<!-- macwarden:record -->\n\n"

fun observation(id : string, scope : string, details : string, state : string) : string
  "# Observation: " ++ id ++
  "\n\n## Scope\n\n" ++ scope ++
  "\n\n## Context\n\n" ++ details ++
  "\n\n## State\n\n" ++ state

fun transition(id : string, before : list<string>, reason : string,
               change : string, after : list<string>) : string
  "# Transition: " ++ id ++
  "\n\n## Before\n\n" ++ before.map(fn(ref) { "- " ++ ref }).join("\n") ++
  "\n\n## Reason\n\n" ++ reason ++
  "\n\n## Change\n\n" ++ change ++
  "\n\n## After\n\n" ++ after.map(fn(ref) { "- " ++ ref }).join("\n")

fun observation-entry(id : string, markdown : string) : authority-entry
  AuthorityEntry("observations/" ++ id, markdown)

fun write-entry(write : planned-write) : authority-entry
  match write
    PlannedWrite(selector, markdown) -> AuthorityEntry(selector, markdown)

fun write-selector(write : planned-write) : string
  match write
    PlannedWrite(selector, _) -> selector

pub fun main()
  val before-input = observation("input-before", "macos-input-selection",
    "Observed before the change.", "- ABC enabled")
  val before-protection = observation("protection-before", "hitoolbox-protection",
    "Observed before the change.", "- uchg absent")
  val empty = right(open-authority([]), "empty Authority")
  val initial-writes = right(capture(empty, before-input ++ separator ++ before-protection),
                             "standalone Observation capture")
  check(initial-writes.map(write-selector) ==
        ["observations/input-before", "observations/protection-before"],
        "Observation capture plan")

  val initial-entries = initial-writes.map(write-entry)
  val existing = right(open-authority(initial-entries), "open captured Authority")
  check(right(show(existing,
                   ["observations/input-before", "observations/protection-before"]),
              "show captured Observations") == before-input ++ separator ++ before-protection,
        "canonical Observation bytes changed")

  val newline-input = observation("newline-input", "newline-roundtrip",
    "Observed with a final newline.", "- enabled\n")
  val newline-authority = right(open-authority([
    observation-entry("newline-input", newline-input)]), "open newline Authority")
  val newline-shown = right(show(newline-authority, ["observations/newline-input"]),
                            "show newline Observation")
  check(newline-shown == newline-input, "show changed final newline")
  check(right(capture(newline-authority, newline-shown),
              "recapture shown newline Observation").is-empty,
        "shown canonical bytes were not idempotent capture input")

  val after-input = observation("input-after", "macos-input-selection",
    "Read back after the change.", "- ABC absent")
  val after-protection = observation("protection-after", "hitoolbox-protection",
    "Read back after the change.", "- uchg present")
  val edge = transition("remove-abc", ["input-before", "protection-before"],
    "Avoid secure-input fallback to ABC.",
    "Changed the input-source plist and applied uchg.",
    ["input-after", "protection-after"])
  val draft = edge ++ separator ++ before-input ++ separator ++ before-protection ++
              separator ++ after-input ++ separator ++ after-protection
  val additions = right(capture(existing, draft), "multi-Scope Transition capture")
  check(additions.map(write-selector) ==
        ["observations/input-after", "observations/protection-after", "transitions/remove-abc"],
        "capture plan did not write Observations before the Transition")

  val complete = right(open-authority(initial-entries ++ additions.map(write-entry)),
                       "open complete Authority")
  check(authority-selectors(complete) ==
        ["observations/input-after", "observations/input-before",
         "observations/protection-after", "observations/protection-before",
         "transitions/remove-abc"],
        "Authority selectors are not deterministic")
  check(right(show(complete, ["transitions/remove-abc"]), "show Transition") == edge,
        "canonical Transition bytes changed")

  expect-error(capture(existing,
    observation("input-before", "macos-input-selection", "Changed evidence.", "- ABC absent")),
    "append-only record conflict: observations/input-before",
    "conflicting immutable Observation")

  expect-error(capture(existing,
    transition("dangling", ["missing"], "Reason", "Change", ["input-before"])),
    "Transition references a missing Observation: missing",
    "dangling Observation reference")

  expect-error(capture(empty, before-input ++ separator ++ before-input),
    "duplicate record in capture draft: observations/input-before",
    "duplicate draft record")

  expect-error(capture(empty, observation("bad", "scope", "Context", "body\n## State\nforged")),
    "body contains a reserved structural line",
    "reserved body heading")

  [0.char, 9.char, 127.char].foreach(fn(disallowed) {
    expect-error(capture(empty, observation("bad" ++ disallowed.string,
                                           "scope", "Context", "State")),
      "record ID must be nonblank and file-safe",
      "control character in record ID")
  })

  expect-error(open-authority([AuthorityEntry("observations/other", before-input)]),
    "record identity does not match its path: observations/other",
    "record path identity")

  expect-error(open-authority([AuthorityEntry("observations/input-before ", before-input)]),
    "record identity does not match its path: observations/input-before ",
    "non-canonical authority path")

  expect-error(open-authority([AuthorityEntry("observations/input-before",
    observation("input-before ", "macos-input-selection",
                "Observed before the change.", "- ABC enabled"))]),
    "persisted record is not canonical: observations/input-before",
    "non-canonical persisted bytes")

  expect-error(open-authority([
    observation-entry("input-before", before-input),
    observation-entry("input-before", before-input)]),
    "duplicate authority record: observations/input-before",
    "duplicate Authority record")

  expect-error(open-authority([
    AuthorityEntry("transitions/dangling",
      transition("dangling", ["missing"], "Reason", "Change", ["missing"]))]),
    "Transition references a missing Observation: missing",
    "Authority graph closure")

  expect-error(show(existing, ["observations/missing"]),
    "record does not exist: observations/missing",
    "missing show selector")

  println("Macwarden core checks passed")
