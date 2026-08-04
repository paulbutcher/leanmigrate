/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate.SqlBackend
import Postgres

instance : SqlBackend Postgres.Conn where
  exec db sql := Postgres.execScript db sql
  queryText1 db sql := do
    let stmt ← Postgres.prepare db sql
    let mut out := #[]
    while (← stmt.step) do
      out := out.push (← stmt.columnText 0)
    pure out
  withTransaction db action := Postgres.transaction db action
