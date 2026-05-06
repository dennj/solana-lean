/-! Probe: `Except` with `throw` / `tryCatch`. Exercises typeclass
resolution for `MonadExcept Except` and the codegen for the
exception-recovery branch. -/

@[noinline]
def divOrThrow (a b : UInt64) : Except String UInt64 :=
  if b == 0 then throw "div by zero" else pure (a / b)

def safeDivWithFallback (a b : UInt64) : Except String UInt64 :=
  tryCatch (divOrThrow a b) (fun _ => pure 0)

def chain (a b c : UInt64) : Except String UInt64 := do
  let q <- divOrThrow a b
  let r <- divOrThrow q c
  pure r

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let r1 := safeDivWithFallback 100 5      -- ok 20
  let r2 := safeDivWithFallback 100 0      -- caught -> ok 0
  let c1 := chain 100 5 4                  -- ok 5
  let c2 := chain 100 0 4                  -- error "div by zero"
  let ok :=
    (match r1 with | .ok 20 => true | _ => false) &&
    (match r2 with | .ok 0 => true | _ => false) &&
    (match c1 with | .ok 5 => true | _ => false) &&
    (match c2 with | .error msg => msg == "div by zero" | _ => false)
  if ok then 0 else 99
