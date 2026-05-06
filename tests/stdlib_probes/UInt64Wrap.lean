/-! Probe: `UInt64` boundary arithmetic. UInt64 is mod-2^64, so
`MAX + 1 = 0` and `MAX * 2 = MAX - 1`. The probe pins the wrap-around
behaviour at the upper boundary. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let max : UInt64 := 0xFFFFFFFFFFFFFFFF
  let zero : UInt64 := 0
  let one : UInt64 := 1
  let half : UInt64 := 0x8000000000000000
  let ok :=
    (max + 1 == 0)               &&    -- wrap to zero
    (max + 2 == 1)               &&    -- wrap by two
    (max * 2 == max - 1)         &&    -- 2 * MAX = MAX - 1 mod 2^64
    (max + max == max - 1)       &&    -- (2^64 - 1) + (2^64 - 1) mod 2^64
    (zero - 1 == max)            &&    -- underflow
    (half + half == 0)           &&    -- 2 * 2^63 = 2^64 = 0
    (max ^^^ max == 0)           &&    -- xor with self
    (max ||| 0 == max)           &&    -- or with zero
    (max &&& 0 == 0)             &&    -- and with zero
    (one <<< 63 == half)              -- shift to top bit
  if ok then 0 else 99
