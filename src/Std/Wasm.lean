/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

prelude
public import Init.Data.String.Basic
public import Init.Data.ByteArray.Basic
public import Init.Data.Array.Basic
public import Init.System.IO
public import Init.While
public import Std.Wasm.Unsupported

/-! User-facing entry point for writing freestanding WASM programs in Lean 4.
Primitives lower onto the WASI snapshot1 import surface (`fd_write`,
`fd_read`, `proc_exit`, `args_get`, `args_sizes_get`) exposed by
`src/runtime/wasm/` via `lean --target=wasm32-wasip1`. -/

public section

namespace Std.Wasm

/-- Forwards a `String` to WASI `fd_write(stderr, ...)`. -/
@[extern "lean_wasm_log", never_extract]
opaque wasmLogImpl (s : @&String) : BaseIO Unit

/-- Log a message to the host (stderr, with trailing newline). -/
@[inline]
def log (s : String) : BaseIO Unit :=
  wasmLogImpl s

/-- Forwards a `String` to WASI `fd_write(stdout, ...)` (no trailing newline). -/
@[extern "lean_wasm_print", never_extract]
opaque wasmPrintImpl (s : @&String) : BaseIO Unit

/-- Print a string to stdout. -/
@[inline]
def print (s : String) : BaseIO Unit :=
  wasmPrintImpl s

/-- Print a string followed by `\n` to stdout. -/
@[inline]
def println (s : String) : BaseIO Unit := do
  print s
  print "\n"

/-- Reads up to `cap` bytes from WASI `fd_read(stdin, ...)`. Returns the
bytes actually read; an empty `ByteArray` indicates EOF. -/
@[extern "lean_wasm_read_stdin", never_extract]
opaque wasmReadStdinImpl (cap : USize) : BaseIO ByteArray

/-- Read up to `cap` bytes from stdin. -/
@[inline]
def readStdin (cap : USize := 4096) : BaseIO ByteArray :=
  wasmReadStdinImpl cap

/-- Read a UTF-8 string of up to `cap` bytes from stdin. Bytes that are
not well-formed UTF-8 are replaced with U+FFFD. -/
def readStdinString (cap : USize := 4096) : BaseIO String := do
  let bytes ← readStdin cap
  return String.fromUTF8! bytes

/-- Number of program arguments (`argc`-equivalent under WASI
`args_sizes_get`). -/
@[extern "lean_wasm_argc", never_extract]
opaque wasmArgcImpl (_ : Unit) : BaseIO USize

/-- Read the program argument at the given index. Returns the empty string
if the index is out of range. -/
@[extern "lean_wasm_arg", never_extract]
opaque wasmArgImpl (idx : USize) : BaseIO String

/-- The full argument vector exposed to the program by the WASI host. -/
def args : BaseIO (Array String) := do
  let n ← wasmArgcImpl ()
  let mut acc : Array String := Array.empty
  let mut i : USize := 0
  while i < n do
    acc := acc.push (← wasmArgImpl i)
    i := i + 1
  return acc

/-- Terminate the program with the given exit code via WASI `proc_exit`. -/
@[extern "lean_wasm_exit", never_extract]
opaque exit (code : UInt32) : BaseIO Unit

end Std.Wasm
