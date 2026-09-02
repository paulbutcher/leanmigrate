/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import Leanmigrate.SqlBackend
public import Leanmigrate.Migration

/-- Creates the bookkeeping table if it doesn't already exist. This SQL is portable across
every backend we support, so it lives here once rather than in each adapter.

Retried once, because Postgres's `CREATE TABLE IF NOT EXISTS` is not safe against a concurrent
create of the same table: the loser waits for the winner and then fails on the system
catalogue's unique index rather than finding the table already there. By the time it retries,
the winner has committed and there is nothing left to do. -/
public def ensureMigrationsTable [SqlBackend Conn] (conn : Conn) : IO Unit := do
  let create : IO Unit := SqlBackend.execQuiet conn
    "CREATE TABLE IF NOT EXISTS schema_migrations (id TEXT PRIMARY KEY, applied_at TEXT NOT NULL)"
  try
    create
  catch _ =>
    create

/-- Ids already recorded as applied, ascending. Ensures the bookkeeping table exists first, so
this is always safe to call on a database no migration has ever touched. -/
public def appliedIds [SqlBackend Conn] (conn : Conn) : IO (Array String) := do
  ensureMigrationsTable conn
  SqlBackend.queryText1 conn "SELECT id FROM schema_migrations ORDER BY id ASC"

/-- Migrations on disk not yet recorded as applied, in ascending id order. -/
public def pendingMigrations [SqlBackend Conn] (conn : Conn) (all : Array Migration) :
    IO (Array Migration) := do
  let applied ← appliedIds conn
  return all.filter fun m => !applied.contains m.id

/-- Records `m` as applied and runs its `up.sql` in one transaction, so a migration that fails
is never left half-applied-and-recorded. The bookkeeping row goes in first, and that order
matters: `schema_migrations.id` is the primary key, so the insert doubles as a claim on `m`,
and a second caller inserting the same id waits for this transaction and then fails, having run
none of `m`'s own SQL. It also makes `applied_at` the moment the migration started. `m.id` is
always a validated run of digits (see `Migration`), so interpolating it directly into SQL here
is safe. -/
public def applyOne [SqlBackend Conn] (conn : Conn) (m : Migration) : IO Unit :=
  SqlBackend.withTransaction conn do
    SqlBackend.exec conn
      s!"INSERT INTO schema_migrations (id, applied_at) VALUES ('{m.id}', '{← isoTimestamp}')"
    SqlBackend.exec conn (← IO.FS.readFile m.up)

/-- Runs `m`'s `down.sql` and removes its bookkeeping row in one transaction. -/
public def rollbackOne [SqlBackend Conn] (conn : Conn) (m : Migration) : IO Unit :=
  SqlBackend.withTransaction conn do
    SqlBackend.exec conn (← IO.FS.readFile m.down)
    SqlBackend.exec conn s!"DELETE FROM schema_migrations WHERE id = '{m.id}'"

/-- Applies pending migrations in ascending id order, stopping at (and including) `target?`
if given, else applying all of them. Aborts at the first failure: migrations already committed
before the failure stay applied, and nothing after it runs.

Safe to run concurrently against one database: `applyOne` claims each migration before running
it, so concurrent callers between them apply every pending migration exactly once, and one that
loses a race waits for the winner and then carries on. -/
public def migrateUp [SqlBackend Conn] (conn : Conn) (all : Array Migration)
    (target? : Option String := none) : IO Unit := do
  let todo ← pendingMigrations conn all
  let todo := match target? with
    | none => todo
    | some t => todo.filter (·.id <= t)
  for m in todo do
    try
      applyOne conn m
    catch e =>
      -- Our own transaction rolled back, so it can't be what recorded the id. The id being
      -- there now therefore means another caller claimed the migration and committed it, and
      -- the work we were about to do is already done.
      if !(← appliedIds conn).contains m.id then throw e

/-- Rolls back applied migrations in descending id order. With `target? = some id`, rolls back
everything strictly after `id` (leaving `id` itself applied); with `target? = none`, rolls back
only the single most-recently-applied migration (matching migratus's no-argument `rollback`).

Unlike `migrateUp`, this needs exclusive access: deleting a bookkeeping row is not a claim
anything can lose, so two concurrent rollbacks would both run the same `down.sql`. -/
public def migrateDown [SqlBackend Conn] (conn : Conn) (all : Array Migration)
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
