/-! Probe: bounded-Nat near the 2^63 - 1 cap and saturating subtraction. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let cap : Nat := 9223372036854775807    -- 2^63 - 1
  let satSub : Nat := 5 - 100
  let halfCap : Nat := cap / 2
  let bumped : Nat := halfCap + 1
  let ok :=
    (satSub == 0) &&
    (halfCap < cap) &&
    (bumped > halfCap) &&
    (halfCap * 2 == cap - 1)
  if ok then 0 else 99
