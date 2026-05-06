/-! Probe: simple recursion via if-style termination. -/
partial def sumDownto (n : UInt64) : UInt64 :=
  if n == 0 then 0 else n + sumDownto (n - 1)

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  if sumDownto 10 == 55 then 0 else 99
