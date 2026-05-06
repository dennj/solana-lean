/-! Probe: `String.push` builds a string one character at a time.
Exercises `lean_string_push`, `lean_string_length`, and the UTF-8
encoding of single-byte ASCII characters. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 := Id.run do
  let mut s : String := ""
  let chars := "hello world".toList
  for c in chars do
    s := s.push c
  let ok :=
    (s == "hello world") &&
    (s.length == 11) &&
    (s.toUTF8.size == 11)
  if ok then return 0 else return 99
