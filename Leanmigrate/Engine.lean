/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate.SqlBackend
import Leanmigrate.Migration

/-- Creates the bookkeeping table if it doesn't already exist. This SQL is portable across
every backend we support, so it lives here once rather than in each adapter. -/
def ensureMigrationsTable [SqlBackend Conn] (conn : Conn) : IO Unit :=
  SqlBackend.exec conn
    "CREATE TABLE IF NOT EXISTS schema_migrations (id TEXT PRIMARY KEY, applied_at TEXT NOT NULL)"

/-- Ids already recorded as applied, ascending. Ensures the bookkeeping table exists first, so
this is always safe to call on a database no migration has ever touched. -/
def appliedIds [SqlBackend Conn] (conn : Conn) : IO (Array String) := do
  ensureMigrationsTable conn
  SqlBackend.queryText1 conn "SELECT id FROM schema_migrations ORDER BY id ASC"

/-- Migrations on disk not yet recorded as applied, in ascending id order. -/
def pendingMigrations [SqlBackend Conn] (conn : Conn) (all : Array Migration) :
    IO (Array Migration) := do
  let applied ← appliedIds conn
  return all.filter fun m => !applied.contains m.id

/-- Runs `m`'s `up.sql` and records it as applied in one transaction, so a migration that
fails is never left half-applied-and-recorded. `m.id` is always a validated run of digits (see
`Migration`), so interpolating it directly into SQL here is safe. -/
def applyOne [SqlBackend Conn] (conn : Conn) (m : Migration) : IO Unit :=
  SqlBackend.withTransaction conn do
    SqlBackend.exec conn (← IO.FS.readFile m.up)
    SqlBackend.exec conn
      s!"INSERT INTO schema_migrations (id, applied_at) VALUES ('{m.id}', '{← isoTimestamp}')"

/-- Runs `m`'s `down.sql` and removes its bookkeeping row in one transaction. -/
def rollbackOne [SqlBackend Conn] (conn : Conn) (m : Migration) : IO Unit :=
  SqlBackend.withTransaction conn do
    SqlBackend.exec conn (← IO.FS.readFile m.down)
    SqlBackend.exec conn s!"DELETE FROM schema_migrations WHERE id = '{m.id}'"

/-- Applies pending migrations in ascending id order, stopping at (and including) `target?`
if given, else applying all of them. Aborts at the first failure: migrations already committed
before the failure stay applied, and nothing after it runs. -/
def migrateUp [SqlBackend Conn] (conn : Conn) (all : Array Migration)
    (target? : Option String := none) : IO Unit := do
  let todo ← pendingMigrations conn all
  let todo := match target? with
    | none => todo
    | some t => todo.filter (·.id <= t)
  for m in todo do applyOne conn m

/-- Rolls back applied migrations in descending id order. With `target? = some id`, rolls back
everything strictly after `id` (leaving `id` itself applied); with `target? = none`, rolls back
only the single most-recently-applied migration (matching migratus's no-argument `rollback`). -/
def migrateDown [SqlBackend Conn] (conn : Conn) (all : Array Migration)
    (target? : Option String := none) : IO Unit := do
  let applied ← appliedIds conn
  let toRevert := match target? with
    | some t => (applied.filter (· > t)).reverse
    | none => match applied.back? with
      | some id => #[id]
      | none => #[]
  for id in toRevert do
    match all.find? (·.id == id) with
    | some m => rollbackOne conn m
    | none => throw <| IO.userError s!"cannot roll back {id}: no migration files found for it"
