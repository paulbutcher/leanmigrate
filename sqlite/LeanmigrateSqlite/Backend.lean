/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import Leanmigrate.SqlBackend
public import SQLite

namespace LeanmigrateSqlite

/-- How long to wait for another connection to let go of the database before reporting it as
locked. SQLite serialises writers at the file level and, with no timeout set, reports a locked
database immediately, so a second caller running `migrateUp` concurrently would fail instead of
waiting its turn. Five minutes covers a migration slow enough to be worth waiting for, such as
one rewriting a large table. -/
public def busyTimeoutMs : Int32 := 5 * 60 * 1000

/-- The timeout is a property of the connection and persists once set, but the connection
belongs to the caller and reaches us already open, so every operation sets it rather than
assuming an earlier one did. -/
public def withBusyTimeout (db : SQLite) (act : IO α) : IO α := do
  db.busyTimeout busyTimeoutMs
  act

public instance : SqlBackend SQLite where
  exec db sql := withBusyTimeout db (db.exec sql)
  queryText1 db sql := withBusyTimeout db do
    let stmt ← db.prepare sql
    let mut out := #[]
    while (← stmt.step) do
      out := out.push (← stmt.columnText 0)
    pure out
  withTransaction db action := withBusyTimeout db (db.transaction action)

end LeanmigrateSqlite
