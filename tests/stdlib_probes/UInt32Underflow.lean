/-! Probe: `UInt32` boundary arithmetic. UInt32 is mod-2^32, so `0 - 1`
is `0xFFFFFFFF`. Same shape as UInt64Wrap but on i32 — catches any wasm32
ABI mistakes where UInt32 might be promoted to a wider type. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let max32 : UInt32 := 0xFFFFFFFF
  let zero32 : UInt32 := 0
  let one32 : UInt32 := 1
  let half32 : UInt32 := 0x80000000
  let ok :=
    (zero32 - 1 == max32)            &&    -- underflow
    (zero32 - 2 == max32 - 1)        &&    -- underflow by two
    (max32 + 1 == 0)                 &&    -- overflow wraps
    (max32 + max32 == max32 - 1)     &&    -- 2 * (2^32 - 1) mod 2^32
    (max32 * 2 == max32 - 1)         &&    -- shift-equivalent
    (one32 <<< 31 == half32)         &&
    (half32 + half32 == 0)
  if ok then 0 else 99
