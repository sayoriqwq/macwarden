module scopelog

import scopelog/core
import std/num/int32
import std/os/dir
import std/os/env
import std/os/file
import std/os/path
import std/os/process

fun log-path(scope : scope-id) : path
  "scopes" / (scope-id-text(scope) ++ ".md")

fun log-path-in(scopes-directory : path, scope : scope-id) : path
  scopes-directory / log-path(scope).nodir

fun or-throw(result : either<log-error,a>) : exn a
  match result
    Left(err) -> throw(render-error(err))
    Right(value) -> value

fun init-at(scopes-directory : path, scope : string, initial-state-markdown : string) : <fsys,exn> path
  val sid = or-throw(make-scope-id(scope))
  val initial = or-throw(make-state(initial-state-markdown))
  val target = log-path-in(scopes-directory, sid)
  if target.is-file then throw("Scope already exists")
  write-text-file(target, render-scope-log(ScopeLog(sid, initial, [])))
  target

fun append-at(scopes-directory : path, scope : string, reason-markdown : string,
              new-state-markdown : string) : <fsys,exn> path
  val sid = or-throw(make-scope-id(scope))
  val why = or-throw(make-reason(reason-markdown))
  val next = or-throw(make-state(new-state-markdown))
  val target = log-path-in(scopes-directory, sid)
  if !target.is-file then throw("Scope does not exist")
  val existing = read-text-file(target)
  val log = or-throw(parse-scope-log(sid, existing))
  write-text-file(target, render-scope-log(append-log(log, why, next)))
  target

val help =
  "usage: macwarden <command> [options]\n\n" ++
  "Maintain one configured directory of canonical ScopeLogs.\n\n" ++
  "commands:\n" ++
  "  setup [SCOPES_DIR]                  configure the authoritative directory\n" ++
  "  path                                print the configured directory\n" ++
  "  list                                list Scope IDs\n" ++
  "  show <scope>...                     show complete ScopeLogs\n" ++
  "  capture <scope> [options]           initialize or append a ScopeLog\n" ++
  "  init <scope> <state-file>           low-level initial State write\n" ++
  "  append <scope> <reason-file> <state-file>\n" ++
  "                                      low-level Transition append\n\n" ++
  "Run 'macwarden capture --help' for capture inputs."

val capture-help =
  "usage: macwarden capture <scope> --state FILE [--reason FILE] [--before FILE]\n\n" ++
  "Capture explicit Markdown without interpreting it.\n\n" ++
  "options:\n" ++
  "  --state FILE    current State for init, or New State for a transition\n" ++
  "  --reason FILE   nonblank Reason for one transition\n" ++
  "  --before FILE   trustworthy Before State when creating a transition history\n\n" ++
  "A new Scope accepts --state alone, or all three inputs for Before -> After.\n" ++
  "An existing Scope accepts --reason and --state."

fun config-file()
  val root = match get-env-value("XDG_CONFIG_HOME")
    Just(value) ->
      val configured = value.path
      if configured.is-absolute then configured else homedir() / ".config"
    Nothing -> homedir() / ".config"
  root / "macwarden" / "scopes-dir"

fun default-scopes-directory()
  match run-system-read("git rev-parse --show-toplevel")
    Error(_) -> throw("current directory is not in a Git repository; pass SCOPES_DIR to macwarden setup")
    Ok(root) -> root.trim.path / "scopes"

fun setup(directory : maybe<string>)
  val selected = match directory
    Just(value) -> value.realpath
    Nothing -> default-scopes-directory().realpath
  ensure-dir(selected)
  val authority = selected.realpath
  if !authority.is-directory then throw("scopes authority must be a directory")
  write-text-file(config-file(), authority.string)
  println(authority.string)

fun load-authority()
  val config = config-file()
  if !config.is-file then
    throw("Macwarden is not set up; run: macwarden setup [SCOPES_DIR]")
  val configured = read-text-file(config)
  if configured.is-empty then
    throw("Macwarden is not set up; run: macwarden setup [SCOPES_DIR]")
  val authority = configured.path
  if !authority.is-directory then
    throw("configured scopes directory is unavailable; run: macwarden setup [SCOPES_DIR]")
  authority.realpath

fun insert-scope(scope : string, scopes : list<string>) : list<string>
  match scopes
    Nil -> [scope]
    Cons(first, rest) ->
      if scope <= first then Cons(scope, scopes)
      else Cons(first, insert-scope(scope, rest))

fun sort-scopes(scopes : list<string>) : list<string>
  scopes.foldl([], fn(sorted, scope) { insert-scope(scope, sorted) })

fun scope-id-from-path(entry : path) : <fsys> maybe<string>
  if !entry.is-file then Nothing
  else match entry.basename.ends-with(".md")
    Just(stem) ->
      val scope = stem.string
      match make-scope-id(scope)
        Right(_) -> Just(scope)
        Left(_) -> Nothing
    Nothing -> Nothing

fun list-scopes(scopes-directory : path) : <fsys,exn> list<string>
  list-directory(scopes-directory).filter-map(scope-id-from-path).sort-scopes

