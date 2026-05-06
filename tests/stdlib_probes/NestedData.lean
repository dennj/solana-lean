/-! Probe: nested data — Array of Option of UInt64. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let xs : Array (Option UInt64) := #[some 10, none, some 32, none]
  let mut sum : UInt64 := 0
  for y in xs do
    sum := sum + match y with
      | some n => n
      | none   => 0
  if sum == 42 then return 0 else return 99
