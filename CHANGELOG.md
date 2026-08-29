# Changelog

## [0.5.1] - 2026-08-29

The build treats warnings as errors.

## [0.5.0] - 2026-08-20

Move to the Lean module system.

## [0.4.0] - 2026-08-16

- Tests move to a package of their own, so a consumer resolves neither them nor the tools they need
- Theorems covering migration id parsing and padding

## [0.3.1] - 2026-08-06

Suppress the Postgres notice from creating the `schema_migrations` table.

## [0.3.0] - 2026-08-04

A Postgres migration file may contain several statements.

## [0.2.0] - 2026-08-03

Split into separate `leanmigrateSqlite` and `leanmigratePostgres` packages, so a project fetches only the driver it uses.

## [0.1.0] - 2026-08-02

Initial release.
