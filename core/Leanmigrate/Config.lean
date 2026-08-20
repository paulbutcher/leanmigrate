/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

/-- What the CLI needs to operate: an open connection and the migrations directory. -/
public structure Config (Conn : Type) where
  conn : Conn
  dir  : System.FilePath := "migrations"
