/-! Probe: do-notation in `Option`. Each `<-` desugars to a pattern match
on `some` / `none`; `none` short-circuits. Exercises typeclass resolution
for `Monad Option` and the same bind/pure codegen as Id/BaseIO. -/

@[noinline]
def safeDiv (a b : UInt64) : Option UInt64 :=
  if b == 0 then none else some (a / b)

def chain (a b c : UInt64) : Option UInt64 := do
  let q1 <- safeDiv a b
  let q2 <- safeDiv q1 c
  pure q2

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let ok := chain 1000 5 4              -- 1000/5 = 200; 200/4 = 50
  let firstFail := chain 1000 0 4       -- short-circuit on first
  let secondFail := chain 1000 5 0      -- short-circuit on second
  let allOk :=
    (match ok with | some 50 => true | _ => false) &&
    (match firstFail with | none => true | _ => false) &&
    (match secondFail with | none => true | _ => false)
  if allOk then 0 else 99
