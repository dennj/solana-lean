/-
Copyright (c) 2026 Dennj Osele. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dennj Osele
-/
module

prelude
public import Lake.Util.Log
public import Lake.Util.Proc
public import Lake.Util.IO
public import Lake.Build.Actions
import Init.System.IO
import Init.System.Platform

/-! # Cross-Target Program Build Helpers

Shared scaffolding for building Lean programs that target a non-host triple
(`sbf-solana-solana`, `wasm32-wasip1`, `riscv64-unknown-none-elf`, ...).

The pipeline is identical for every cross-target:

    lean  --target=<triple> --bc=<mod>.bc <Mod>.lean      (per module)
    leanc --target=<triple> <mods>.bc [extra sources] -o <out>

What varies is captured by `CrossTargetSpec`: which triple, which output
extension, which entry symbol, what extra link arguments / sources, and how to
validate the linked artifact.

Per-target wrappers (e.g. `solana_program`, `wasm_program`,
`freestanding_program`) construct a `CrossTargetSpec` and call
`buildCrossProgram` rather than duplicating the pipeline.

This module is internal to Lake — it does not register a new target kind or
DSL keyword. Those live in the per-target files. -/

namespace Lake
open System

/--
Validation hook run on the linked output binary. Implementations should
report failures via `LogIO`; returning `()` means the artifact passed.
-/
public abbrev CrossValidator := FilePath → LogIO Unit

/-- A do-nothing validator: accepts any output binary. -/
public def CrossValidator.trivial : CrossValidator := fun _ => pure ()

/--
Configuration for a cross-compiled Lean program. Captures the per-target
differences so the build pipeline itself stays target-agnostic.

* `triple`        — LLVM target triple, forwarded as `--target=<triple>` to
                    both `lean` and `leanc`.
* `outputExt`     — file extension for the linked artifact (`so`, `wasm`,
                    `elf`). Per-target wrappers use this to derive the
                    on-disk filename.
* `entrySymbol`   — exported entry point the validator expects in the
                    output. Empty disables the check.
* `extraLinkArgs` — extra arguments appended to the `leanc` invocation,
                    *before* the bitcode file list. Used by freestanding
                    targets to pass linker scripts, `--entry`, etc.
* `extraSources`  — additional source paths (e.g. `boot.S`, `kernel.c`) to
                    be linked alongside the Lean bitcode.
* `validate`      — structural / semantic check run on the linked binary,
                    e.g. asserting `EM_BPF` + `DYN` for SBF programs.
-/
public structure CrossTargetSpec where
  triple         : String
  outputExt      : String
  entrySymbol    : String         := ""
  extraLinkArgs  : Array String   := #[]
  extraSources   : Array FilePath := #[]
  validate       : CrossValidator := CrossValidator.trivial
  deriving Inhabited

namespace CrossTargetSpec

/-- The `--target=<triple>` argument expected by both `lean` and `leanc`. -/
public def targetArg (self : CrossTargetSpec) : String :=
  s!"--target={self.triple}"

/--
Arguments to pass to `lean` (the frontend) when emitting bitcode for this
target. Per-target wrappers feed these to `compileLeanModule`'s `leanArgs`
parameter so every module in the program is built with the same triple.
-/
public def leanArgs (self : CrossTargetSpec) : Array String :=
  #[self.targetArg]

/--
Arguments to pass to `leanc` when linking the final binary, *not* including
the bitcode/source file list or the `-o <out>` flag — the caller adds those.
-/
public def leancArgs (self : CrossTargetSpec) : Array String :=
  #[self.targetArg] ++ self.extraLinkArgs

end CrossTargetSpec

/--
Link the given bitcode files (plus `spec.extraSources`) into a single
cross-compiled binary at `outFile` using `leanc --target=<triple>`.

This leaves the process environment intact so target-specific toolchain
discovery (for example Solana platform-tools under `$HOME/.cache/solana`) still
works. Cross-target linkers also inspect bitcode inputs and target flags before
invoking clang, so these arguments are passed directly rather than hidden in a
response file.

The `--target=<triple>` flag tells `leanc` to invoke the platform-specific
clang backend (SBF for Solana, WebAssembly for WASM, freestanding ELF for
bare-metal targets) instead of the host `cc`.
-/
public def linkCrossProgram
    (outFile  : FilePath)
    (bitcodes : Array FilePath)
    (spec     : CrossTargetSpec)
    (leanc    : FilePath := "leanc")
    : LogIO Unit := do
  let inputs : Array String :=
    bitcodes.map FilePath.toString ++ spec.extraSources.map FilePath.toString
  createParentDirs outFile
  proc {
    cmd := leanc.toString
    args := #["-o", outFile.toString] ++ spec.leancArgs ++ inputs
  }

/--
Compile one Lean source file to LLVM bitcode for a cross target.

This is the frontend half of the shell pipeline:

    lean --target=<triple> [--root=<root>] --bc=<out>.bc <Mod>.lean

`root?` (when supplied) is forwarded as `--root=<root>` so the module's
symbol names are derived from the path relative to `<root>` rather than
the package directory — needed by freestanding programs that link
cross-compiled module symbols by their bare names (`Kernel_Hardware`)
rather than package-qualified ones (`pkg__name_Kernel_Hardware`).

The caller is responsible for wiring this into Lake dependencies and for
linking the resulting bitcode with `linkCrossProgram` or `buildCrossProgram`.
-/
public def compileLeanCrossModule
    (bcFile   : FilePath)
    (leanFile : FilePath)
    (spec     : CrossTargetSpec)
    (leanPath : SearchPath := [])
    (lean     : FilePath := "lean")
    (root?    : Option FilePath := none)
    : LogIO Unit := do
  createParentDirs bcFile
  let rootArgs : Array String := match root? with
    | some r => #[s!"--root={r.toString}"]
    | none   => #[]
  proc {
    cmd := lean.toString
    args := spec.leanArgs ++ rootArgs
              ++ #[s!"--bc={bcFile.toString}", leanFile.toString]
    env := #[("LEAN_PATH", leanPath.toString)]
  }

/--
Build a cross-compiled program end-to-end: link `bitcodes` (plus
`spec.extraSources`) into `outFile`, then run the spec's structural
validator.

The validator is the only target-specific step beyond linking — it's what
catches `Stack offset of N exceeded max offset` for SBF, missing entry
symbols, wrong ELF type, or invalid WASM magic. Per-target wrappers
populate `spec.validate`; if they leave it as `CrossValidator.trivial`,
this collapses to a pure link step.
-/
public def buildCrossProgram
    (outFile  : FilePath)
    (bitcodes : Array FilePath)
    (spec     : CrossTargetSpec)
    (leanc    : FilePath := "leanc")
    : LogIO Unit := do
  linkCrossProgram outFile bitcodes spec leanc
  spec.validate outFile

end Lake
