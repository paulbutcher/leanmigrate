/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
import LeanmigrateTest
import LeanmigrateSqlite

/-- Runs `action` against a fresh SQLite database file and migrations directory, so each
scenario starts with a clean `schema_migrations` table. `action` is given a way to open
connections rather than a connection, since a scenario racing two callers needs one each. -/
private def withFreshDb (label : String) (action : IO SQLite → System.FilePath → IO Unit) :
    IO Unit := do
  let dir ← freshTempDir label
  action (SQLite.open (dir / "test.db")) dir
  IO.FS.removeDirAll dir

private def single (scenario : SQLite → System.FilePath → IO Unit) (newConn : IO SQLite)
    (dir : System.FilePath) : IO Unit := do
  scenario (← newConn) dir

public def main : IO UInt32 := do
  withFreshDb "sqlite-clean-apply" (single scenarioCleanApply)
  withFreshDb "sqlite-apply-rollback" (single scenarioApplyThenRollback)
  withFreshDb "sqlite-partial-more" (single scenarioPartialThenMore)
  withFreshDb "sqlite-idempotent" (single scenarioIdempotentRerun)
  withFreshDb "sqlite-failure-aborts" (single scenarioFailureMidBatchAborts)
  withFreshDb "sqlite-multistatement" (single scenarioMultiStatementFile)
  withFreshDb "sqlite-concurrent" scenarioConcurrentUp
  withFreshDb "sqlite-loser-runs-nothing" scenarioLoserRunsNothing
  report "SqliteTests"
