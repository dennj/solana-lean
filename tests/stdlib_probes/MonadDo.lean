/-! Probe: monadic do-notation in `Id`. Exercises codegen for `bind` /
`pure` chains and any partial-application machinery the bind expansion
needs. The stdlib_probes runner expects a non-monadic entry, so we run
the do-block via `Id.run`. The kernel uses the same codegen for
`BaseIO`-typed do-blocks. -/

@[noinline]
def double (n : UInt64) : Id UInt64 := pure (n * 2)

@[noinline]
def addOne (n : UInt64) : Id UInt64 := pure (n + 1)

def chain (start : UInt64) : Id UInt64 := do
  let a <- double start
  let b <- addOne a
  let c <- double b
  let d <- addOne c
  pure d

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let r := Id.run (chain 5)
  -- 5 -> 10 -> 11 -> 22 -> 23
  if r == 23 then 0 else 99
