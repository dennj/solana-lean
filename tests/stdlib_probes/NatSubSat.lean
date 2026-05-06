/-! Probe: `Nat` subtraction saturates at zero. Unlike fixed-width
integers, Lean's `Nat` is unbounded but cannot go below zero, so
`5 - 7 == 0`. The freestanding runtime must implement `lean_nat_sub`
with the saturation semantics. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Nat := 5
  let b : Nat := 7
  let big : Nat := 1000
  let zero : Nat := 0
  let ok :=
    (a - b == 0)              &&    -- saturate when result would be negative
    (b - a == 2)              &&    -- normal direction
    (zero - 1 == 0)           &&    -- saturate from zero
    (zero - 1000 == 0)        &&    -- saturate from zero by a lot
    (a - a == 0)              &&    -- equal cancels
    (big - 1 == 999)          &&    -- normal subtraction
    (big - big == 0)          &&    -- big - self = 0
    (big - (big + 1) == 0)         -- saturate by one
  if ok then 0 else 99
