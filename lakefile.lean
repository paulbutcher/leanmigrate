/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

-- This package isn't published; it's the local workspace that ties the `core`, `sqlite` and
-- `postgres` packages together for development and integration testing. Consumers require
-- those packages directly (see README.md), so that a project using only one backend never
-- fetches the other backend's driver.
package leanmigrateWorkspace where
  version := v!"0.1.0"

require leanmigrate from "core"

require leanmigrateSqlite from "sqlite"

require leanmigratePostgres from "postgres"

@[default_target]
lean_exe MigrationTests where
  srcDir := "tests"
  root := `MigrationTests

@[default_target]
lean_exe SqliteTests where
  srcDir := "tests"
  root := `SqliteTests

@[default_target]
lean_exe PostgresTests where
  srcDir := "tests"
  root := `PostgresTests

-- Dogfoods the exact wiring documented for consumers in the README.
@[default_target]
lean_exe «migrate-sqlite» where
  srcDir := "dev"
  root := `MigrateSqlite

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

