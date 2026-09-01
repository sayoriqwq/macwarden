module macwarden/core/record

import macwarden/core/error
import macwarden/core/result

type record-kind
  ObservationKind
  TransitionKind

type section
  ScopeSection
  ContextSection
  StateSection
  BeforeSection
  ReasonSection
  ChangeSection
  AfterSection

type record-id-rep
  RecordId(text : string)

pub alias record-id = record-id-rep

type scope-id-rep
  ScopeId(text : string)

pub alias scope-id = scope-id-rep

type observation-context-rep
  Context(markdown : string)

pub alias observation-context = observation-context-rep

type state-rep
  State(markdown : string)

pub alias state = state-rep

type reason-rep
  Reason(markdown : string)

pub alias reason = reason-rep

type change-rep
  Change(markdown : string)

pub alias change = change-rep

type references
  References(first : record-id, rest : list<record-id>)

type observation-rep
  Observation(id : record-id, scope : scope-id, details : observation-context, state : state)

pub alias observation = observation-rep

type transition-rep
  Transition(id : record-id, before : references, reason : reason,
             change : change, after : references)

pub alias transition = transition-rep

pub type record
  ObservationRecord(value : observation)
  TransitionRecord(value : transition)

val sections = [ScopeSection, ContextSection, StateSection, BeforeSection,
                ReasonSection, ChangeSection, AfterSection]
val kinds = [ObservationKind, TransitionKind]
val record-separator = "\n\n<!-- macwarden:record -->\n\n"

fun section-name(value : section) : string
  match value
    ScopeSection -> "Scope"
    ContextSection -> "Context"
    StateSection -> "State"
    BeforeSection -> "Before"
    ReasonSection -> "Reason"
    ChangeSection -> "Change"
    AfterSection -> "After"

fun section-line(value : section) : string
  "## " ++ section-name(value)

fun section-heading(value : section) : string
  "\n\n" ++ section-line(value) ++ "\n\n"

fun render-section(value : section, body : string) : string
  section-heading(value) ++ body

fun kind-name(value : record-kind) : string
  match value
    ObservationKind -> "Observation"
    TransitionKind -> "Transition"

fun kind-header(value : record-kind) : string
  "# " ++ kind-name(value) ++ ": "

fun kind-category(value : record-kind) : string
  match value
    ObservationKind -> "observations"
    TransitionKind -> "transitions"

fun file-safe(source : string) : bool
  !source.trim.is-empty && !source.contains("/") && !source.contains("\\") &&
  !source.list.any(fn(c) { c.is-control || c == '\x7F' })

fun make-record-id(source : string) : abort<domain-error> record-id
  ensure(file-safe(source), InvalidRecordId)
  RecordId(source.trim)

fun make-scope-id(source : string) : abort<domain-error> scope-id
  ensure(file-safe(source), InvalidScopeId)
  ScopeId(source.trim)

fun structural-line(line : string) : bool
  sections.any(fn(value) { line == section-line(value) }) ||
  kinds.any(fn(value) { line.starts-with(kind-header(value)).is-just }) ||
  line == "<!-- macwarden:record -->"

fun make-body(source : string, blank : domain-error,
              wrap : string -> a) : abort<domain-error> a
  ensure(!source.trim.is-empty, blank)
  ensure(!source.split("\n").any(structural-line), StructuralHeading)
  wrap(source)

fun make-context(source : string) : abort<domain-error> observation-context
  make-body(source, BlankContext, Context)

fun make-state(source : string) : abort<domain-error> state
  make-body(source, BlankState, State)

fun make-reason(source : string) : abort<domain-error> reason
  make-body(source, BlankReason, Reason)

fun make-change(source : string) : abort<domain-error> change
  make-body(source, BlankChange, Change)

fun cut(source : string, marker : string) : abort<domain-error> (string,string)
  match source.split(marker)
    [left, right] -> (left, right)
    _ -> abort(MalformedRecord)

fun cut-section(source : string, value : section) : abort<domain-error> (string,string)
  cut(source, section-heading(value))

fun after-prefix(source : string, pre : string) : abort<domain-error> string
  require-maybe(source.starts-with(pre), MalformedRecord).string

fun parse-header(source : string, kind : record-kind) : abort<domain-error> record-id
  make-record-id(after-prefix(source, kind-header(kind)))

fun parse-reference-list(source : string) : abort<domain-error> list<record-id>
  if source.trim.is-empty then []
  else source.trim.split("\n").map(fn(line) {
    val id-source = require-maybe(line.trim.starts-with("- "), MalformedReference)
    make-record-id(id-source.string)
  })

