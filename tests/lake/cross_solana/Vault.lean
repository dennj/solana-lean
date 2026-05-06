import Std.Solana

/-! Minimal Solana program used to exercise the `solana_program` build path.

    Mirrors the shape of `tests/solana/Counter.lean` — entry point with the
    canonical `lean_sol_entry_typed` export — so the same `lake build`
    pipeline that serves real programs is exercised end-to-end here. -/

open Std.Solana

namespace Vault

@[export lean_sol_entry_typed]
def entry (_ : ProgramContext) : UInt64 :=
  let _ := msg! "vault: hello from lake build"
  0x77

end Vault
