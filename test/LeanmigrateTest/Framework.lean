/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

/-- A fresh directory under `/tmp`, unique to this call. Callers are responsible for removing
it when done. -/
public def freshTempDir (label : String) : IO System.FilePath := do
  let dir : System.FilePath := s!"/tmp/leanmigrate-test-{label}-{← IO.monoNanosNow}"
  IO.FS.createDirAll dir
  return dir

public initialize failureCount : IO.Ref Nat ← IO.mkRef 0

/-- Records `label` as passing or failing depending on `cond`, printing either way. -/
public def check (label : String) (cond : Bool) : IO Unit := do
  if cond then
    IO.println s!"  ok  - {label}"
  else
    IO.println s!"  FAIL - {label}"
    failureCount.modify (· + 1)

/-- Records `label` as passing if `act` throws, failing if it doesn't. -/
public def checkThrows (label : String) (act : IO α) : IO Unit := do
  try
    discard act
    IO.println s!"  FAIL - {label} (expected an error, got none)"
    failureCount.modify (· + 1)
  catch _ =>
    IO.println s!"  ok  - {label}"

/-- Prints a summary and returns the process exit code: `0` if every `check`/`checkThrows`
call made in this process passed, `1` otherwise. -/
public def report (suiteName : String) : IO UInt32 := do
  let n ← failureCount.get
  if n == 0 then
    IO.println s!"{suiteName}: all checks passed"
    return 0
  else
    IO.println s!"{suiteName}: {n} check(s) failed"
    return 1
