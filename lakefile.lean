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
  version := v!"0.3.1"

require leanmigrate from "core"

require leanmigrateSqlite from "sqlite"

require leanmigratePostgres from "postgres"

-- Dogfoods the exact wiring documented for consumers in the README.
@[default_target]
lean_exe «migrate-sqlite» where
  srcDir := "dev"
  root := `MigrateSqlite

@[test_driver]
script test (_args) do
  let child ← IO.Process.spawn
    { cmd := "lake", args := #["test"], cwd := __dir__ / "test" }
  child.wait
