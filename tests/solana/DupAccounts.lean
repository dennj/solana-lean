/- Exercises the duplicate-account path of lean_sbf_make_program_context. -/
import Std.Solana

@[export lean_sol_entry_typed]
def entry (ctx : Std.Solana.ProgramContext) : UInt64 :=
  let _ := Std.Solana.msg! "dup-accounts entrypoint reached"
  let n := ctx.accounts.size.toUInt64
  let dataLen := ctx.data.size.toUInt64
  let pidLen := ctx.programId.toBytes.size.toUInt64
  0x55 ^^^ n ^^^ dataLen ^^^ pidLen
