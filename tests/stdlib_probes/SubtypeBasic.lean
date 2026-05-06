/-! Probe: subtype `{x : T // P x}`. The kernel uses this pattern in
`Std.Solana.Pubkey` (a `ByteArray` paired with a proof that its size is
32). Codegen represents the subtype as a single ctor with the value as
the only object field; the proof is erased. -/

abbrev Bounded := { n : UInt64 // n < 1000 }

def boundedAdd (a b : Bounded) : UInt64 :=
  a.val + b.val

def mkBounded? (n : UInt64) : Option Bounded :=
  if h : n < 1000 then some ⟨n, h⟩ else none

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Bounded := ⟨500, by decide⟩
  let b : Bounded := ⟨300, by decide⟩
  let r := boundedAdd a b
  let made := mkBounded? 42
  let rejected := mkBounded? 5000
  let madeOk := match made with | some v => v.val == 42 | none => false
  let rejectedOk := match rejected with | none => true | some _ => false
  if r == 800 && madeOk && rejectedOk then 0 else 99
