# leanmigrate

A database migration library for Lean 4, modeled on
[migratus](https://github.com/yogthos/migratus). Migrations are plain SQL files on disk;
leanmigrate tracks which have been applied and gives you `create`/`migrate`/`rollback`/`pending`
commands to manage them.

It supports [leansqlite](https://github.com/leanprover/leansqlite) and
[leanpostgres](https://github.com/paulbutcher/leanpostgres) out of the box, and can be extended to
other backends by implementing a three-method type class.

## Adding it to your project

Require whichever backend you use:

```toml
# if using SQLite
[[require]]
name = "leanmigrateSqlite"
git = "https://github.com/paulbutcher/leanmigrate"
rev = "<rev>"
subDir = "sqlite"
```

```toml
# if using Postgres
[[require]]
name = "leanmigratePostgres"
git = "https://github.com/paulbutcher/leanmigrate"
rev = "<rev>"
subDir = "postgres"
```

## Running migrations

leanmigrate doesn't ship a standalone binary, since opening the database connection is inherently
project-specific. Instead, add a small `lean_exe` to your own `lakefile.toml`:

```toml
[[lean_exe]]
name = "migrate"
srcDir = "dev"
root = "Migrate"
```

```lean
-- dev/Migrate.lean
import SQLite
import Leanmigrate
import LeanmigrateSqlite

def main (args : List String) : IO UInt32 := do
  let conn ← SQLite.open "app.db"
  runCli { conn, dir := "migrations" } args
```

(swap in `import Postgres`, `import LeanmigratePostgres`, and `Postgres.open ""` for Postgres;
an empty conninfo string falls back to the standard `PGHOST`/`PGPORT`/`PGUSER`/`PGDATABASE`
environment variables).

Then:

```sh
lake exe migrate create add_users   # writes migrations/<id>_add_users.{up,down}.sql
lake exe migrate migrate            # applies all pending migrations
lake exe migrate migrate 20260101120000  # applies pending migrations up to and including this id
lake exe migrate rollback           # undoes the most recently applied migration
lake exe migrate rollback 3         # undoes the 3 most recently applied migrations
lake exe migrate rollback 20260101120000 # undoes everything applied after this id
lake exe migrate pending            # lists migrations not yet applied
```

## Migration files

`create` writes a pair of empty files under your migrations directory, named
`<14-digit-UTC-timestamp>_<name>.up.sql` and `..._<name>.down.sql`. Fill in the `up.sql` with the
change and the `down.sql` with how to undo it. Every `up.sql` must have a matching `down.sql`, or
`leanmigrate` refuses to run.

Applying a migration runs its `up.sql` and records its id in a `schema_migrations` bookkeeping
table in a single transaction, so a migration that fails is never left half-applied. Migrations
run in ascending id order; a run stops at the first failure, leaving everything before it applied
and everything from it onward untouched.

## Supporting another backend

Implement `SqlBackend` for your connection type:

```lean
class SqlBackend (Conn : Type) where
  exec            : Conn → String → IO Unit
  queryText1      : Conn → String → IO (Array String)
  withTransaction : Conn → IO α → IO α
```

`exec` runs a statement, discarding any results. `queryText1` runs a query that returns a single
text column, one entry per row; it's only ever used internally, to read the `schema_migrations`
table. `withTransaction` runs an action atomically, rolling back if it throws. See
`sqlite/LeanmigrateSqlite/Backend.lean` and `postgres/LeanmigratePostgres/Backend.lean` for
examples; each is under twenty lines.

## Development

This repo is a Lake workspace over three packages: `core` (`leanmigrate`), `sqlite`
(`leanmigrateSqlite`) and `postgres` (`leanmigratePostgres`), each with its own `lakefile.lean`
and `lake-manifest.json`. The root `lakefile.lean` requires all three by path purely so `lake
build` and `lake test` here exercise everything together; it isn't a package consumers require.

`lake test` runs the pure discovery/ordering tests, then the SQLite scenario tests (against a
temp-file database), then the Postgres scenario tests (against a live database, in a throwaway
schema per test; see `PG*` environment variables for how the connection is configured).
