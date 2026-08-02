/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

package leanmigrate where
  version := v!"0.1.0"

-- Closest tagged release to our v4.32.2 toolchain that still builds cleanly.
-- `main` is on v4.33.0-rc1, which needs a newer toolchain than ours.
require leansqlite from git
  "https://github.com/leanprover/leansqlite" @ "b2e8105c3507d81adaa531fda5990d14b631528f"

-- Closest tagged release to our v4.32.2 toolchain; also predates the `plausible`
-- dependency added to `main`, which we don't need.
require leanpostgres from git
  "https://github.com/paulbutcher/leanpostgres" @ "b9442f8df6227a5e472b309ed1b77fe699968a17"

@[default_target]
lean_lib Leanmigrate

lean_lib LeanmigrateSqlite

lean_lib LeanmigratePostgres

lean_lib LeanmigrateTest

lean_exe MigrationTests where
  srcDir := "tests"
  root := `MigrationTests

lean_exe SqliteTests where
  srcDir := "tests"
  root := `SqliteTests

lean_exe PostgresTests where
  srcDir := "tests"
  root := `PostgresTests

-- Dogfoods the exact wiring documented for consumers in the README.
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

