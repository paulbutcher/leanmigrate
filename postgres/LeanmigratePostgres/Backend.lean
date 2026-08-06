/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate.SqlBackend
import Postgres

instance : SqlBackend Postgres.Conn where
  exec db sql := Postgres.execScript db sql
  -- Postgres reports `CREATE TABLE IF NOT EXISTS` on an existing relation as a NOTICE, which
  -- the server would otherwise send to the client on every run, not just the first. `SET
  -- LOCAL` scopes the suppression to this one statement (and, since `execScript` sends both
  -- as a single multi-statement query, to the implicit transaction wrapping them) rather than
  -- the whole session, so notices from migrations the caller supplied still come through.
  execQuiet db sql := Postgres.execScript db s!"SET LOCAL client_min_messages = WARNING; {sql}"
  queryText1 db sql := do
    let stmt ← Postgres.prepare db sql
    let mut out := #[]
    while (← stmt.step) do
      out := out.push (← stmt.columnText 0)
    pure out
  withTransaction db action := Postgres.transaction db action
