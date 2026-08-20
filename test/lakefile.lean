/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

require leanmigrateSqlite from ".." / "sqlite"

require leanmigratePostgres from ".." / "postgres"

-- A package of its own, rather than targets in the packages it tests, so that nothing here
-- reaches a downstream consumer: neither this code nor the test-only dependencies it pulls in.
package leanmigrateTest where
  version := v!"0.5.0"
  leanOptions := #[⟨`experimental.module, true⟩]

@[default_target]
lean_lib LeanmigrateTest

@[default_target]
lean_exe MigrationTests where
  root := `MigrationTests

@[default_target]
lean_exe SqliteTests where
  root := `SqliteTests

@[default_target]
lean_exe PostgresTests where
  root := `PostgresTests

/-- Runs each test executable as its own process (rather than importing their `main`s here)
so `lake exe SqliteTests`, for instance, stays runnable on its own, e.g. in an environment with
no Postgres available. -/
@[test_driver]
script test (_args) do
  let mut code : UInt32 := 0
  for exe in #["MigrationTests", "SqliteTests", "PostgresTests"] do
    let child ← IO.Process.spawn { cmd := "lake", args := #["exe", exe] }
    let exitCode ← child.wait
    if exitCode != 0 then code := exitCode
  return code
