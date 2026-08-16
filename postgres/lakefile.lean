/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

require leanpostgres from git
  "https://github.com/paulbutcher/leanpostgres" @ "v0.4.1"

package leanmigratePostgres where
  version := v!"0.4.0"

@[default_target]
lean_lib LeanmigratePostgres
