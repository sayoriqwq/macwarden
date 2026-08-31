module macwarden

import macwarden/core
import std/num/int32
import std/os/dir
import std/os/env
import std/os/file
import std/os/path
import std/os/process

fun or-throw(result : either<domain-error,a>) : exn a
  match result
    Left(err) -> throw(render-error(err))
    Right(value) -> value

fun config-file()
  val root = match get-env-value("XDG_CONFIG_HOME")
    Just(value) ->
      val configured = value.path
      if configured.is-absolute then configured else homedir() / ".config"
    Nothing -> homedir() / ".config"
  root / "macwarden" / "scopes-dir"

fun default-authority()
  match run-system-read("git rev-parse --show-toplevel")
    Error(_) -> throw("current directory is not in a Git repository; pass AUTHORITY_DIR to macwarden setup")
    Ok(root) -> root.trim.path / "authority"

fun observations-directory(authority : path) : path
  authority / "observations"

fun transitions-directory(authority : path) : path
  authority / "transitions"

fun ensure-authority(authority : path) : <fsys,exn> ()
  ensure-dir(authority)
  ensure-dir(observations-directory(authority))
  ensure-dir(transitions-directory(authority))

fun setup(directory : maybe<string>)
  val selected = match directory
    Just(value) -> value.realpath
    Nothing -> default-authority().realpath
  ensure-authority(selected)
  val authority = selected.realpath
  write-text-file(config-file(), authority.string)
  println(authority.string)

fun load-authority()
  val config = config-file()
  if !config.is-file then
    throw("Macwarden is not set up; run: macwarden setup [AUTHORITY_DIR]")
  val configured = read-text-file(config)
  if configured.is-empty then
    throw("Macwarden is not set up; run: macwarden setup [AUTHORITY_DIR]")
  val authority = configured.path
  if !authority.is-directory then
    throw("configured authority is unavailable; run: macwarden setup [AUTHORITY_DIR]")
  if !observations-directory(authority).is-directory ||
     !transitions-directory(authority).is-directory then
    throw("configured authority uses an older layout; run macwarden setup again")
  authority.realpath

fun insert-selector(selector : string, selectors : list<string>) : list<string>
  match selectors
    Nil -> [selector]
    Cons(first, rest) ->
      if selector <= first then Cons(selector, selectors)
      else Cons(first, insert-selector(selector, rest))

fun sort-selectors(selectors : list<string>) : list<string>
  selectors.foldl([], fn(sorted, selector) { insert-selector(selector, sorted) })

fun selectors-in(directory : path, category : string) : <fsys,exn> list<string>
  list-directory(directory).filter-map(fn(entry) {
    if !entry.is-file then Nothing
    else match entry.basename.ends-with(".md")
      Just(stem) ->
        val selector = category ++ "/" ++ stem.string
        match validate-selector(selector)
          Right(value) -> Just(value)
          Left(_) -> Nothing
      Nothing -> Nothing
  })

fun list-selectors(authority : path) : <fsys,exn> list<string>
  (selectors-in(observations-directory(authority), "observations") ++
   selectors-in(transitions-directory(authority), "transitions")).sort-selectors

fun selector-path(authority : path, source : string) : exn (string,path)
  val selector = or-throw(validate-selector(source))
  match selector.starts-with("observations/")
    Just(id) -> (selector, observations-directory(authority) / (id.string ++ ".md"))
    Nothing -> match selector.starts-with("transitions/")
      Just(id) -> (selector, transitions-directory(authority) / (id.string ++ ".md"))
      Nothing -> throw("invalid record selector")

fun read-record(authority : path, source : string) : <fsys,exn> record
  val (selector, target) = selector-path(authority, source)
  if !target.is-file then throw("record does not exist: " ++ selector)
  val value = or-throw(parse-record(read-text-file(target)))
  if record-selector(value) != selector then
    throw("record identity does not match its path: " ++ selector)
  value

fun load-records(authority : path) : <fsys,exn> list<record>
  list-selectors(authority).map(fn(selector) { read-record(authority, selector) })

fun write-record(authority : path, value : record) : <fsys,exn> ()
  val (selector, target) = selector-path(authority, record-selector(value))
  if target.is-file then throw("record appeared while capturing: " ++ selector)
  write-text-file(target, render-record(value))

fun write-capture(authority : path, records : list<record>) : <fsys,exn> ()
  records.filter(is-observation).foreach(fn(value) { write-record(authority, value) })
  records.filter(fn(value) { !is-observation(value) }).foreach(fn(value) {
    write-record(authority, value)
  })

fun run-capture(authority : path, draft-file : string)
  val existing = load-records(authority)
  val additions = or-throw(capture(existing, read-text-file(draft-file.path)))
  write-capture(authority, additions)
  if additions.is-empty then println("no changes")
  else
    println("captured:")
    additions.foreach(fn(value) { println("  " ++ record-selector(value)) })

fun show-records(authority : path, selectors : list<string>)
  val records = selectors.map(fn(selector) { read-record(authority, selector) })
  println(render-records(records))

val help =
  "usage: macwarden <command> [options]\n\n" ++
  "Maintain one configured directory of immutable Observations and Transitions.\n\n" ++
  "commands:\n" ++
  "  setup [AUTHORITY_DIR]              configure the authoritative directory\n" ++
  "  path                               print the configured directory\n" ++
  "  list                               list record selectors\n" ++
  "  show <selector>...                 show canonical records\n" ++
  "  capture <draft.md>                 validate and append a record draft"

val capture-help =
  "usage: macwarden capture <draft.md>\n\n" ++
  "The draft is one or more canonical Observation or Transition records.\n" ++
  "All records are validated before immutable Observations are written, then Transitions."

fun dispatch(authority : path, command : string, arguments : list<string>)
  match command
    "path" ->
      if !arguments.is-empty then throw("path accepts no arguments")
      println(authority.string)
    "list" ->
      if !arguments.is-empty then throw("list accepts no arguments")
      list-selectors(authority).foreach(fn(selector) { println(selector) })
    "show" ->
      if arguments.is-empty then throw("show requires at least one record selector")
      show-records(authority, arguments)
    "capture" -> match arguments
      [draft-file] -> run-capture(authority, draft-file)
      _ -> throw("capture requires exactly one draft file; run: macwarden capture --help")
    _ -> throw("unknown command: " ++ command ++ "; run: macwarden --help")

extern process-exit(code : int32) : io ()
  c "exit"

fun run()
  match get-args()
    [] -> println(help)
    ["--help"] -> println(help)
    ["-h"] -> println(help)
    ["capture", "--help"] -> println(capture-help)
    ["capture", "-h"] -> println(capture-help)
    ["setup", "--help"] -> println(help)
    ["setup", "-h"] -> println(help)
    ["setup"] -> setup(Nothing)
    ["setup", directory] -> setup(Just(directory))
    Cons("setup", _) -> throw("setup accepts at most one AUTHORITY_DIR")
    Cons(command, arguments) -> dispatch(load-authority(), command, arguments)

pub fun main()
  with catch fn(exn)
    println("error: " ++ exn.message)
    process-exit(1.int32)
  run()
