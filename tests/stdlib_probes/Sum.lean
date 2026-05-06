/-! Probe: Sum α β with payload-bearing ctors. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let l : Sum UInt64 UInt64 := Sum.inl 7
  let r : Sum UInt64 UInt64 := Sum.inr 35
  let lv : UInt64 := match l with | Sum.inl x => x | Sum.inr _ => 0
  let rv : UInt64 := match r with | Sum.inl _ => 0 | Sum.inr x => x
  if lv + rv == 42 then 0 else 99
