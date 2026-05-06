/- Linked .so retains sol_invoke_signed_c. -/
import Std.Solana

open Std.Solana

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _ := msg! "invoke shape demo"
  let metas : Array AccountMeta := ctx.accounts.map fun a =>
    { pubkey := a.key, isWritable := false, isSigner := false }
  let inst : Instruction :=
    { programId := ctx.programId, accounts := metas, data := ByteArray.mk #[0x77] }
  let _ := invokeSignedImpl inst Array.empty
  0x77
