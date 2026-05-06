/-! Probe: in-place `Array.set!` on a unique-reference array. Exercises
`lean_array_uset` (the exclusive update path) and `lean_is_exclusive`.
Each iteration consumes the previous `arr` and rebinds, so codegen sees
the array as exclusive and avoids copying. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut arr : Array UInt64 := Array.replicate 16 (0 : UInt64)
  for i in [0:16] do
    arr := arr.set! i (i.toUInt64 * 7)
  let s : UInt64 := arr.foldl (· + ·) 0
  -- Sum 7*(0..15) = 7 * 120 = 840
  if arr.size == 16 && s == 840 && arr[0]! == 0 && arr[15]! == 105 then
    return 0
  else
    return 99
