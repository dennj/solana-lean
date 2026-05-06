/- Toolchain-free smoke test for cross-compile codegen options. -/
@[export hello_entry]
def helloEntry (x : UInt64) : UInt64 :=
  x + 1
