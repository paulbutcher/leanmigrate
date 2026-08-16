/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate
import LeanmigrateTest.Framework

/-- Writes one migration per id in `ids` under `dir`, each creating/dropping its own
uniquely-named table. Ids should be distinct, fixed-width, all-digit strings so lexicographic
and intended order agree. -/
private def writeMigrations (dir : System.FilePath) (ids : Array String) :
    IO (Array Migration) := do
  IO.FS.createDirAll dir
  let mut result := #[]
  for id in ids do
    let name := s!"widget{id}"
    let up := dir / s!"{id}_{name}.up.sql"
    let down := dir / s!"{id}_{name}.down.sql"
    IO.FS.writeFile up s!"CREATE TABLE widget_{id} (id INTEGER);"
    IO.FS.writeFile down s!"DROP TABLE widget_{id};"
    result := result.push { id, name, up, down }
  return result

/-- Writes a migration under `dir` whose `up.sql` is invalid, for testing that a failing
migration aborts the run. -/
private def writeBadMigration (dir : System.FilePath) (id : String) : IO Migration := do
  let name := s!"broken{id}"
  let up := dir / s!"{id}_{name}.up.sql"
  let down := dir / s!"{id}_{name}.down.sql"
  IO.FS.writeFile up "this is not valid sql;"
  IO.FS.writeFile down "select 1;"
  return { id, name, up, down }

private def tableExists [SqlBackend Conn] (conn : Conn) (table : String) : IO Bool := do
  try
    discard <| SqlBackend.queryText1 conn s!"SELECT id FROM {table}"
    pure true
  catch _ => pure false

/-- Applying a batch of pending migrations from a clean database applies all of them, in
ascending id order. -/
def scenarioCleanApply [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) : IO Unit := do
  let all ← writeMigrations dir #["00000001", "00000002", "00000003"]
  migrateUp conn all
  let applied ← appliedIds conn
  check "clean apply: all migrations applied in order"
    (applied == #["00000001", "00000002", "00000003"])

/-- Rolling back with no target undoes exactly the single most-recently-applied migration,
running its `down.sql` and removing its bookkeeping row, leaving earlier migrations untouched. -/
def scenarioApplyThenRollback [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  let all ← writeMigrations dir #["00000001", "00000002"]
  migrateUp conn all
  migrateDown conn all
  let applied ← appliedIds conn
  check "apply then rollback: only the latest is undone" (applied == #["00000001"])
  check "apply then rollback: the latest's table is gone" !(← tableExists conn "widget_00000002")
  check "apply then rollback: the earlier table remains" (← tableExists conn "widget_00000001")

/-- Applying up to a target id, then discovering newly-added migrations and applying again
with no target, applies only what's still pending. -/
def scenarioPartialThenMore [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  let initial ← writeMigrations dir #["00000001", "00000002"]
  migrateUp conn initial (target? := some "00000001")
  discard <| writeMigrations dir #["00000003"]
  let all ← discoverMigrations dir
  migrateUp conn all
  let applied ← appliedIds conn
  check "partial then more: everything ends up applied in order"
    (applied == #["00000001", "00000002", "00000003"])

/-- Applying the same batch twice is a no-op the second time: already-applied migrations are
never re-run. -/
def scenarioIdempotentRerun [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  let all ← writeMigrations dir #["00000001"]
  migrateUp conn all
  migrateUp conn all
  let applied ← appliedIds conn
  check "idempotent re-run: no duplicate application" (applied == #["00000001"])

/-- A single migration file may contain several `;`-separated statements, which apply and roll
back as a unit. -/
def scenarioMultiStatementFile [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  IO.FS.createDirAll dir
  IO.FS.writeFile (dir / "00000001_multi.up.sql")
    "CREATE TABLE multi_a (id INTEGER);\nCREATE TABLE multi_b (id INTEGER);"
  IO.FS.writeFile (dir / "00000001_multi.down.sql")
    "DROP TABLE multi_a;\nDROP TABLE multi_b;"
  let all ← discoverMigrations dir
  migrateUp conn all
  check "multi-statement up: every statement applied"
    ((← tableExists conn "multi_a") && (← tableExists conn "multi_b"))
  migrateDown conn all
  check "multi-statement down: every statement applied"
    (!(← tableExists conn "multi_a") && !(← tableExists conn "multi_b"))

/-- A failing migration aborts the whole run: migrations before it stay committed, the failing
one is fully rolled back (no bookkeeping row), and nothing after it ever runs. -/
def scenarioFailureMidBatchAborts [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  discard <| writeMigrations dir #["00000001"]
  discard <| writeBadMigration dir "00000002"
  discard <| writeMigrations dir #["00000003"]
  let all ← discoverMigrations dir
  checkThrows "a failing migration aborts the run" (migrateUp conn all)
  let applied ← appliedIds conn
  check "only the migration before the failure is committed" (applied == #["00000001"])
  check "the migration after the failure never ran" !(← tableExists conn "widget_00000003")
