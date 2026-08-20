/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import Leanmigrate.SqlBackend
public import SQLite

public instance : SqlBackend SQLite where
  exec db sql := db.exec sql
  queryText1 db sql := do
    let stmt ← db.prepare sql
    let mut out := #[]
    while (← stmt.step) do
      out := out.push (← stmt.columnText 0)
    pure out
  withTransaction db action := db.transaction action
