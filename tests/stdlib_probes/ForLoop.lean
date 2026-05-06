/- Probe: `for i in [0:n]` range iteration. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut sum : UInt64 := 0
  for i in [0:10] do
    sum := sum + i.toUInt64
  if sum == 45 then return 0 else return 99
