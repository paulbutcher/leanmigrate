/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

package leanmigrate where
  version := v!"0.5.1"
  leanOptions := #[⟨`experimental.module, true⟩, ⟨`warningAsError, true⟩]

@[default_target]
lean_lib Leanmigrate
