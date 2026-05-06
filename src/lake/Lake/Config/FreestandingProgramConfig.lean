/-
Copyright (c) 2026 Dennj Osele. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dennj Osele
-/
module

prelude
public import Lake.Build.Facets
public import Lake.Config.LeanConfig
meta import all Lake.Config.Meta
import Lake.Config.Meta

namespace Lake
open Lean System

/--
A freestanding cross-target program's declarative configuration. A
freestanding program is one or more Lean modules cross-compiled to a
bare-metal ELF for an arbitrary LLVM triple, linked alongside user
boot stubs and a linker script.

Used for kernels (RISC-V, ARM bare-metal), embedded controllers, and
microvisors — anywhere a host runtime is unavailable.
-/
public configuration FreestandingProgramConfig (name : Name) extends LeanConfig where
  /-- The subdirectory of the package's source directory containing the
      program's Lean source files. Defaults to said `srcDir`. -/
  srcDir : FilePath := "."

  /-- The Lean module roots cross-compiled into bitcode and linked
      together. The first root is treated as the program's main module
      for naming purposes; all roots' transitive imports are resolved.
      Defaults to a singleton of the target name. -/
  roots : Array Name := #[name]

  /-- Source-root override forwarded to `lean --root=<rootDir>` when
      cross-compiling each module. Use `"."` for kernels whose lakefile
      lives in the same directory as their `.lean` files and whose
      cross-link expects bare module symbol names (e.g.
      `Kernel_Hardware`, not `pkg__Kernel_Hardware`). -/
  rootDir : FilePath := "."

  /-- The file name (with extension) of the linked artifact. Defaults to
      the target name with any `.` replaced with a `-` plus `.elf`. -/
  programName : String := name.toStringWithSep "-" (escape := false) ++ ".elf"

  /-- LLVM target triple to cross-compile for. Defaults to
      `riscv64-unknown-none-elf`. -/
  triple : String := "riscv64-unknown-none-elf"

  /-- Additional source paths (e.g. `boot.S`, `kernel.c`) linked
      alongside the Lean bitcode. Paths are resolved relative to the
      package directory. -/
  extraSources : Array FilePath := #[]

  /-- Path to the linker script (`-T <linkerScript>`). Resolved
      relative to the package directory. -/
  linkerScript : FilePath := "kernel.ld"

  /-- Entry symbol exposed by the boot stub (`-Wl,-e,<entry>`). -/
  entry : String := "_start"

  /-- Extra arguments inserted *before* the linker script and entry
      flags. Use for include paths (e.g. `-I path/to/runtime/headers`). -/
  extraLinkArgs : Array String := #[]

  /-- An `Array` of targets to build before the program's modules. -/
  needs : Array PartialBuildKey := #[]

deriving Inhabited

namespace FreestandingProgramConfig

/-- The program's name. -/
public abbrev name (_ : FreestandingProgramConfig n) := n

end FreestandingProgramConfig
