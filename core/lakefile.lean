/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lake
open Lake DSL

package leanmigrate where
  version := v!"0.2.0"

@[default_target]
lean_lib Leanmigrate

lean_lib LeanmigrateTest
