/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate
import LeanmigrateTest.Framework

def touch (path : System.FilePath) (contents : String := "") : IO Unit :=
  IO.FS.writeFile path contents

def testWellFormedPairsSortedById : IO Unit := do
  let dir ← freshTempDir "sorted"
  touch (dir / "20260102030405_second.up.sql")
  touch (dir / "20260102030405_second.down.sql")
  touch (dir / "20260101000000_first.up.sql")
  touch (dir / "20260101000000_first.down.sql")
  let migrations ← discoverMigrations dir
  check "discovers both migrations" (migrations.size == 2)
  check "sorted ascending by id" (migrations.map (·.id) == #["20260101000000", "20260102030405"])
  check "names parsed correctly" (migrations.map (·.name) == #["first", "second"])
  IO.FS.removeDirAll dir

def testMissingDownErrors : IO Unit := do
  let dir ← freshTempDir "missing-down"
  touch (dir / "20260101000000_orphan.up.sql")
  checkThrows "up file with no matching down.sql errors" (discoverMigrations dir)
  IO.FS.removeDirAll dir

def testUnrelatedFilesIgnored : IO Unit := do
  let dir ← freshTempDir "unrelated"
  touch (dir / "20260101000000_only.up.sql")
  touch (dir / "20260101000000_only.down.sql")
  touch (dir / "README.md")
  touch (dir / ".gitkeep")
  let migrations ← discoverMigrations dir
  check "unrelated files don't affect discovery" (migrations.size == 1)
  IO.FS.removeDirAll dir

def testMissingDirIsEmpty : IO Unit := do
  let migrations ← discoverMigrations "/tmp/leanmigrate-test-does-not-exist"
  check "a missing migrations directory yields no migrations" (migrations.isEmpty)

def testCreateMigration : IO Unit := do
  let dir ← freshTempDir "create"
  let m ← createMigration dir "Add Users!"
  check "id is 14 digits" (m.id.length == 14 && m.id.all Char.isDigit)
  check "name is sanitized" (m.name == "AddUsers")
  check "up file was written" (← m.up.pathExists)
  check "down file was written" (← m.down.pathExists)
  checkThrows "a name with no valid characters is rejected" (createMigration dir "!!!")
  IO.FS.removeDirAll dir

def main : IO UInt32 := do
  testWellFormedPairsSortedById
  testMissingDownErrors
  testUnrelatedFilesIgnored
  testMissingDirIsEmpty
  testCreateMigration
  report "MigrationTests"
