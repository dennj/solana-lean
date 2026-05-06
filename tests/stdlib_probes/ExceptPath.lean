/-! Probe: `Except` ok / error construction and pattern matching. Exercises
the same ctor-allocation + tag-discriminator codegen used by `IO.Result`
(which is `Except IO.Error`). The stdlib_probes runner expects a non-IO
entry, so we use `Except String` directly; the codegen path is identical. -/

@[noinline]
def divide (a b : UInt64) : Except String UInt64 :=
  if b == 0 then Except.error "div by zero" else Except.ok (a / b)

def chain (a b c : UInt64) : Except String UInt64 := do
  let q1 <- divide a b
  let q2 <- divide q1 c
  pure q2

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let okResult := chain 1000 5 4              -- 1000/5 = 200, 200/4 = 50
  let errResult := chain 1000 0 4             -- first step errors
  let lateErr := chain 1000 5 0               -- second step errors
  let ok :=
    (match okResult with | .ok v => v == 50 | .error _ => false) &&
    (match errResult with | .ok _ => false   | .error msg => msg == "div by zero") &&
    (match lateErr with | .ok _ => false     | .error msg => msg == "div by zero")
  if ok then 0 else 99
