/-! Probe: USize arithmetic, comparisons, and conversions. Exercises
`lean_usize_add/sub/mul/dec_eq/le/lt/of_nat/to_nat/to_uint64`. USize is
target-dependent (32-bit on wasm32-wasip1, 64-bit on host/sbf/riscv64) so
divergence here is a target-ABI bug. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : USize := 1000
  let b : USize := 7
  let zero : USize := 0
  let ok :=
    (a + b == (1007 : USize)) &&
    (a - b == (993 : USize)) &&
    (a * b == (7000 : USize)) &&
    (b < a) &&
    (a == a) &&
    (a <= a) &&
    (zero < a) &&
    (a.toNat == 1000) &&
    (a.toUInt64 == (1000 : UInt64)) &&
    (USize.ofNat 42 == (42 : USize))
  if ok then 0 else 99
