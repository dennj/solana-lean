/- Probe: Array operations (size, foldl). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let xs : Array UInt64 := #[10, 20, 30, 40, 50]
  let n : UInt64 := xs.size.toUInt64
  let sum : UInt64 := xs.foldl (init := 0) (· + ·)
  if n == 5 && sum == 150 then 0 else 99
