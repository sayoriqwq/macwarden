module macwarden/core

pub type domain-error
  InvalidRecordId
  InvalidScopeId
  BlankContext
  BlankState
  BlankReason
  BlankChange
  StructuralHeading
  MalformedRecord
  MalformedReference
  EmptyCapture
  EmptyBefore
  EmptyAfter
  DuplicateRecord(selector : string)
  RecordConflict(selector : string)
  MissingObservation(id : string)

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

type observation-rep
  Observation(id : record-id, scope : scope-id, details : observation-context, state : state)

pub alias observation = observation-rep

type transition-rep
  Transition(id : record-id, before : list<record-id>, reason : reason,
             change : change, after : list<record-id>)

pub alias transition = transition-rep

pub type record
  ObservationRecord(value : observation)
  TransitionRecord(value : transition)

val scope-heading = "\n\n## Scope\n\n"
val context-heading = "\n\n## Context\n\n"
val state-heading = "\n\n## State\n\n"
val before-heading = "\n\n## Before\n\n"
val reason-heading = "\n\n## Reason\n\n"
val change-heading = "\n\n## Change\n\n"
val after-heading = "\n\n## After\n\n"
val record-separator = "\n\n<!-- macwarden:record -->\n\n"

pub fun render-error(err : domain-error) : string
  match err
    InvalidRecordId -> "record ID must be nonblank and file-safe"
    InvalidScopeId -> "scope ID must be nonblank and file-safe"
    BlankContext -> "Context body must be nonblank"
    BlankState -> "State body must be nonblank"
    BlankReason -> "Reason body must be nonblank"
    BlankChange -> "Change body must be nonblank"
    StructuralHeading -> "body contains a reserved structural line"
    MalformedRecord -> "malformed Macwarden record"
    MalformedReference -> "observation references must use '- ID', one per line"
    EmptyCapture -> "capture draft must contain at least one record"
    EmptyBefore -> "Transition Before must contain at least one Observation ID"
    EmptyAfter -> "Transition After must contain at least one Observation ID"
    DuplicateRecord(selector) -> "duplicate record in capture draft: " ++ selector
    RecordConflict(selector) -> "append-only record conflict: " ++ selector
    MissingObservation(id) -> "Transition references a missing Observation: " ++ id

fun file-safe(source : string) : bool
  !source.trim.is-empty && !source.contains("/") && !source.contains("\\") &&
  !source.contains("\n") && !source.contains("\r")

fun make-record-id(source : string) : either<domain-error,record-id>
  val text = source.trim
  if file-safe(text) then Right(RecordId(text)) else Left(InvalidRecordId)

fun make-scope-id(source : string) : either<domain-error,scope-id>
  val text = source.trim
  if file-safe(text) then Right(ScopeId(text)) else Left(InvalidScopeId)

fun structural-line(line : string) : bool
  line == "## Scope" || line == "## Context" || line == "## State" ||
  line == "## Before" || line == "## Reason" || line == "## Change" ||
  line == "## After" || line == "<!-- macwarden:record -->" ||
  line.starts-with("# Observation: ").is-just ||
  line.starts-with("# Transition: ").is-just

fun valid-body(source : string) : bool
  !source.trim.is-empty && !source.split("\n").any(structural-line)

fun make-context(source : string) : either<domain-error,observation-context>
  if source.trim.is-empty then Left(BlankContext)
  elif !valid-body(source) then Left(StructuralHeading)
  else Right(Context(source))

fun make-state(source : string) : either<domain-error,state>
  if source.trim.is-empty then Left(BlankState)
  elif !valid-body(source) then Left(StructuralHeading)
  else Right(State(source))

fun make-reason(source : string) : either<domain-error,reason>
  if source.trim.is-empty then Left(BlankReason)
  elif !valid-body(source) then Left(StructuralHeading)
  else Right(Reason(source))

