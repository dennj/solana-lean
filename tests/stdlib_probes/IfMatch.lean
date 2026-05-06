/- Probe: if/match branching — LLVM switch lowering with i64 discriminator. -/
inductive Color where
  | red | green | blue

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let c := Color.green
  let v : UInt64 := match c with
    | Color.red   => 1
    | Color.green => 2
    | Color.blue  => 3
  let n : UInt64 := 7
  let cond := if n > 5 then n - 5 else 0
  if v == 2 && cond == 2 then 0 else 99
