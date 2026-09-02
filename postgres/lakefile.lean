/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

require leanmigrate from ".." / "core"

require leanpostgres from git
  "https://github.com/paulbutcher/leanpostgres" @ "v0.7.2"

package leanmigratePostgres where
  version := v!"0.6.0"
  leanOptions := #[⟨`experimental.module, true⟩, ⟨`warningAsError, true⟩]

@[default_target]
lean_lib LeanmigratePostgres
