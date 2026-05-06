/- Diag2: typed entrypoint returns ctx.data[0] as UInt64. -/
import Std.Solana
open Std.Solana

namespace Diag2Byte0

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  (ctx.data[0]?.getD 0).toUInt64
end Diag2Byte0
