/-! Probe: array boundary access via the *safe* (`get?`) and the
*last-valid-index* (`get!` at `size - 1`) paths. The probe deliberately
does not exercise out-of-bounds `get!`, which would `panic!` and abort
before exiting — testing the panic path requires a separate runner that
asserts on panic instead of on `exit 0`. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let arr : Array UInt64 := #[10, 20, 30, 40, 50]
  let n := arr.size
  let lastValid := arr[n - 1]!
  let firstValid := arr[0]!
  let oobNone : Option UInt64 :=
    if h : n < arr.size then some arr[n] else none
  let inboundsSome : Option UInt64 :=
    if h : 2 < arr.size then some arr[2] else none
  let oobNoneOk := match oobNone with | none => true | some _ => false
  let inboundsOk := match inboundsSome with | some 30 => true | _ => false
  if firstValid == 10 && lastValid == 50 && n == 5
     && oobNoneOk && inboundsOk then 0 else 99
