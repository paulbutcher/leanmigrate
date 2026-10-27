/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

/-- What the CLI needs to operate: an open connection and the migrations directories. `dir` is
the application's own, and the only one `create` writes to; `includeDirs` names further,
read-only directories, such as those a library ships, whose migrations are merged with `dir`'s
by id. -/
public structure Config (Conn : Type) where
  conn        : Conn
  dir         : System.FilePath := "migrations"
  includeDirs : List System.FilePath := []
