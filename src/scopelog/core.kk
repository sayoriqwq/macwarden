module scopelog/core

pub type log-error
  InvalidScope
  BlankState
  BlankReason
  StructuralHeading
  Malformed
  ScopeMismatch

type scope-id-rep
  ScopeId(text : string)

pub alias scope-id = scope-id-rep

type state-rep
  State(markdown : string)

pub alias state = state-rep

type reason-rep
  Reason(markdown : string)

pub alias reason = reason-rep

pub type transition
  Transition(why : reason, new-state : state)

pub type scope-log
  ScopeLog(scope : scope-id, initial : state, transitions : list<transition>)

val state-heading = "\n\n## State\n\n"
val transition-heading = "\n\n## Transition\n\n"

pub fun render-error(err : log-error) : string
  match err
    InvalidScope -> "scope must be a nonblank file-safe ID"
    BlankState -> "state body must be nonblank"
    BlankReason -> "reason body must be nonblank"
    StructuralHeading -> "body contains a reserved structural heading"
    Malformed -> "malformed ScopeLog"
    ScopeMismatch -> "Scope mismatch"

pub fun make-scope-id(source : string) : either<log-error,scope-id>
  if source.trim.is-empty || source.contains("/") || source.contains("\\") ||
     source.contains("\n") || source.contains("\r")
  then Left(InvalidScope)
  else Right(ScopeId(source))

pub fun scope-id-text(ScopeId(text) : scope-id) : string
  text

fun structural-line(line : string) : bool
  line == "## State" || line == "## Transition" ||
  line.starts-with("# Scope: ").is-just

fun has-structural-heading(lines : list<string>) : bool
  lines.any(structural-line)

pub fun make-state(markdown : string) : either<log-error,state>
  if markdown.trim.is-empty then Left(BlankState)
  elif has-structural-heading(markdown.split("\n")) then Left(StructuralHeading)
  else Right(State(markdown))

pub fun make-reason(markdown : string) : either<log-error,reason>
  if markdown.trim.is-empty then Left(BlankReason)
  elif has-structural-heading(markdown.split("\n")) then Left(StructuralHeading)
  else Right(Reason(markdown))

fun parse-chain(parts : list<string>) : either<log-error,(state,list<transition>)>
  match parts
    Cons(last, Nil) ->
      if last.contains(transition-heading) then Left(Malformed)
      else make-state(last).map(fn(final-state) { (final-state, []) })
    Cons(section, rest) ->
      match section.split(transition-heading)
        [old, why] ->
          match make-state(old)
            Left(err) -> Left(err)
            Right(old-state) ->
              match make-reason(why)
                Left(err) -> Left(err)
                Right(edge-reason) ->
                  parse-chain(rest).map(fn((next-state, transitions)) {
                    (old-state, Cons(Transition(edge-reason, next-state), transitions))
                  })
        _ -> Left(Malformed)
    Nil -> Left(Malformed)

pub fun parse-scope-log(expected : scope-id, markdown : string) : either<log-error,scope-log>
  match (expected, markdown.split(state-heading))
    (ScopeId(scope), Cons(header, Cons(first, rest))) ->
      if header != "# Scope: " ++ scope then Left(ScopeMismatch)
      else parse-chain(Cons(first, rest)).map(fn((initial, transitions)) {
        ScopeLog(expected, initial, transitions)
      })
    _ -> Left(Malformed)

fun render-transitions(transitions : list<transition>) : string
  match transitions
    Nil -> ""
    Cons(Transition(Reason(why), State(next)), rest) ->
      transition-heading ++ why ++ state-heading ++ next ++ render-transitions(rest)

pub fun render-scope-log(log : scope-log) : string
  match log
    ScopeLog(ScopeId(scope), State(initial), transitions) ->
      "# Scope: " ++ scope ++ state-heading ++ initial ++ render-transitions(transitions)

pub fun append-log(log : scope-log, why : reason, next : state) : scope-log
  match log
    ScopeLog(scope, initial, transitions) ->
      ScopeLog(scope, initial, transitions ++ [Transition(why, next)])
