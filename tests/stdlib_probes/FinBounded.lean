/-! Probe: `Fin n` arithmetic with bounds proofs. `Fin n` is a subtype
`{val : Nat // val < n}`. The probe constructs `Fin 100` values and
performs modular addition while preserving the bound. -/

def addFin (a b : Fin 100) : Fin 100 :=
  ⟨(a.val + b.val) % 100, Nat.mod_lt _ (by decide)⟩

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Fin 100 := ⟨42, by decide⟩
  let b : Fin 100 := ⟨88, by decide⟩
  let c : Fin 100 := ⟨0, by decide⟩
  let r1 := addFin a b
  let r2 := addFin a c
  let r3 := addFin b b
  -- (42+88)%100 = 30; (42+0)%100 = 42; (88+88)%100 = 76
  if r1.val == 30 && r2.val == 42 && r3.val == 76 then 0 else 99
