/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
import LeanmigrateTest
import LeanmigratePostgres

/-- Runs `action` in a freshly created schema, on the connection given by the standard `PG*`
environment variables, so each scenario gets its own empty `schema_migrations` table and its
own namespace for the tables its migrations create. `action` is given a way to open connections
rather than a connection, since a scenario racing two callers needs one each, and since
`search_path` is per-session and so has to be set on each of them. The schema (and its temp
migrations directory) is dropped afterwards, success or failure. -/
private def withFreshSchema (label : String)
    (action : IO Postgres.Conn → System.FilePath → IO Unit) : IO Unit := do
  let conn ← Postgres.open ""
  let schema := s!"leanmigrate_test_{label}_{← IO.monoNanosNow}"
  SqlBackend.exec conn s!"CREATE SCHEMA {schema}"
  let newConn : IO Postgres.Conn := do
    let scenarioConn ← Postgres.open ""
    SqlBackend.exec scenarioConn s!"SET search_path TO {schema}"
    return scenarioConn
  let dir ← freshTempDir label
  try
    action newConn dir
  finally
    SqlBackend.exec conn s!"DROP SCHEMA {schema} CASCADE"
    IO.FS.removeDirAll dir

private def single (scenario : Postgres.Conn → System.FilePath → IO Unit)
    (newConn : IO Postgres.Conn) (dir : System.FilePath) : IO Unit := do
  scenario (← newConn) dir

public def main : IO UInt32 := do
  withFreshSchema "pgcleanapply" (single scenarioCleanApply)
  withFreshSchema "pgapplyrollback" (single scenarioApplyThenRollback)
  withFreshSchema "pgpartialmore" (single scenarioPartialThenMore)
  withFreshSchema "pgidempotent" (single scenarioIdempotentRerun)
  withFreshSchema "pgfailureaborts" (single scenarioFailureMidBatchAborts)
  withFreshSchema "pgmultistatement" (single scenarioMultiStatementFile)
  withFreshSchema "pgconcurrent" scenarioConcurrentUp
  withFreshSchema "pgloserrunsnothing" scenarioLoserRunsNothing
  report "PostgresTests"
