/- Probe: Bool operations (&&, ||, !) and branching. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let t := true
  let f := false
  let ok :=
    (t && t) &&
    !(t && f) &&
    (t || f) &&
    !(f || f) &&
    !(!t) &&
    (decide (1 < 2 : Prop))
  if ok then 0 else 99
