/- State-changing program: read u64 counter, increment, write back. -/
import Std.Solana

open Std.Solana

namespace Counter

/-- Decode a little-endian uint64 from the first 8 bytes of `bytes`.
    Bytes past the end of the buffer are treated as zero — keeps the
    decoder total without bounds-check noise at every call site. -/
def decodeLeU64 (bytes : ByteArray) : UInt64 := Id.run do
  let mut acc : UInt64 := 0
  for i in [0:8] do
    let b : UInt8 := bytes[i]?.getD 0
    acc := acc ||| (b.toUInt64 <<< (i.toUInt64 * 8))
  acc

/-- Encode a little-endian uint64 into a fresh 8-byte ByteArray. -/
def encodeLeU64 (v : UInt64) : ByteArray := Id.run do
  let mut bs := ByteArray.emptyWithCapacity 8
  for i in [0:8] do
    let shift := (i.toUInt64 * 8)
    bs := bs.push ((v >>> shift).toUInt8)
  bs

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _   := msg! "counter: read+inc+write"
  let cur := decodeLeU64 (readDataImpl 0 0 8)
  let inc := decodeLeU64 ctx.data
  let next := cur + inc
  let _ := writeDataImpl 0 0 (encodeLeU64 next)
  next

end Counter
