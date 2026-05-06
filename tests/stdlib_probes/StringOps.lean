/-! Probe: String operations (length, ++, toUTF8). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let s1 := "hello"
  let s2 := "world"
  let combined := s1 ++ " " ++ s2
  let bytes := combined.toUTF8
  let ok :=
    (s1.length == 5) &&
    (s2.length == 5) &&
    (combined.length == 11) &&
    (bytes.size == 11)
  if ok then 0 else 99
