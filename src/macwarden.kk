module macwarden

import macwarden/core
import std/num/int32
import std/os/dir
import std/os/env
import std/os/file
import std/os/path
import std/os/process

extern import
  c file "macwarden-inline.c"

extern write-new-file(path : string, content : string) : fsys int32
  c inline "macwarden_write_new_file(#1,#2,kk_context())"

extern remove-file(path : string) : fsys int32
  c inline "macwarden_remove_file(#1,kk_context())"

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

fun legacy-record-paths(root : path) : <fsys,exn> list<path>
  list-directory(root).filter(fn(entry) {
    entry.is-file && entry.basename.ends-with(".md").is-just
  })

fun uses-legacy-layout(root : path) : <fsys,exn> bool
  !observations-directory(root).is-directory ||
  !transitions-directory(root).is-directory ||
  !legacy-record-paths(root).is-empty

fun configured-legacy-authority()
  val config = config-file()
  if !config.is-file then Nothing
  else
    val configured = read-text-file(config)
    if configured.is-empty then Nothing
    else
      val root = configured.path
      if root.is-directory && uses-legacy-layout(root) then Just(root.realpath)
      else Nothing

fun setup(directory : maybe<string>)
  val selected = match directory
    Just(value) -> value.realpath
    Nothing -> match configured-legacy-authority()
      Just(configured) -> configured
      Nothing -> default-authority().realpath
  ensure-dir(selected)
  val authority = selected.realpath
  val legacy = legacy-record-paths(authority)
  legacy.foreach(fn(record) {
    if remove-file(record.string) != 0.int32 then
      throw("unable to clear legacy ScopeLog record: " ++ record.string)
  })
  ensure-authority(authority)
  write-text-file(config-file(), authority.string)
  if !legacy.is-empty then
    println("cleared legacy ScopeLog records: " ++ legacy.length.show)
  println(authority.string)

fun load-root()
  val config = config-file()
  if !config.is-file then
    throw("Macwarden is not set up; run: macwarden setup [AUTHORITY_DIR]")
  val configured = read-text-file(config)
  if configured.is-empty then
    throw("Macwarden is not set up; run: macwarden setup [AUTHORITY_DIR]")
  val authority = configured.path
  if !authority.is-directory then
    throw("configured authority is unavailable; run: macwarden setup [AUTHORITY_DIR]")
  if uses-legacy-layout(authority) then
    throw("configured authority uses an older layout; run macwarden setup again")
  authority.realpath

fun entries-in(directory : path, category : string) : <fsys,exn> list<authority-entry>
  list-directory(directory).filter-map(fn(entry) {
    if !entry.is-file then Nothing
    else match entry.basename.ends-with(".md")
      Just(stem) ->
        Just(AuthorityEntry(category ++ "/" ++ stem.string, read-text-file(entry)))
      Nothing -> Nothing
  })

fun read-authority(root : path) : <fsys,exn> authority
  or-throw(open-authority(
    entries-in(observations-directory(root), "observations") ++
    entries-in(transitions-directory(root), "transitions")))

fun selector-path(root : path, selector : string) : exn path
  match selector.starts-with("observations/")
    Just(id) -> observations-directory(root) / (id.string ++ ".md")
    Nothing -> match selector.starts-with("transitions/")
      Just(id) -> transitions-directory(root) / (id.string ++ ".md")
      Nothing -> throw("invalid record selector")

fun write-plan(root : path, writes : list<planned-write>) : <fsys,exn> ()
  writes.foreach(fn(write) {
    match write
      PlannedWrite(selector, markdown) ->
        val target = selector-path(root, selector)
        if write-new-file(target.string, markdown) != 0.int32 then
          throw("record could not be published without replacement: " ++ selector)
  })

fun run-capture(root : path, draft-file : string)
  val writes = or-throw(capture(read-authority(root), read-text-file(draft-file.path)))
  write-plan(root, writes)
  if writes.is-empty then println("no changes")
  else
    println("captured:")
    writes.foreach(fn(write) {
      match write
        PlannedWrite(selector, _) -> println("  " ++ selector)
    })

fun show-records(root : path, selectors : list<string>)
  println(or-throw(show(read-authority(root), selectors)))

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

fun dispatch(root : path, command : string, arguments : list<string>)
  match command
    "path" ->
      if !arguments.is-empty then throw("path accepts no arguments")
      println(root.string)
    "list" ->
      if !arguments.is-empty then throw("list accepts no arguments")
      authority-selectors(read-authority(root)).foreach(fn(selector) { println(selector) })
    "show" ->
      if arguments.is-empty then throw("show requires at least one record selector")
      show-records(root, arguments)
    "capture" -> match arguments
      [draft-file] -> run-capture(root, draft-file)
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
    Cons(command, arguments) -> dispatch(load-root(), command, arguments)

pub fun main()
  with catch fn(exn)
    println("error: " ++ exn.message)
    process-exit(1.int32)
  run()
