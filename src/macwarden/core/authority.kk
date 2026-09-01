module macwarden/core/authority

import macwarden/core/error
import macwarden/core/record
import std/core/undiv

effect abort<x>
  final ctl abort(error : x) : a

fun run-result(action : () -> <abort<x>|e> a) : e either<x,a>
  handle action
    return(value) Right(value)
    final ctl abort(error) Left(error)

fun require(value : either<x,a>) : abort<x> a
  match value
    Left(error) -> abort(error)
    Right(result) -> result

fun require-maybe(value : maybe<a>, error : x) : abort<x> a
  match value
    Nothing -> abort(error)
    Just(result) -> result

fun ensure(condition : bool, error : x) : abort<x> ()
  if !condition then abort(error)

pub type authority-entry
  AuthorityEntry(selector : string, markdown : string)

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
      ensure(render-record(value) == markdown, NonCanonicalRecord(selector))
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

pub fun capture(source : authority, draft : string)
                : either<domain-error,list<planned-write>>
  run-result fn()
    val Authority(existing) = source
    val proposed = require(parse-records(draft))
    validate-unique(proposed, DuplicateRecord)
    validate-graph(existing ++ proposed)
    plan-writes(select-additions(existing, proposed))
