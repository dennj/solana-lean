/-! Probe: Option α — construction and pattern match. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Option UInt64 := some 42
  let b : Option UInt64 := none
  let av : UInt64 := match a with | some x => x | none => 0
  let bv : UInt64 := match b with | some x => x | none => 99
  let r : UInt64 := av + bv
  if r == 141 then 0 else 99
