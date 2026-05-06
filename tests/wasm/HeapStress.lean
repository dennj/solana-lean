/- WASM heap stress: 64 array pushes and 32 string concats. -/
import Std.Wasm

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut xs : Array UInt64 := #[]
  for i in [0:64] do
    xs := xs.push i.toUInt64
  let mut s : String := ""
  for _ in [0:32] do
    s := s ++ "x"
  return xs.size.toUInt64 ^^^ s.length.toUInt64
