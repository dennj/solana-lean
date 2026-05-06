/-! Probe: bounded Nat arithmetic (add, sub, mul, div, mod, comparisons). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Nat := 1000
  let b : Nat := 7
  let ok :=
    (a + b == 1007) &&
    (a - b == 993) &&
    (a * b == 7000) &&
    (a / b == 142) &&
    (a % b == 6) &&
    (5 - 100 == 0) &&
    (b < a) &&
    (a <= a)
  if ok then 0 else 99
