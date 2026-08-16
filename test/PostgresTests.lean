/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import LeanmigrateTest
import LeanmigratePostgres

/-- Runs `action` in a freshly created schema, on the connection given by the standard `PG*`
environment variables, so each scenario gets its own empty `schema_migrations` table and its
own namespace for the tables its migrations create. The schema (and its temp migrations
directory) is dropped afterwards, success or failure. -/
private def withFreshSchema (label : String) (action : Postgres.Conn → System.FilePath → IO Unit) :
    IO Unit := do
  let conn ← Postgres.open ""
  let schema := s!"leanmigrate_test_{label}_{← IO.monoNanosNow}"
  SqlBackend.exec conn s!"CREATE SCHEMA {schema}"
  SqlBackend.exec conn s!"SET search_path TO {schema}"
  let dir ← freshTempDir label
  try
    action conn dir
  finally
    SqlBackend.exec conn s!"DROP SCHEMA {schema} CASCADE"
    IO.FS.removeDirAll dir

def main : IO UInt32 := do
  withFreshSchema "pgcleanapply" scenarioCleanApply
  withFreshSchema "pgapplyrollback" scenarioApplyThenRollback
  withFreshSchema "pgpartialmore" scenarioPartialThenMore
  withFreshSchema "pgidempotent" scenarioIdempotentRerun
  withFreshSchema "pgfailureaborts" scenarioFailureMidBatchAborts
  withFreshSchema "pgmultistatement" scenarioMultiStatementFile
  report "PostgresTests"
