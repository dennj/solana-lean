/- Diag1: typed entrypoint returns a constant. -/
import Std.Solana
open Std.Solana

namespace Diag1Const

@[export lean_sol_entry_typed]
def entry (_ctx : ProgramContext) : UInt64 := 0x2A
end Diag1Const
