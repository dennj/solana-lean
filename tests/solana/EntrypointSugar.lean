/- `@[solana_entrypoint]` expands to `@[export lean_sol_entry_typed]`. -/
import Std.Solana

open Std.Solana

@[solana_entrypoint]
def entry (ctx : ProgramContext) : UInt64 :=
  let accounts := ctx.accounts.size.toUInt64
  let dataBytes := ctx.data.size.toUInt64
  0x66 ^^^ accounts ^^^ dataBytes
