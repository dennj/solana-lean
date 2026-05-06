/-! Probe: mutual recursion (even/odd). -/
mutual
  partial def isEven (n : UInt64) : Bool :=
    if n == 0 then true else isOdd (n - 1)

  partial def isOdd (n : UInt64) : Bool :=
    if n == 0 then false else isEven (n - 1)
end

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let ok :=
    isEven 0 && !isOdd 0 &&
    !isEven 7 && isOdd 7 &&
    isEven 10 && !isOdd 10
  if ok then 0 else 99
