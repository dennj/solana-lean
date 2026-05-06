/-
Copyright (c) 2022 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.Util.Trace

public section

namespace Lean.Compiler

register_builtin_option compiler.check : Bool := {
  defValue := false
  descr    := "type check code after each compiler step (this is useful for debugging purses)"
}

register_builtin_option compiler.traceUnnormalized : Bool := {
  defValue := false
  descr    := "don't normalize declarations before tracing them at each pipeline step (this is \
    useful for debugging purposes)"
}

register_builtin_option compiler.checkMeta : Bool := {
  defValue := true
  descr := "Check that `meta` declarations only refer to other `meta` declarations and ditto for \
    non-`meta` declarations. Disabling this option may lead to delayed compiler errors and is
    intended only for debugging purposes."
}

register_builtin_option compiler.relaxedMetaCheck : Bool := {
  defValue := false
  descr := "Allow mixed `meta`/non-`meta` references in the same module. References to imports are unaffected."
}

register_builtin_option compiler.ignoreBorrowAnnotation : Bool := {
  defValue := false
  descr := "Ignore user defined borrow inference annotations. This is useful for export/extern \
    forward declarations"
}

register_builtin_option compiler.postponeCompile : Bool := {
  defValue := false
  descr := "Internal. Toggle experimental `leanir` separate compilation."
}

register_builtin_option compiler.inLeanIR : Bool := {
  defValue := false
  descr := "Internal. Indicates whether the compiler is currently running in `leanir`."
}

register_builtin_option compiler.target : String := {
  defValue := ""
  descr := "LLVM target triple to cross-compile for (empty = host). When set, \
    the LLVM backend tags the module with this triple and uses its canonical data layout."
}

register_builtin_option compiler.runtime : String := {
  defValue := "host"
  descr := "Lean runtime to link into the emitted bitcode: \"host\" links \
    `lean.h.bc`; \"none\" emits bitcode for a target that supplies its own runtime \
    at link time. `--target=<triple>` sets this to \"none\" automatically."
}

register_builtin_option compiler.crossImports : String := {
  defValue := ""
  descr := "Module name to prepend to every elaborated file's imports. \
    Used by cross-compile target packages to inject a deny-list / target-policy \
    module that must be active regardless of the user file's own imports. \
    A package that needs multiple should ship an umbrella module that imports them."
}

end Lean.Compiler
