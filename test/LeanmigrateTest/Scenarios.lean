/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import Leanmigrate
public import LeanmigrateTest.Framework

/-- Writes a migration under `dir` creating and dropping its own uniquely-named table. Its
`up.sql` is deliberately not idempotent, so anything that runs it twice fails. -/
private def writeMigration (dir : System.FilePath) (id : String) : IO Migration := do
  IO.FS.createDirAll dir
  let name := s!"widget{id}"
  let up := dir / s!"{id}_{name}.up.sql"
  let down := dir / s!"{id}_{name}.down.sql"
  IO.FS.writeFile up s!"CREATE TABLE widget_{id} (id INTEGER);"
  IO.FS.writeFile down s!"DROP TABLE widget_{id};"
  return { id, name, up, down }

/-- Ids should be distinct, fixed-width, all-digit strings so lexicographic and intended order
agree. -/
private def writeMigrations (dir : System.FilePath) (ids : Array String) :
    IO (Array Migration) :=
  ids.mapM (writeMigration dir)

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

private def mentions (haystack needle : String) : Bool := (haystack.splitOn needle).length > 1

/-- Runs `action` twice at once, each run on a connection of its own, and returns what each
threw or returned. Both connections are open and waiting before either run starts, so that the
two overlap rather than one finishing before the other has begun. -/
private def race (newConn : IO Conn) (action : Conn → IO Unit) :
    IO (Except IO.Error Unit × Except IO.Error Unit) := do
  let readyA : IO.Promise Unit ← IO.Promise.new
  let readyB : IO.Promise Unit ← IO.Promise.new
  let side (mine other : IO.Promise Unit) : IO Unit := do
    let conn ← newConn
    mine.resolve ()
    discard <| IO.wait other.result?
    action conn
  let taskA ← IO.asTask (side readyA readyB) .dedicated
  let taskB ← IO.asTask (side readyB readyA) .dedicated
  return (← IO.wait taskA, ← IO.wait taskB)

/-- Applying a batch of pending migrations from a clean database applies all of them, in
ascending id order. -/
public def scenarioCleanApply [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  let all ← writeMigrations dir #["00000001", "00000002", "00000003"]
  migrateUp conn all
  let applied ← appliedIds conn
  check "clean apply: all migrations applied in order"
    (applied == #["00000001", "00000002", "00000003"])

/-- Rolling back with no target undoes exactly the single most-recently-applied migration,
running its `down.sql` and removing its bookkeeping row, leaving earlier migrations untouched. -/
public def scenarioApplyThenRollback [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
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
public def scenarioPartialThenMore [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
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
public def scenarioIdempotentRerun [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  let all ← writeMigrations dir #["00000001"]
  migrateUp conn all
  migrateUp conn all
  let applied ← appliedIds conn
  check "idempotent re-run: no duplicate application" (applied == #["00000001"])

/-- A single migration file may contain several `;`-separated statements, which apply and roll
back as a unit. -/
public def scenarioMultiStatementFile [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
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
one is fully rolled back (no bookkeeping row), and nothing after it ever runs. Since its id is
never recorded, `migrateUp` must report the failure rather than mistake it for a lost race. -/
public def scenarioFailureMidBatchAborts [SqlBackend Conn] (conn : Conn) (dir : System.FilePath) :
    IO Unit := do
  discard <| writeMigrations dir #["00000001"]
  discard <| writeBadMigration dir "00000002"
  discard <| writeMigrations dir #["00000003"]
  let all ← discoverMigrations dir
  checkThrows "a failing migration aborts the run" (migrateUp conn all)
  let applied ← appliedIds conn
  check "only the migration before the failure is committed" (applied == #["00000001"])
  check "the migration after the failure never ran" !(← tableExists conn "widget_00000003")

/-- Two callers running `migrateUp` at once against one database apply every migration exactly
once, and both return successfully. -/
public def scenarioConcurrentUp [SqlBackend Conn] (newConn : IO Conn) (dir : System.FilePath) :
    IO Unit := do
  let ids := (Array.range 12).map fun i => pad 8 (i + 1 : Nat)
  let all ← writeMigrations dir ids
  let (first, second) ← race newConn (migrateUp · all)
  for (which, outcome) in #[("first", first), ("second", second)] do
    match outcome with
    | .ok _ => check s!"concurrent up: the {which} caller succeeds" true
    | .error e => check s!"concurrent up: the {which} caller succeeds (threw {e})" false
  let applied ← appliedIds (← newConn)
  check "concurrent up: every migration applied exactly once" (applied == ids)

/-- Two callers racing for one migration: the loser fails on the bookkeeping row, before any of
the migration's own SQL. The error is the only evidence either way, since the loser's
transaction rolls back whichever statement it died on. -/
public def scenarioLoserRunsNothing [SqlBackend Conn] (newConn : IO Conn) (dir : System.FilePath) :
    IO Unit := do
  let m ← writeMigration dir "00000001"
  ensureMigrationsTable (← newConn)
  let (first, second) ← race newConn (applyOne · m)
  match ([first, second].filterMap fun | .ok _ => none | .error e => some (toString e)) with
  | [thrown] =>
    check "racing for one migration: the loser fails on the claim, not on the migration"
      (mentions thrown "schema_migrations")
  | errors =>
    check s!"racing for one migration: exactly one caller loses (errors: {errors})" false
