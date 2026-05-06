/-! Probe: `deriving BEq` on a custom inductive. The compiler synthesises
a `BEq.beq` method that case-splits the constructors and combines field
comparisons via `&&`. Lowering: each branch becomes a sequence of
`lean_uint64_dec_eq` (or equivalent) calls returning a Bool. -/

inductive Token where
  | num (v : UInt64)
  | sym (s : String)
  | nest (head : UInt64) (tail : List UInt64)
  deriving BEq

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let n1 := Token.num 42
  let n2 := Token.num 42
  let n3 := Token.num 43
  let s1 := Token.sym "lean"
  let s2 := Token.sym "lean"
  let s3 := Token.sym "kernel"
  let nestA := Token.nest 7 [10, 20, 30]
  let nestB := Token.nest 7 [10, 20, 30]
  let nestC := Token.nest 7 [10, 20, 99]
  let ok :=
    (n1 == n2) && !(n1 == n3) && !(n1 == s1) &&
    (s1 == s2) && !(s1 == s3) &&
    (nestA == nestB) && !(nestA == nestC)
  if ok then 0 else 99
