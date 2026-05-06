/-! Probe: `@[inline]` propagation. Inlined functions disappear at -O2;
the resulting code should compute the constant directly with no extra
function calls. The `@[noinline]` wrapper prevents whole-program
constant folding from collapsing the test. -/

@[inline] def addOne (n : UInt64) : UInt64 := n + 1
@[inline] def double (n : UInt64) : UInt64 := n * 2
@[inline] def addThenDouble (a b : UInt64) : UInt64 := double (addOne (a + b))

@[noinline] def topLevel (a b : UInt64) : UInt64 :=
  addThenDouble a b

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  -- topLevel 5 7 = double (addOne (5 + 7)) = double 13 = 26
  let r := topLevel 5 7
  if r == 26 then 0 else 99
