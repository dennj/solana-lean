/-! Probe: incremental `ByteArray.push` past initial capacity. Exercises
`lean_byte_array_push`, `lean_alloc_sarray`, and `lean_copy_byte_array`.
Each push past the current capacity must reallocate and copy bytes. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut ba : ByteArray := ByteArray.empty
  for i in [0:32] do
    ba := ba.push i.toUInt8
  let n := ba.size
  let s : UInt64 := ba.foldl (fun acc b => acc + b.toUInt64) 0
  -- Sum 0..31 = 31 * 32 / 2 = 496
  if n == 32 && s == 496 && ba[0]! == 0 && ba[31]! == 31 then
    return 0
  else
    return 99
