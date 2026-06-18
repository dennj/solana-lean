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
A WebAssembly (WASI-preview1) program target's declarative configuration.
A WASM program is a Lean library cross-compiled to a freestanding `.wasm`
module. Defaults to `wasm32-wasip1`; use `wasm32-unknown-unknown` for the
browser/reactor runtime adapter.
-/
public configuration WasmProgramConfig (name : Name) extends LeanConfig where
  /-- The subdirectory of the package's source directory containing the
      program's Lean source file. Defaults to said `srcDir`. -/
  srcDir : FilePath := "."

  /-- The root module of the WASM program. Should contain a definition
      with `@[export lean_wasm_main]` (or `lean_wasm_main_io`). Defaults
      to the name of the target. -/
  root : Name := name

  /-- The file name (without `.wasm` extension) of the linked artifact.
      Defaults to the target name with any `.` replaced with a `-`. -/
  programName : String := name.toStringWithSep "-" (escape := false)

  /-- LLVM target triple. `wasm32-wasip1` builds a WASI command module;
      `wasm32-unknown-unknown` builds a browser reactor module. -/
  triple : String := "wasm32-wasip1"

  /-- An `Array` of targets to build before the program's modules. -/
  needs : Array PartialBuildKey := #[]

deriving Inhabited

namespace WasmProgramConfig

/-- The program's name. -/
public abbrev name (_ : WasmProgramConfig n) := n

end WasmProgramConfig
