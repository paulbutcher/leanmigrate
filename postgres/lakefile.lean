/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

-- First revision providing `Postgres.execScript`, which `exec` needs to run multi-statement
-- migration files.
require leanpostgres from git
  "https://github.com/paulbutcher/leanpostgres" @ "f7b8f7c26e80203ba0476e4a4322e0c545545def"

package leanmigratePostgres where
  version := v!"0.3.0"

@[default_target]
lean_lib LeanmigratePostgres
