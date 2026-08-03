/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate.SqlBackend
import Postgres

/-- Unlike the SQLite backend, `exec` here can only run a single SQL statement per call:
leanpostgres executes everything through libpq's `PQexecParams`, which rejects multiple
`;`-separated commands outright rather than running them in sequence. A migration file with
several statements needs splitting into several files. -/
instance : SqlBackend Postgres.Conn where
  exec db sql := do (← Postgres.prepare db sql).exec
  queryText1 db sql := do
    let stmt ← Postgres.prepare db sql
    let mut out := #[]
    while (← stmt.step) do
      out := out.push (← stmt.columnText 0)
    pure out
  withTransaction db action := Postgres.transaction db action
