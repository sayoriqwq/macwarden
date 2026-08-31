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

pub fun main()
  val before-input = observation("input-before", "macos-input-selection",
    "Observed before the change.", "- ABC enabled")
  val before-protection = observation("protection-before", "hitoolbox-protection",
    "Observed before the change.", "- uchg absent")
  val existing = right(capture([], before-input ++ separator ++ before-protection),
                       "standalone Observation capture")
  check(render-records(existing) == before-input ++ separator ++ before-protection,
        "Observation parse/render changed canonical bytes")

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
  check(additions.map(record-selector) ==
        ["transitions/remove-abc", "observations/input-after", "observations/protection-after"],
        "capture did not reuse Before Observations or retain all After records")

  expect-error(capture(existing,
    observation("input-before", "macos-input-selection", "Changed evidence.", "- ABC absent")),
    "append-only record conflict: observations/input-before",
    "conflicting immutable Observation")

  expect-error(capture(existing,
    transition("dangling", ["missing"], "Reason", "Change", ["input-before"])),
    "Transition references a missing Observation: missing",
    "dangling Observation reference")

  expect-error(capture([], before-input ++ separator ++ before-input),
    "duplicate record in capture draft: observations/input-before",
    "duplicate draft record")

  expect-error(capture([], observation("bad", "scope", "Context", "body\n## State\nforged")),
    "body contains a reserved structural line",
    "reserved body heading")

  println("Macwarden core checks passed")
