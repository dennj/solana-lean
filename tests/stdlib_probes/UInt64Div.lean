/-! Probe: `UInt64.div` (`/`). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt64 := 1000000
  let b : UInt64 := 7
  let big : UInt64 := 0xFFFFFFFFFFFFFFFF
  let one : UInt64 := 1
  let ok :=
    (a / b == 142857) &&
    (a / 1 == 1000000) &&
    (a / a == 1) &&
    (0 / b == 0) &&
    (big / 2 == 0x7FFFFFFFFFFFFFFF) &&
    (big / big == 1) &&
    (one / big == 0)
  if ok then 0 else 99
