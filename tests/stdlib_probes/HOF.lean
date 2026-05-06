/- Probe: higher-order function via Array.foldl. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let xs : Array UInt64 := #[10, 20, 30]
  let s : UInt64 := xs.foldl (init := 0) (fun acc v => acc + v)
  if s == 60 then 0 else 99