fun make-change(source : string) : either<domain-error,change>
  if source.trim.is-empty then Left(BlankChange)
  elif !valid-body(source) then Left(StructuralHeading)
  else Right(Change(source))

fun parse-reference-lines(lines : list<string>) : either<domain-error,list<record-id>>
  match lines
    Nil -> Right([])
    Cons(line, rest) ->
      match line.trim.starts-with("- ")
        Nothing -> Left(MalformedReference)
        Just(id-source) ->
          match make-record-id(id-source.string)
            Left(err) -> Left(err)
            Right(id) -> parse-reference-lines(rest).map(fn(ids) { Cons(id, ids) })

fun parse-references(source : string) : either<domain-error,list<record-id>>
  if source.trim.is-empty then Right([])
  else parse-reference-lines(source.trim.split("\n"))

fun parse-observation(markdown : string) : either<domain-error,record>
  match markdown.split(scope-heading)
    [header, rest] ->
      match (header.starts-with("# Observation: "), rest.split(context-heading))
        (Just(id-source), [scope-source, body]) ->
          match body.split(state-heading)
            [context-source, state-source] ->
              match make-record-id(id-source.string)
                Left(err) -> Left(err)
                Right(id) ->
                  match make-scope-id(scope-source)
                    Left(err) -> Left(err)
                    Right(scope) ->
                      match make-context(context-source)
                        Left(err) -> Left(err)
                        Right(details) ->
                          make-state(state-source).map(fn(state) {
                            ObservationRecord(Observation(id, scope, details, state))
                          })
            _ -> Left(MalformedRecord)
        _ -> Left(MalformedRecord)
    _ -> Left(MalformedRecord)

fun parse-transition(markdown : string) : either<domain-error,record>
  match markdown.split(before-heading)
    [header, rest] ->
      match (header.starts-with("# Transition: "), rest.split(reason-heading))
        (Just(id-source), [before-source, edge]) ->
          match edge.split(change-heading)
            [reason-source, tail] ->
              match tail.split(after-heading)
                [change-source, after-source] ->
                  match make-record-id(id-source.string)
                    Left(err) -> Left(err)
                    Right(id) ->
                      match parse-references(before-source)
                        Left(err) -> Left(err)
                        Right(before) ->
                          if before.is-empty then Left(EmptyBefore)
                          else match make-reason(reason-source)
                            Left(err) -> Left(err)
                            Right(reason) ->
                              match make-change(change-source)
                                Left(err) -> Left(err)
                                Right(change) ->
                                  match parse-references(after-source)
                                    Left(err) -> Left(err)
                                    Right(after) ->
                                      if after.is-empty then Left(EmptyAfter)
                                      else Right(TransitionRecord(
                                        Transition(id, before, reason, change, after)))
                _ -> Left(MalformedRecord)
            _ -> Left(MalformedRecord)
        _ -> Left(MalformedRecord)
    _ -> Left(MalformedRecord)

pub fun parse-record(markdown : string) : either<domain-error,record>
  if markdown.starts-with("# Observation: ").is-just then parse-observation(markdown)
  elif markdown.starts-with("# Transition: ").is-just then parse-transition(markdown)
  else Left(MalformedRecord)

fun parse-record-parts(parts : list<string>) : either<domain-error,list<record>>
  match parts
    Nil -> Right([])
    Cons(source, rest) ->
      match parse-record(source)
        Left(err) -> Left(err)
        Right(value) -> parse-record-parts(rest).map(fn(values) { Cons(value, values) })

fun strip-final-newline(source : string) : string
  match source.ends-with("\n")
    Just(body) -> body.string
    Nothing -> source

pub fun parse-records(markdown : string) : either<domain-error,list<record>>
  if markdown.trim.is-empty then Left(EmptyCapture)
  else parse-record-parts(strip-final-newline(markdown).split(record-separator))

fun render-references(ids : list<record-id>) : string
  ids.map(fn(RecordId(id)) { "- " ++ id }).join("\n")

