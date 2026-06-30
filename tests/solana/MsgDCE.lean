/- A leading `msg!` must survive even when followed by a ProgramContext projection. -/
import Std.Solana

open Std.Solana

namespace MsgDCE

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _ := msg! "msgdce: leading log before ctx projection"
  match Bytes.readUInt8At? ctx.data 0 with
  | some b => b.toUInt64
  | none => 0

end MsgDCE
