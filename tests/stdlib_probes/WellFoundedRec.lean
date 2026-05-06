/-! Probe: well-founded recursion via `termination_by`. The recursive call
on `(n + 2) / 2` is not a constructor projection, so Lean must use the
well-founded fixpoint compiler rather than structural recursion. The
generated code goes through `WellFounded.fix`. -/

def myLog2 : Nat -> Nat
  | 0 => 0
  | 1 => 0
  | n + 2 => 1 + myLog2 ((n + 2) / 2)
decreasing_by
  simp_wf
  omega

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let l1 := myLog2 1     -- 0
  let l2 := myLog2 2     -- 1
  let l4 := myLog2 4     -- 2
  let l16 := myLog2 16   -- 4
  let l100 := myLog2 100 -- 6 (floor log2 100)
  if l1 == 0 && l2 == 1 && l4 == 2 && l16 == 4 && l100 == 6 then 0 else 99
