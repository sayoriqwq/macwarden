module tests/scopelog-core

import scopelog/core

fun fail-test(message : string) : exn a
  throw("ScopeLog core check failed: " ++ message)

fun check(condition : bool, message : string) : exn ()
  if !condition then fail-test(message)

fun right(result : either<log-error,a>, message : string) : exn a
  match result
    Left(err) -> fail-test(message ++ ": " ++ render-error(err))
    Right(value) -> value

fun expect-error(result : either<log-error,a>, expected : log-error, message : string) : exn ()
  match result
    Left(actual) -> check(render-error(actual) == render-error(expected), message)
    Right(_) -> fail-test(message ++ ": accepted invalid input")

pub fun main()
  val sid = right(make-scope-id("keyboard"), "scope ID")
  val initial = "### Devices\n\n- Built-in: **enabled**  \n- Note: café and inline `## State`"
  val canonical = "# Scope: keyboard\n\n## State\n\n" ++ initial
  val parsed = right(parse-scope-log(sid, canonical), "canonical parse")
  check(render-scope-log(parsed) == canonical, "canonical parse/render changed bytes")

  val why-source = "Installed a confirmed replacement.\n"
  val next-source = "### Devices\n\n- External: enabled  "
  val why = right(make-reason(why-source), "append Reason")
  val next = right(make-state(next-source), "append State")
  val appended = append-log(parsed, why, next)
  val expected = canonical ++ "\n\n## Transition\n\n" ++ why-source ++
                 "\n\n## State\n\n" ++ next-source
  check(render-scope-log(appended) == expected,
        "append did not preserve prefix or add one Reason/New State edge")

  expect-error(parse-scope-log(sid, canonical ++ "\n\n## Transition\n\nunfinished"),
               Malformed, "malformed topology")
  expect-error(parse-scope-log(right(make-scope-id("other"), "other scope ID"), canonical),
               ScopeMismatch, "Scope mismatch")
  expect-error(make-state(" \n"), BlankState, "blank State")
  expect-error(make-reason("\n"), BlankReason, "blank Reason")
  expect-error(make-state("body\n## State\nforged"), StructuralHeading, "State heading")
  expect-error(make-reason("body\n## Transition\nforged"), StructuralHeading, "Transition heading")
  expect-error(make-state("body\n# Scope: forged"), StructuralHeading, "Scope heading")

  val rollback-reason = "The replacement failed; restore the recorded state."
  val rollback = append-log(parsed,
    right(make-reason(rollback-reason), "rollback Reason"),
    right(make-state(initial), "rollback State"))
  val expected-rollback = canonical ++ "\n\n## Transition\n\n" ++ rollback-reason ++
                          "\n\n## State\n\n" ++ initial
  check(render-scope-log(rollback) == expected-rollback,
        "ordinary append did not preserve rollback payload identity")

  println("ScopeLog core checks passed")
