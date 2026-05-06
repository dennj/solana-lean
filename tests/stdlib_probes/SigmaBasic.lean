/-! Probe: dependent pair `Σ x : α, β x`. Codegen represents the Sigma
ctor as two object fields (the index value and the dependent value).
Both `fst` and `snd` projections must compose correctly. -/

def mkPair (n : UInt64) : Σ k : UInt64, UInt64 :=
  ⟨n, n * 2⟩

def sumPair (p : Σ _ : UInt64, UInt64) : UInt64 :=
  p.fst + p.snd

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let p := mkPair 7
  let s := sumPair p
  -- 7 + (7 * 2) = 21
  if p.fst == 7 && p.snd == 14 && s == 21 then 0 else 99
