/- Diag3: decode a little-endian UInt64 from ctx.data via for-loop. -/
import Std.Solana
open Std.Solana

namespace Diag3Decode

def decodeLeU64 (bytes : ByteArray) : UInt64 := Id.run do
  let mut acc : UInt64 := 0
  for i in [0:8] do
    let b : UInt8 := bytes[i]?.getD 0
    acc := acc ||| (b.toUInt64 <<< (i.toUInt64 * 8))
  acc

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  decodeLeU64 ctx.data
end Diag3Decode
