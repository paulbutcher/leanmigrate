/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

-- Closest tagged release to our v4.32.2 toolchain; also predates the `plausible`
-- dependency added to `main`, which we don't need.
require leanpostgres from git
  "https://github.com/paulbutcher/leanpostgres" @ "b9442f8df6227a5e472b309ed1b77fe699968a17"

package leanmigratePostgres where
  version := v!"0.3.0"

@[default_target]
lean_lib LeanmigratePostgres
