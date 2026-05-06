/-! Probe: ByteArray capacity growth across multiple reallocations. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut ba : ByteArray := ByteArray.empty
  for i in [0:256] do
    ba := ba.push (i.toUInt8)
  let n := ba.size
  let mut mismatches : UInt64 := 0
  for i in [0:256] do
    if ba[i]! != (i.toUInt8) then
      mismatches := mismatches + 1
  if n == 256 && mismatches == 0 then return 0 else return 99