fun read-scope(scopes-directory : path, scope : string) : <fsys,exn> string
  val sid = or-throw(make-scope-id(scope))
  val target = log-path-in(scopes-directory, sid)
  if !target.is-file then throw("Scope does not exist")
  val markdown = read-text-file(target)
  or-throw(parse-scope-log(sid, markdown))
  markdown

fun show-scopes(scopes-directory : path, scopes : list<string>)
  val logs = scopes.map(fn(scope) { read-scope(scopes-directory, scope) })
  println(logs.join("\n\n"))

type capture-files
  CaptureFiles(scope : string, state-file : string,
               before-file : maybe<string>, reason-file : maybe<string>)

fun parse-capture-options(scope : string, arguments : list<string>,
                          state-file : maybe<string> = Nothing,
                          before-file : maybe<string> = Nothing,
                          reason-file : maybe<string> = Nothing) : exn capture-files
  match arguments
    Nil -> match state-file
      Just(state) -> CaptureFiles(scope, state, before-file, reason-file)
      Nothing -> throw("capture requires --state FILE; run: macwarden capture --help")
    Cons(option, Cons(file, rest)) ->
      if file.starts-with("--").is-just then
        throw(option ++ " requires FILE; run: macwarden capture --help")
      match option
        "--state" ->
          if state-file.is-just then throw("duplicate --state")
          parse-capture-options(scope, rest, Just(file), before-file, reason-file)
        "--before" ->
          if before-file.is-just then throw("duplicate --before")
          parse-capture-options(scope, rest, state-file, Just(file), reason-file)
        "--reason" ->
          if reason-file.is-just then throw("duplicate --reason")
          parse-capture-options(scope, rest, state-file, before-file, Just(file))
        _ -> throw("unsupported capture option: " ++ option ++ "; run: macwarden capture --help")
    Cons(option, Nil) -> throw(option ++ " requires FILE; run: macwarden capture --help")

fun parse-capture(arguments : list<string>) : exn capture-files
  match arguments
    Cons(scope, options) | !scope.starts-with("--").is-just ->
      parse-capture-options(scope, options)
    _ -> throw("capture requires a scope; run: macwarden capture --help")

fun read-optional-file(file : maybe<string>) : <fsys,exn> maybe<string>
  file.map(fn(name) { read-text-file(name.path) })

fun capture-at(scopes-directory : path, scope : string, before-markdown : maybe<string>,
               reason-markdown : maybe<string>, current-markdown : string) : <fsys,exn> (string,path)
  val sid = or-throw(make-scope-id(scope))
  val current = or-throw(make-state(current-markdown))
  val target = log-path-in(scopes-directory, sid)
  if target.is-file then
    match (before-markdown, reason-markdown)
      (Nothing, Just(reason-source)) ->
        val why = or-throw(make-reason(reason-source))
        val existing = read-text-file(target)
        val log = or-throw(parse-scope-log(sid, existing))
        write-text-file(target, render-scope-log(append-log(log, why, current)))
        ("appended", target)
      _ -> throw("existing Scope capture requires one Reason and New State, without Before State")
  else
    match (before-markdown, reason-markdown)
      (Nothing, Nothing) ->
        write-text-file(target, render-scope-log(ScopeLog(sid, current, [])))
        ("initialized", target)
      (Just(before-source), Just(reason-source)) ->
        val before = or-throw(make-state(before-source))
        val why = or-throw(make-reason(reason-source))
        val log = append-log(ScopeLog(sid, before, []), why, current)
        write-text-file(target, render-scope-log(log))
        ("initialized and appended", target)
      _ -> throw("new Scope capture requires current State alone, or Before State, Reason, and New State")

fun run-capture(scopes-directory : path, arguments : list<string>)
  val CaptureFiles(scope, state-file, before-file, reason-file) = parse-capture(arguments)
  val current = read-text-file(state-file.path)
  val before = read-optional-file(before-file)
  val reason = read-optional-file(reason-file)
  val (action, target) = capture-at(scopes-directory, scope, before, reason, current)
  println(action ++ " Scope " ++ scope ++ ": " ++ target.string)

fun dispatch(scopes-directory : path, command : string, arguments : list<string>)
  match command
    "path" ->
      if !arguments.is-empty then throw("path accepts no arguments")
      println(scopes-directory.string)
    "list" ->
      if !arguments.is-empty then throw("list accepts no arguments")
      list-scopes(scopes-directory).foreach(fn(scope) { println(scope) })
    "show" ->
      if arguments.is-empty then throw("show requires at least one scope")
      show-scopes(scopes-directory, arguments)
    "capture" -> run-capture(scopes-directory, arguments)
    "init" -> match arguments
      [scope, state-file] ->
        init-at(scopes-directory, scope, read-text-file(state-file.path))
        ()
      _ -> throw("init requires <scope> <state-file>")
    "append" -> match arguments
      [scope, reason-file, state-file] ->
        append-at(scopes-directory, scope, read-text-file(reason-file.path),
                  read-text-file(state-file.path))
        ()
      _ -> throw("append requires <scope> <reason-file> <state-file>")
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
    Cons("setup", _) -> throw("setup accepts at most one SCOPES_DIR")
    Cons(command, arguments) -> dispatch(load-authority(), command, arguments)

pub fun main()
  with catch fn(exn)
    println("error: " ++ exn.message)
    process-exit(1.int32)
  run()
