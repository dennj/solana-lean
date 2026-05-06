/-! Probe: incremental `Array.push` past initial capacity. Exercises
`lean_array_push`, `lean_copy_expand_array`, and `lean_alloc_array`.
Empty array starts at capacity 0, so each push past the current capacity
forces a reallocation+copy. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut arr : Array UInt64 := Array.empty
  for i in [0:64] do
    arr := arr.push i.toUInt64
  let n := arr.size
  let s : UInt64 := arr.foldl (· + ·) 0
  -- Sum 0..63 = 63 * 64 / 2 = 2016
  if n == 64 && s == 2016 && arr[0]! == 0 && arr[63]! == 63 then return 0 else return 99
