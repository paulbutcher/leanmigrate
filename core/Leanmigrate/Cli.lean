/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import Leanmigrate.Config
public import Leanmigrate.Engine

private def usage : String :=
  "usage: <command> [args]\n" ++
  "commands:\n" ++
  "  create <name>              create a new migration\n" ++
  "  migrate|up [<id>]          apply pending migrations, optionally only up to <id>\n" ++
  "  rollback|down [<id>|<n>]   roll back migrations (default: the most recent one)\n" ++
  "  pending|status             list migrations not yet applied"

private def isTimestampId (s : String) : Bool :=
  s.length == 14 && s.all Char.isDigit

/-- `arg?` disambiguates as: nothing (roll back the latest), a 14-digit migration id (roll
back everything after it), or a bare count (roll back that many, most-recent-first). -/
private def runRollback [SqlBackend Conn] (conn : Conn) (all : Array Migration)
    (arg? : Option String) : IO Unit := do
  match arg? with
  | none => migrateDown conn all none
  | some arg =>
    if isTimestampId arg then
      migrateDown conn all (some arg)
    else match arg.toNat? with
      | some n => for _ in [0:n] do migrateDown conn all none
      | none =>
        throw <| IO.userError s!"rollback: {arg.quote} is neither a migration id nor a count"

/-- Parses `args` and runs the corresponding command against `cfg`, returning a process exit
code. This is the one place an `IO.Error` is caught; everything below lets errors propagate,
aborting the run. -/
public def runCli [SqlBackend Conn] (cfg : Config Conn) (args : List String) : IO UInt32 := do
  try
    match args with
    | ["create", name] =>
      let m ← createMigration cfg.dir name
      IO.println s!"created {m.up} and {m.down}"
      return 0
    | "migrate" :: rest | "up" :: rest =>
      let all ← discoverMigrations cfg.dir
      migrateUp cfg.conn all rest.head?
      return 0
    | "rollback" :: rest | "down" :: rest =>
      let all ← discoverMigrations cfg.dir
      runRollback cfg.conn all rest.head?
      return 0
    | ["pending"] | ["status"] =>
      let all ← discoverMigrations cfg.dir
      let todo ← pendingMigrations cfg.conn all
      if todo.isEmpty then
        IO.println "up to date"
      else
        for m in todo do IO.println s!"{m.id}_{m.name}"
      return 0
    | _ =>
      IO.eprintln usage
      return 1
  catch e =>
    IO.eprintln s!"error: {e}"
    return 1
