/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

/-- The minimal set of database operations the migration engine needs. Backend adapters
(one per underlying driver, e.g. SQLite or Postgres) provide an instance of this class for
their own connection type, handling that driver's own placeholder syntax and error types
internally. -/
class SqlBackend (Conn : Type) where
  /-- Execute a batch of SQL against `Conn`, discarding any result rows. -/
  exec : Conn → String → IO Unit
  /-- Run a query that returns a single text column, one entry per result row. -/
  queryText1 : Conn → String → IO (Array String)
  /-- Run `action` inside a database transaction, committing on success and rolling back if
  `action` throws. -/
  withTransaction : Conn → IO α → IO α
