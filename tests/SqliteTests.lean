/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanmigrateTest
import LeanmigrateSqlite

/-- Runs `action` against a fresh SQLite database file and migrations directory, so each
scenario starts with a clean `schema_migrations` table. -/
private def withFreshDb (label : String) (action : SQLite → System.FilePath → IO Unit) :
    IO Unit := do
  let dir ← freshTempDir label
  let conn ← SQLite.open (dir / "test.db")
  action conn dir
  IO.FS.removeDirAll dir

def main : IO UInt32 := do
  withFreshDb "sqlite-clean-apply" scenarioCleanApply
  withFreshDb "sqlite-apply-rollback" scenarioApplyThenRollback
  withFreshDb "sqlite-partial-more" scenarioPartialThenMore
  withFreshDb "sqlite-idempotent" scenarioIdempotentRerun
  withFreshDb "sqlite-failure-aborts" scenarioFailureMidBatchAborts
  withFreshDb "sqlite-multistatement" scenarioMultiStatementFile
  report "SqliteTests"
