/-! Probe: `UInt64.mod` (`%`). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt64 := 1000000
  let b : UInt64 := 7
  let big : UInt64 := 0xFFFFFFFFFFFFFFFF
  let one : UInt64 := 1
  let ok :=
    (a % b == 1) &&
    (a % 1 == 0) &&
    (a % a == 0) &&
    (0 % b == 0) &&
    (big % 2 == 1) &&
    (big % big == 0) &&
    (one % big == 1) &&
    (10 % 3 == (1 : UInt64))
  if ok then 0 else 99
