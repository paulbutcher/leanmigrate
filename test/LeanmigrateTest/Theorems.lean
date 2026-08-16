/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanmigrate

/-- `Engine.lean` interpolates `Migration.id` directly into the bookkeeping SQL rather than
binding it as a parameter. Every id it ever sees reached it through `discoverMigrations`, and so
through `parseMigrationFilename`, which makes this the property that rules out a crafted filename
injecting SQL. -/
theorem parseMigrationFilename_id_isDigits {fname id name : String} {isUp : Bool}
    (h : parseMigrationFilename fname = some (id, name, isUp)) :
    id ≠ "" ∧ id.all Char.isDigit := by
  unfold parseMigrationFilename at h
  simp only [Option.bind_eq_some_iff] at h
  obtain ⟨⟨stem, up⟩, -, h⟩ := h
  split at h
  · split at h
    · simp_all
    · simp at h
  · simp at h

theorem pad_length (width : Nat) (n : Int) :
    (pad width n).length = max width (toString n.toNat).length := by
  simp [pad, String.length, Nat.sub_add_eq_max]

/-- Migrations are ordered by comparing their ids as strings, which agrees with chronological
order only while every component of the timestamp occupies its full width: a component that
overflowed would shift every later one and silently reorder the run. -/
theorem pad_length_eq_width {width : Nat} {n : Int} (hw : 0 < width) (h : n.toNat < 10 ^ width) :
    (pad width n).length = width := by
  rw [pad_length]
  have : (toString n.toNat).length ≤ width := by
    rw [Nat.toString_eq_ofList_toDigits]
    simpa [String.length] using (Nat.length_toDigits_le_iff (by omega) hw).mpr h
  omega

/-- `pad` is the only source of characters in an id `createMigration` writes, so this is the
other half of the loop `parseMigrationFilename_id_isDigits` closes: what `createMigration` names
a file is what `discoverMigrations` will accept back. -/
theorem pad_all_isDigit (width : Nat) (n : Int) : (pad width n).all Char.isDigit := by
  simp [pad, String.all_bool_eq, List.leftpad, List.all_replicate]
  exact fun c hc => Nat.isDigit_of_mem_toDigits (by omega) (by omega) hc
