/-! Probe: match arms with `if`-style guards in the body and the
`match h : x with` form that retains the discriminator equation. The
codegen lowers each guard arm to a chained `if`, exercising both the
match dispatcher and conditional-branch emission. -/

inductive Reading where
  | none
  | sample (value : UInt64)

def grade (r : Reading) : UInt64 :=
  match r with
  | .none => 0
  | .sample v =>
    if v < 10 then 1
    else if v < 100 then 2
    else if v < 1000 then 3
    else 4

@[noinline]
def safeDivSimple (a b : UInt64) : UInt64 :=
  match b with
  | 0 => 0
  | _ => a / b

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let g0 := grade .none
  let g1 := grade (.sample 5)
  let g2 := grade (.sample 50)
  let g3 := grade (.sample 500)
  let g4 := grade (.sample 5000)
  let d1 := safeDivSimple 100 5
  let d0 := safeDivSimple 100 0
  if g0 == 0 && g1 == 1 && g2 == 2 && g3 == 3 && g4 == 4
     && d1 == 20 && d0 == 0 then 0 else 99
