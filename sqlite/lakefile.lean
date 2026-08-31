/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

-- Tagged releases track Lean releases; this is the one matching our toolchain.
require leansqlite from git
  "https://github.com/leanprover/leansqlite" @ "v4.33.0"

package leanmigrateSqlite where
  version := v!"0.5.2"
  leanOptions := #[⟨`experimental.module, true⟩, ⟨`warningAsError, true⟩]

@[default_target]
lean_lib LeanmigrateSqlite
