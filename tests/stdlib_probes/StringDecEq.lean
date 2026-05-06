/-! Probe: `String.dec_eq` (`==` on String). Exercises `lean_string_dec_eq`,
`lean_string_length`, and the byte-by-byte UTF-8 comparison loop. Covers
equal strings, unequal-same-length, prefix-difference, length-mismatch,
empty pair, and empty-vs-nonempty. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a := "hello"
  let b := "hello"
  let c := "help"     -- same length, different at index 3
  let d := "hellos"   -- a is a prefix of d
  let e := ""
  let f := ""
  let g := "h"
  let ok :=
    (a == b)        &&    -- equal
    (b == a)        &&    -- symmetric
    !(a == c)       &&    -- unequal at index 3
    !(a == d)       &&    -- length mismatch
    !(d == a)       &&    -- length mismatch reversed
    (e == f)        &&    -- both empty
    !(a == e)       &&    -- nonempty vs empty
    !(e == g)             -- empty vs single char
  if ok then 0 else 99
