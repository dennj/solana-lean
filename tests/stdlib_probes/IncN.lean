/-! Probe: ref-count-by-N path (`lean_inc_n` / `lean_inc_ref_n`). Regression
for the freestanding runtime gap that broke the kernel until `lean_inc_n`
and `lean_inc_ref_n` were added. Codegen emits these when the same value is
consumed multiple times in a body. -/

partial def sumN (xs : List UInt64) (n : Nat) : UInt64 :=
  match n with
  | 0 => 0
  | Nat.succ k =>
    let s := xs.foldl (· + ·) 0
    s + sumN xs k

@[noinline]
def consumeFour (xs : List UInt64) : UInt64 :=
  let a := xs.length
  let b := xs.length
  let c := xs.length
  let d := xs.length
  (a + b + c + d).toUInt64

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let xs : List UInt64 := [1, 2, 3, 4, 5]
  let totalReuses := sumN xs 6
  let lengthReuses := consumeFour xs
  if totalReuses == 90 && lengthReuses == 20 then 0 else 99
