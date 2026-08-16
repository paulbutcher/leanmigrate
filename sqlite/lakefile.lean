/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

-- Closest tagged release to our v4.32.2 toolchain that still builds cleanly.
-- `main` is on v4.33.0-rc1, which needs a newer toolchain than ours.
require leansqlite from git
  "https://github.com/leanprover/leansqlite" @ "b2e8105c3507d81adaa531fda5990d14b631528f"

package leanmigrateSqlite where
  version := v!"0.4.0"

@[default_target]
lean_lib LeanmigrateSqlite
