/-! Probe: UInt8 bitwise ops (`&&&`, `|||`, `^^^`, `<<<`, `>>>`) and
multiplicative arithmetic (`*`, `/`, `%`). The freestanding runtime declares
`lean_uint8_add/sub/xor/dec_eq/le/lt/to_uint64` only — anything else either
inlines via `lean.h` or surfaces as a missing extern. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt8 := 0xF0
  let b : UInt8 := 0x0F
  let c : UInt8 := 5
  let d : UInt8 := 3
  let one : UInt8 := 1
  let n : UInt8 := 16
  let ok :=
    (a &&& b == 0) &&
    (a ||| b == 0xFF) &&
    (a ^^^ 0xFF == 0x0F) &&
    (one <<< 4 == n) &&
    (n >>> 2 == 4) &&
    (c * d == 15) &&
    (n / d == 5) &&
    (n % d == 1) &&
    (a + 1 == 0xF1) &&
    (b - 1 == 0x0E)
  if ok then 0 else 99
