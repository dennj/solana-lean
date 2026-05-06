/- Typed-entrypoint shape: entry takes a ProgramContext. -/
import Std.Solana

@[export lean_sol_entry_typed]
def entry (ctx : Std.Solana.ProgramContext) : UInt64 :=
  let _ := Std.Solana.msg! "typed entrypoint reached"
  let accounts := ctx.accounts.size.toUInt64
  let dataBytes := ctx.data.size.toUInt64
  let firstByte := (ctx.programId.toBytes.get! 0).toUInt64
  0x77 ^^^ accounts ^^^ dataBytes ^^^ firstByte
