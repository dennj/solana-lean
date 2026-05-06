/-! Probe: Prod tuples — mixed-type pairs and nested pairs. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let p : UInt64 × UInt64 := (10, 32)
  let q : UInt64 × (UInt64 × UInt64) := (1, (2, 3))
  let s := p.1 + p.2 + q.1 + q.2.1 + q.2.2
  if s == 48 then 0 else 99
