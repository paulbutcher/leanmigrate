/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
import SQLite
import Leanmigrate
import LeanmigrateSqlite

/-- Dogfoods the SQLite backend against a local dev database: `lake exe migrate-sqlite <cmd>`. -/
public def main (args : List String) : IO UInt32 := do
  let conn ← SQLite.open "dev-sqlite.db"
  runCli { conn, dir := "migrations/sqlite" } args
