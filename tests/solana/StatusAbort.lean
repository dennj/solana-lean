/- Status-returning entrypoint: non-zero return aborts and rolls back writes. -/
import Std.Solana

open Std.Solana

namespace StatusAbort

def handler (ctx : ProgramContext) : ProgramResult Unit :=
  match Bytes.readUInt8At? ctx.data 0 with
  | some (0 : UInt8) =>
      let _ := writeDataImpl 0 0 (ByteArray.mk #[0x11])
      let _ := msg! "statusabort: committed write"
      .ok ()
  | _ =>
      let _ := writeDataImpl 0 0 (ByteArray.mk #[0xe4])
      let _ := msg! "statusabort: aborted write"
      .error 0xe4

@[solana_status_entrypoint]
def entry (ctx : ProgramContext) : UInt64 :=
  ProgramResult.entrypoint handler ctx

end StatusAbort
