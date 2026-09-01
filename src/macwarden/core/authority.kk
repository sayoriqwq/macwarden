module macwarden/core/authority

import macwarden/core/error
import macwarden/core/record
import macwarden/core/result
import std/core/undiv

pub type authority-entry
  AuthorityEntry(selector : string, markdown : string)

pub type legacy-authority-entry
  LegacyAuthorityEntry(scope : string, markdown : string)

pub type planned-write
  PlannedWrite(selector : string, markdown : string)

type authority-rep
  Authority(records : list<record>)

pub alias authority = authority-rep

fun insert-entry(entry : authority-entry, entries : list<authority-entry>)
                 : list<authority-entry>
  match (entry, entries)
    (_, Nil) -> [entry]
    (AuthorityEntry(selector, _), Cons(first, rest)) ->
      match first
        AuthorityEntry(first-selector, _) ->
          if selector <= first-selector then Cons(entry, entries)
          else Cons(first, insert-entry(entry, pretend-decreasing(rest)))

fun sort-entries(entries : list<authority-entry>) : list<authority-entry>
  entries.foldl([], fn(sorted, entry) { insert-entry(entry, sorted) })

fun parse-entry(entry : authority-entry) : abort<domain-error> record
  match entry
    AuthorityEntry(source, markdown) ->
      val selector = require(validate-selector(source))
      ensure(source == selector, RecordIdentityMismatch(source))
      val value = require(parse-record(markdown))
      ensure(record-selector(value) == selector, RecordIdentityMismatch(selector))
      value

fun validate-unique(records : list<record>, duplicate : string -> domain-error)
                    : abort<domain-error> ()
  records.foldl([], fn(selectors, value) {
    val selector = record-selector(value)
    ensure(!selectors.any(fn(existing) { existing == selector }), duplicate(selector))
    Cons(selector, selectors)
  })
  ()

fun observation-exists(records : list<record>, id : string) : bool
  val selector = "observations/" ++ id
  records.any(fn(value) { is-observation(value) && record-selector(value) == selector })

fun validate-graph(records : list<record>) : abort<domain-error> ()
  records.foreach(fn(value) {
    reference-ids(value).foreach(fn(id) {
      ensure(observation-exists(records, id), MissingObservation(id))
    })
  })

pub fun open-authority(entries : list<authority-entry>) : either<domain-error,authority>
  run-result fn()
    val records = sort-entries(entries).map(parse-entry)
    validate-unique(records, DuplicateAuthorityRecord)
    validate-graph(records)
    Authority(records)

pub fun authority-selectors(source : authority) : list<string>
  match source
    Authority(records) -> records.map(record-selector)

fun find-record(records : list<record>, selector : string) : maybe<record>
  records.find(fn(value) { record-selector(value) == selector })

pub fun show(source : authority, wanted : list<string>) : either<domain-error,string>
  run-result fn()
    val Authority(records) = source
    wanted.map(fn(raw-selector) {
      val selector = require(validate-selector(raw-selector))
      require-maybe(find-record(records, selector), MissingRecord(selector))
    }).render-records

fun select-additions(existing : list<record>, proposed : list<record>)
                     : abort<domain-error> list<record>
  proposed.filter-map(fn(value) {
    val selector = record-selector(value)
    match find-record(existing, selector)
      Nothing -> Just(value)
      Just(old) ->
        if render-record(old) == render-record(value) then Nothing
        else abort(RecordConflict(selector))
  })

fun plan-writes(records : list<record>) : list<planned-write>
  val (observations, transitions) = records.partition(is-observation)
  (observations ++ transitions).map(fn(value) {
    PlannedWrite(record-selector(value), render-record(value))
  })

val legacy-state-heading = "\n\n## State\n\n"
val legacy-transition-heading = "\n\n## Transition\n\n"

fun legacy-observation-id(scope : string, index : int) : string
  scope ++ "-legacy-observation-" ++ (index + 1).show

fun legacy-transition-id(scope : string, index : int) : string
  scope ++ "-legacy-transition-" ++ (index + 1).show

fun legacy-observation(scope : string, index : int, state : string)
                       : abort<domain-error> record
  val markdown =
    "# Observation: " ++ legacy-observation-id(scope, index) ++
    "\n\n## Scope\n\n" ++ scope ++
    "\n\n## Context\n\nMigrated from legacy ScopeLog " ++ scope ++
    ".md; original observation context was not recorded." ++
    "\n\n## State\n\n" ++ state
  val value = require(parse-record(markdown))
  ensure(render-record(value) == markdown, InvalidScopeId)
  value

fun legacy-transition(scope : string, index : int, reason : string)
                      : abort<domain-error> record
  require(parse-record(
    "# Transition: " ++ legacy-transition-id(scope, index) ++
    "\n\n## Before\n\n- " ++ legacy-observation-id(scope, index) ++
    "\n\n## Reason\n\n" ++ reason ++
    "\n\n## Change\n\nMigrated from legacy ScopeLog; the original format did not record Change separately." ++
    "\n\n## After\n\n- " ++ legacy-observation-id(scope, index + 1)))

fun parse-legacy-chain(scope : string, parts : list<string>, index : int)
                       : abort<domain-error> list<record>
  match parts
    Cons(last, Nil) -> [legacy-observation(scope, index, last)]
    Cons(section, rest) -> match section.split(legacy-transition-heading)
      [state, reason] ->
        Cons(legacy-observation(scope, index, state),
          Cons(legacy-transition(scope, index, reason),
               parse-legacy-chain(scope, rest, index + 1)))
      _ -> abort(MalformedLegacyScopeLog(scope))
    Nil -> abort(MalformedLegacyScopeLog(scope))

fun parse-legacy-entry(entry : legacy-authority-entry)
                       : abort<domain-error> list<record>
  match entry
    LegacyAuthorityEntry(scope, markdown) -> match markdown.split(legacy-state-heading)
      Cons(header, Cons(first, rest)) ->
        ensure(header == "# Scope: " ++ scope, LegacyScopeMismatch(scope))
        parse-legacy-chain(scope, Cons(first, rest), 0)
      _ -> abort(MalformedLegacyScopeLog(scope))

pub fun upgrade-legacy(source : authority, entries : list<legacy-authority-entry>)
                       : either<domain-error,list<planned-write>>
  run-result fn()
    val Authority(existing) = source
    val proposed = entries.flatmap(parse-legacy-entry)
    validate-unique(proposed, DuplicateRecord)
    validate-graph(existing ++ proposed)
    plan-writes(select-additions(existing, proposed))

pub fun capture(source : authority, draft : string)
                : either<domain-error,list<planned-write>>
  run-result fn()
    val Authority(existing) = source
    val proposed = require(parse-records(draft))
    validate-unique(proposed, DuplicateRecord)
    validate-graph(existing ++ proposed)
    plan-writes(select-additions(existing, proposed))
