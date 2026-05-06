/- Probe: Char literals, Char.toNat, comparison. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Char := 'A'
  let z : Char := 'Z'
  let nA : UInt64 := a.toNat.toUInt64
  let nZ : UInt64 := z.toNat.toUInt64
  if nA == 65 && nZ == 90 && (nZ - nA) == 25 then 0 else 99