pub fun render-record(value : record) : string
  match value
    ObservationRecord(Observation(RecordId(id), ScopeId(scope),
                                  Context(details), State(state))) ->
      "# Observation: " ++ id ++ scope-heading ++ scope ++
      context-heading ++ details ++ state-heading ++ state
    TransitionRecord(Transition(RecordId(id), before, Reason(reason),
                                Change(change), after)) ->
      "# Transition: " ++ id ++ before-heading ++ render-references(before) ++
      reason-heading ++ reason ++ change-heading ++ change ++
      after-heading ++ render-references(after)

pub fun render-records(records : list<record>) : string
  records.map(render-record).join(record-separator)

pub fun record-selector(value : record) : string
  match value
    ObservationRecord(Observation(RecordId(id), _, _, _)) -> "observations/" ++ id
    TransitionRecord(Transition(RecordId(id), _, _, _, _)) -> "transitions/" ++ id

pub fun validate-selector(source : string) : either<domain-error,string>
  match source.split("/")
    [kind, id-source] | kind == "observations" || kind == "transitions" ->
      make-record-id(id-source).map(fn(RecordId(id)) { kind ++ "/" ++ id })
    _ -> Left(InvalidRecordId)

pub fun is-observation(value : record) : bool
  match value
    ObservationRecord(_) -> True
    TransitionRecord(_) -> False

fun find-record(records : list<record>, selector : string) : maybe<record>
  match records
    Nil -> Nothing
    Cons(first, rest) ->
      if record-selector(first) == selector then Just(first)
      else find-record(rest, selector)

fun check-unique(records : list<record>, selectors : list<string>) : either<domain-error,()>
  match records
    Nil -> Right(())
    Cons(first, rest) ->
      val selector = record-selector(first)
      if selectors.any(fn(existing) { existing == selector })
      then Left(DuplicateRecord(selector))
      else check-unique(rest, Cons(selector, selectors))

fun observation-exists(records : list<record>, wanted : record-id) : bool
  match records
    Nil -> False
    Cons(first, rest) ->
      match (first, wanted)
        (ObservationRecord(Observation(RecordId(actual), _, _, _)), RecordId(expected)) ->
          actual == expected || observation-exists(rest, wanted)
        _ -> observation-exists(rest, wanted)

fun validate-references(records : list<record>, ids : list<record-id>) : either<domain-error,()>
  match ids
    Nil -> Right(())
    Cons(id, rest) ->
      if observation-exists(records, id) then validate-references(records, rest)
      else match id
        RecordId(text) -> Left(MissingObservation(text))

fun validate-transitions(records : list<record>, remaining : list<record>) : either<domain-error,()>
  match remaining
    Nil -> Right(())
    Cons(first, rest) ->
      match first
        ObservationRecord(_) -> validate-transitions(records, rest)
        TransitionRecord(Transition(_, before, _, _, after)) ->
          match validate-references(records, before)
            Left(err) -> Left(err)
            Right(_) ->
              match validate-references(records, after)
                Left(err) -> Left(err)
                Right(_) -> validate-transitions(records, rest)

fun new-records(existing : list<record>, proposed : list<record>) : either<domain-error,list<record>>
  match proposed
    Nil -> Right([])
    Cons(first, rest) ->
      match find-record(existing, record-selector(first))
        Nothing -> new-records(existing, rest).map(fn(values) { Cons(first, values) })
        Just(old) ->
          if render-record(old) == render-record(first) then new-records(existing, rest)
          else Left(RecordConflict(record-selector(first)))

pub fun capture(existing : list<record>, draft : string) : either<domain-error,list<record>>
  match parse-records(draft)
    Left(err) -> Left(err)
    Right(proposed) ->
      match check-unique(proposed, [])
        Left(err) -> Left(err)
        Right(_) ->
          val combined = existing ++ proposed
          match validate-transitions(combined, combined)
            Left(err) -> Left(err)
            Right(_) -> new-records(existing, proposed)
