/-
Copyright (c) 2026 Dennj Osele. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dennj Osele
-/
module

prelude
public import Lake.Config.Module

namespace Lake
open Lean System

/-- A WebAssembly program -- its package plus its configuration. -/
public abbrev WasmProgram := ConfigTarget WasmProgram.configKind

/-- The WebAssembly programs of the package (as an Array). -/
@[inline] public def Package.wasmPrograms (self : Package) : Array WasmProgram :=
  self.configTargets WasmProgram.configKind

/-- Try to find a WebAssembly program in the package with the given name. -/
@[inline] public def Package.findWasmProgram? (name : Name) (self : Package) : Option WasmProgram :=
  self.findConfigTarget? WasmProgram.configKind name

/-- Convert a WASM program configuration into a single-module Lean
    library configuration, used to build the program's `.olean` files
    before WASM cross-compile. -/
public def WasmProgramConfig.toLeanLibConfig (self : WasmProgramConfig n) : LeanLibConfig n where
  srcDir := self.srcDir
  roots := #[]
  libName := self.programName
  needs := self.needs
  toLeanConfig := self.toLeanConfig

namespace WasmProgram

/-- The program's user-defined configuration. -/
@[inline] public nonrec def config (self : WasmProgram) : WasmProgramConfig self.name :=
  self.config

/-- Convert the program into a Lean library with a single module (the root). -/
@[inline] public def toLeanLib (self : WasmProgram) : LeanLib :=
  ⟨self.pkg, self.name, self.config.toLeanLibConfig⟩

/-- The program's root Lean module. -/
@[inline] public def root (self : WasmProgram) : Module where
  lib := self.toLeanLib
  name := self.config.root

/-- The file name of the linked WASM artifact (`programName` + `.wasm`). -/
@[inline] public def fileName (self : WasmProgram) : FilePath :=
  FilePath.addExtension self.config.programName "wasm"

/-- The path to the linked WASM artifact under the package's `wasm` build dir. -/
@[inline] public def file (self : WasmProgram) : FilePath :=
  self.pkg.buildDir / "wasm" / self.fileName

end WasmProgram

end Lake
