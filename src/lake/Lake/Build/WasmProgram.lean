/-
Copyright (c) 2026 Dennj Osele. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dennj Osele
-/
module

prelude
public import Lake.Build.CrossProgram
public import Lake.Build.Module
public import Lake.Config.Module
public import Lake.Config.WasmProgram
public import Lake.Config.FacetConfig
import Lake.Build.Job.Register
import Lake.Build.Common
import Lake.Build.Infos

/-! # WebAssembly Program Build Action

Builds a Lean module into a freestanding WASI-preview1 `.wasm` module. -/

namespace Lake
open System

/--
The `CrossTargetSpec` for WebAssembly (WASI-preview1) programs.

* `triple = wasm32-wasip1` for WASI command modules, or
  `wasm32-unknown-unknown` for browser reactor modules.
* `outputExt = "wasm"`
* `entrySymbol` empty — WASM programs use varying entry conventions.
* Validator checks the file begins with the 4-byte magic `\\0asm`.
-/
public def wasmSpec (triple : String := "wasm32-wasip1") : CrossTargetSpec where
  triple    := triple
  outputExt := "wasm"
  validate fp := do
    unless ← fp.pathExists do
      error s!"wasm_program: linker did not produce {fp}"
    let sz := (← fp.metadata).byteSize
    if sz < 4 then
      error s!"wasm_program: linker produced {sz}-byte file {fp} (too small to be WebAssembly)"
    let h ← IO.FS.Handle.mk fp .read
    let magic ← h.read 4
    let expected : ByteArray := ⟨#[0x00, 0x61, 0x73, 0x6d]⟩
    unless magic == expected do
      error s!"wasm_program: {fp} is missing the WebAssembly magic header"

private def runWasmCompile
    (rootLean : FilePath) (outFile : FilePath) (spec : CrossTargetSpec)
    (leanPath : SearchPath) (lean : FilePath) (leanc : FilePath)
    : LogIO Unit := do
  let outDir := outFile.parent.getD ("." : FilePath)
  let bcFile := outDir / FilePath.withExtension outFile.fileName.get! "bc"
  compileLeanCrossModule bcFile rootLean spec leanPath lean
  buildCrossProgram outFile #[bcFile] spec leanc.toString

/--
Build a WebAssembly program from a single root module referenced via `target`
in a `lakefile.lean`. Kept for back-compat.
-/
public def buildWasmProgram (mod : Module) : FetchM (Job FilePath) :=
  withRegisterJob s!"{mod.name}:wasm" do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let outFile := mod.pkg.buildDir / "wasm" / s!"{mod.name.toString}.wasm"
    (← mod.olean.fetch).mapM fun _oleanPath => do
      runWasmCompile mod.leanFile outFile (wasmSpec) leanPath lean leanc
      pure outFile

/-- Build a `wasm_program` declaration into a deployable `.wasm`. -/
def WasmProgram.recBuildExe (self : WasmProgram) : FetchM (Job FilePath) :=
  withRegisterJob s!"{self.name}:wasm" <| withCurrPackage self.pkg do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let outFile := self.file
    let spec := wasmSpec self.config.triple
    (← self.root.olean.fetch).mapM fun _oleanPath => do
      runWasmCompile self.root.leanFile outFile spec leanPath lean leanc
      pure outFile

/-- The facet configuration for the builtin `WasmProgram.wasmFacet`. -/
public def WasmProgram.wasmFacetConfig : WasmProgramFacetConfig WasmProgram.wasmFacet :=
  mkFacetJobConfig recBuildExe

def WasmProgram.recBuildDefault (self : WasmProgram) : FetchM (Job FilePath) :=
  self.wasm.fetch

/-- The facet configuration for the WASM program's default facet. -/
public def WasmProgram.defaultFacetConfig : WasmProgramFacetConfig defaultFacet :=
  mkFacetJobConfig recBuildDefault (memoize := false)

/-- A name-configuration map for the initial set of WASM program facets. -/
public def WasmProgram.initFacetConfigs : DNameMap WasmProgramFacetConfig :=
  DNameMap.empty
  |>.insert defaultFacet defaultFacetConfig
  |>.insert WasmProgram.wasmFacet wasmFacetConfig

end Lake
