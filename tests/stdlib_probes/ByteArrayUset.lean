/-! Probe: in-place `ByteArray.set!` on a unique-reference scalar array.
Exercises `lean_byte_array_uset`, `lean_byte_array_fget`, and the
exclusive-write path. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut ba : ByteArray := ⟨Array.replicate 8 (0 : UInt8)⟩
  for i in [0:8] do
    ba := ba.set! i (i.toUInt8 + 100)
  let n := ba.size
  let s : UInt64 := ba.foldl (fun acc b => acc + b.toUInt64) 0
  -- 100 + 101 + ... + 107 = 8 * 100 + 28 = 828
  if n == 8 && s == 828 && ba[0]! == 100 && ba[7]! == 107 then
    return 0
  else
    return 99