fun make-references(ids : list<record-id>, empty : domain-error)
                    : abort<domain-error> references
  match ids
    Nil -> abort(empty)
    Cons(first, rest) -> References(first, rest)

fun parse-references(source : string, empty : domain-error)
                     : abort<domain-error> references
  make-references(parse-reference-list(source), empty)

fun references-list(value : references) : list<record-id>
  match value
    References(first, rest) -> Cons(first, rest)

fun parse-observation(markdown : string) : abort<domain-error> record
  val (header, rest) = cut-section(markdown, ScopeSection)
  val (scope-source, body) = cut-section(rest, ContextSection)
  val (context-source, state-source) = cut-section(body, StateSection)
  ObservationRecord(Observation(
    parse-header(header, ObservationKind),
    make-scope-id(scope-source),
    make-context(context-source),
    make-state(state-source)))

fun parse-transition(markdown : string) : abort<domain-error> record
  val (header, rest) = cut-section(markdown, BeforeSection)
  val (before-source, edge) = cut-section(rest, ReasonSection)
  val (reason-source, tail) = cut-section(edge, ChangeSection)
  val (change-source, after-source) = cut-section(tail, AfterSection)
  TransitionRecord(Transition(
    parse-header(header, TransitionKind),
    parse-references(before-source, EmptyBefore),
    make-reason(reason-source),
    make-change(change-source),
    parse-references(after-source, EmptyAfter)))

fun parse-kind(markdown : string) : abort<domain-error> record-kind
  if markdown.starts-with(kind-header(ObservationKind)).is-just then ObservationKind
  elif markdown.starts-with(kind-header(TransitionKind)).is-just then TransitionKind
  else abort(MalformedRecord)

fun parse-one(markdown : string) : abort<domain-error> record
  match parse-kind(markdown)
    ObservationKind -> parse-observation(markdown)
    TransitionKind -> parse-transition(markdown)

pub fun parse-record(markdown : string) : either<domain-error,record>
  run-result fn() parse-one(markdown)

fun strip-final-newline(source : string) : string
  match source.ends-with("\n")
    Just(body) -> body.string
    Nothing -> source

fun parse-many(markdown : string) : abort<domain-error> list<record>
  ensure(!markdown.trim.is-empty, EmptyCapture)
  strip-final-newline(markdown).split(record-separator).map(parse-one)

pub fun parse-records(markdown : string) : either<domain-error,list<record>>
  run-result fn() parse-many(markdown)

fun render-references(value : references) : string
  references-list(value).map(fn(RecordId(id)) { "- " ++ id }).join("\n")

fun record-kind-of(value : record) : record-kind
  match value
    ObservationRecord(_) -> ObservationKind
    TransitionRecord(_) -> TransitionKind

fun record-id-of(value : record) : record-id
  match value
    ObservationRecord(Observation(id, _, _, _)) -> id
    TransitionRecord(Transition(id, _, _, _, _)) -> id

pub fun render-record(value : record) : string
  match value
    ObservationRecord(Observation(RecordId(id), ScopeId(scope),
                                  Context(details), State(state))) ->
      kind-header(ObservationKind) ++ id ++
      render-section(ScopeSection, scope) ++
      render-section(ContextSection, details) ++
      render-section(StateSection, state)
    TransitionRecord(Transition(RecordId(id), before, Reason(reason),
                                Change(change), after)) ->
      kind-header(TransitionKind) ++ id ++
      render-section(BeforeSection, render-references(before)) ++
      render-section(ReasonSection, reason) ++
      render-section(ChangeSection, change) ++
      render-section(AfterSection, render-references(after))

pub fun render-records(records : list<record>) : string
  records.map(render-record).join(record-separator)

pub fun record-selector(value : record) : string
  val RecordId(id) = record-id-of(value)
  kind-category(record-kind-of(value)) ++ "/" ++ id

pub fun validate-selector(source : string) : either<domain-error,string>
  run-result fn()
    match source.split("/")
      [category, id-source] ->
        ensure(kinds.any(fn(kind) { category == kind-category(kind) }), InvalidRecordId)
        val RecordId(id) = make-record-id(id-source)
        category ++ "/" ++ id
      _ -> abort(InvalidRecordId)

pub fun is-observation(value : record) : bool
  match record-kind-of(value)
    ObservationKind -> True
    TransitionKind -> False

pub fun reference-ids(value : record) : list<string>
  match value
    ObservationRecord(_) -> []
    TransitionRecord(Transition(_, before, _, _, after)) ->
      (references-list(before) ++ references-list(after)).map(fn(RecordId(id)) { id })
