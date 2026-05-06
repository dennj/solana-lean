/-! Probe: large allocations within the heap region. Builds a chain of
moderately-sized arrays (256 elements each) and a long list to exercise
the bump allocator under load. Stays well within the SBF default 32 KB
heap; tests heap exhaustion (the panic path) require a separate runner. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut arr : Array UInt64 := Array.empty
  for i in [0:256] do
    arr := arr.push (i.toUInt64)
  let arrSum : UInt64 := arr.foldl (· + ·) 0
  -- 0 + 1 + ... + 255 = 255 * 256 / 2 = 32640
  let mut lst : List UInt64 := []
  for i in [0:128] do
    lst := i.toUInt64 :: lst
  let lstSum : UInt64 := lst.foldl (· + ·) 0
  -- 0 + 1 + ... + 127 = 127 * 128 / 2 = 8128
  if arr.size == 256 && arrSum == 32640
     && lst.length == 128 && lstSum == 8128 then return 0 else return 99
