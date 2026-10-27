/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
import Std.Time

/-- A discovered migration on disk. `id` is a run of ASCII digits, validated by both
`discoverMigrations` and `createMigration`, so it's always safe to interpolate directly into
the bookkeeping SQL in `Engine.lean`. -/
public structure Migration where
  id   : String
  name : String
  up   : System.FilePath
  down : System.FilePath
deriving Repr, BEq

private def stripSuffix (s suffix : String) : Option String :=
  if s.endsWith suffix then some (s.dropEnd suffix.length).toString else none

/-- Parses a filename of the form `<digits>_<name>.up.sql` or `<digits>_<name>.down.sql`,
returning `(id, name, isUp)`. Any other filename yields `none`. -/
public def parseMigrationFilename (fname : String) : Option (String × String × Bool) :=
  let stem? := (stripSuffix fname ".up.sql").map (·, true)
    |>.orElse fun _ => (stripSuffix fname ".down.sql").map (·, false)
  stem?.bind fun (stem, isUp) =>
    match stem.splitOn "_" with
    | id :: h :: t =>
      if !id.isEmpty && id.all Char.isDigit then
        some (id, String.intercalate "_" (h :: t), isUp)
      else none
    | _ => none

/-- Scans `dir` for `<id>_<name>.up.sql` / `.down.sql` pairs and returns them sorted ascending
by id. `dir` not existing is treated as no migrations rather than an error, so a fresh project
doesn't need to create the directory up front. Fails if an `.up.sql` has no matching
`.down.sql`, since a migration that can't be rolled back is very likely a mistake. -/
public def discoverMigrations (dir : System.FilePath) : IO (Array Migration) := do
  if !(← dir.pathExists) then return #[]
  let mut ups : Array (String × String × System.FilePath) := #[]
  let mut downs : Array (String × System.FilePath) := #[]
  for entry in (← dir.readDir) do
    match parseMigrationFilename entry.fileName with
    | some (id, name, true) => ups := ups.push (id, name, entry.path)
    | some (id, _, false) => downs := downs.push (id, entry.path)
    | none => pure ()
  let mut result := #[]
  for (id, name, up) in ups do
    match downs.find? (·.1 == id) with
    | some (_, down) => result := result.push { id, name, up, down }
    | none => throw <| IO.userError s!"migration {id}_{name}.up.sql has no matching down.sql"
  return result.qsort (·.id < ·.id)

/-- Discovers the migrations in `dir` and in each of `includeDirs`, merged into one sequence
sorted ascending by id. Unlike a missing `dir`, a missing included directory is an error: it
belongs to a dependency, so its absence means a broken build rather than a fresh project. So is
an id found twice, since bookkeeping keyed on the id would apply it once while appearing to be
two. -/
public def discoverAllMigrations (dir : System.FilePath) (includeDirs : List System.FilePath) :
    IO (Array Migration) := do
  let mut all ← discoverMigrations dir
  for d in includeDirs do
    if !(← d.isDir) then
      throw <| IO.userError s!"included migrations directory {d} does not exist"
    all := all ++ (← discoverMigrations d)
  let sorted := all.qsort (·.id < ·.id)
  for (a, b) in sorted.zip (sorted.extract 1) do
    if a.id == b.id then
      throw <| IO.userError s!"migration id {a.id} is used by both {a.up} and {b.up}"
  return sorted

public def pad (width : Nat) (n : Int) : String :=
  String.ofList (List.leftpad width '0' (toString n.toNat).toList)

private def currentUtc : IO Std.Time.PlainDateTime :=
  return (Std.Time.DateTime.ofTimestampWithZone (← Std.Time.Timestamp.now) .UTC).toPlainDateTime

/-- A `yyyyMMddHHmmss` id for the current UTC time, matching migratus's migration naming
convention: sortable lexicographically, and readable at a glance. -/
public def timestampId : IO String := do
  let pdt ← currentUtc
  return pad 4 pdt.year ++ pad 2 pdt.month.val ++ pad 2 pdt.day.val
    ++ pad 2 pdt.hour.val ++ pad 2 pdt.minute.val ++ pad 2 pdt.second.val

/-- The current UTC time as an ISO-8601 string, for recording when a migration was applied. -/
public def isoTimestamp : IO String := do
  let pdt ← currentUtc
  return s!"{pad 4 pdt.year}-{pad 2 pdt.month.val}-{pad 2 pdt.day.val}" ++
    s!"T{pad 2 pdt.hour.val}:{pad 2 pdt.minute.val}:{pad 2 pdt.second.val}Z"

/-- Creates a fresh pair of empty `<id>_<name>.up.sql` / `.down.sql` files under `dir`
(creating `dir` if needed), where `name` has been sanitized to `[A-Za-z0-9_]`. -/
public def createMigration (dir : System.FilePath) (name : String) : IO Migration := do
  let clean := String.ofList (name.toList.filter fun c => c.isAlphanum || c == '_')
  if clean.isEmpty then
    throw <| IO.userError s!"migration name {name.quote} has no valid characters"
  IO.FS.createDirAll dir
  let id ← timestampId
  let up := dir / s!"{id}_{clean}.up.sql"
  let down := dir / s!"{id}_{clean}.down.sql"
  IO.FS.writeFile up ""
  IO.FS.writeFile down ""
  return { id, name := clean, up, down }
