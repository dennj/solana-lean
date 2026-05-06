/- Probe: List α — cons/nil ctors, pattern match, length recursion. -/
partial def myLen (xs : List UInt64) : UInt64 :=
  match xs with
  | [] => 0
  | _ :: t => 1 + myLen t

partial def mySum (xs : List UInt64) : UInt64 :=
  match xs with
  | [] => 0
  | h :: t => h + mySum t

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let xs : List UInt64 := [10, 20, 30, 40, 50]
  let n := myLen xs
  let s := mySum xs
  if n == 5 && s == 150 then 0 else 99
