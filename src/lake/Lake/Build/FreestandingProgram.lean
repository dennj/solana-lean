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
public import Lake.Config.FreestandingProgram
public import Lake.Config.FacetConfig
import Lake.Build.Job.Register
import Lake.Build.Common
import Lake.Build.Infos

/-! # Freestanding Cross-Target Program Build Action

Builds Lean modules into a freestanding ELF binary for bare-metal
targets (RISC-V kernels, embedded controllers, microvisors). -/

namespace Lake
open System

private def elfMagic : ByteArray := ⟨#[0x7f, 0x45, 0x4c, 0x46]⟩

private def mkFreestandingSpec
    (triple : String) (entry : String)
    (extraSources : Array FilePath) (linkerScript : FilePath)
    (extraLinkArgs : Array String)
    : CrossTargetSpec :=
  let linkArgs : Array String :=
    extraLinkArgs ++ #["-T", linkerScript.toString, s!"-Wl,-e,{entry}"]
  { triple        := triple
    outputExt     := "elf"
    entrySymbol   := entry
    extraLinkArgs := linkArgs
    extraSources  := extraSources
    validate      := fun fp => do
      unless ← fp.pathExists do
        error s!"freestanding_program: linker did not produce {fp}"
      let sz := (← fp.metadata).byteSize
      if sz < 4 then
        error s!"freestanding_program: linker produced {sz}-byte file {fp} (too small to be ELF)"
      let h ← IO.FS.Handle.mk fp .read
      let magic ← h.read 4
      unless magic == elfMagic do
        error s!"freestanding_program: {fp} is missing the ELF magic header" }

/--
Build a freestanding cross-target ELF from given Lean modules and auxiliary
sources. Kept for back-compat with the helper-function lakefile shape.
-/
public def buildFreestandingProgram
    (mods          : Array Module)
    (extraSources  : Array FilePath)
    (linkerScript  : FilePath)
    (entry         : String)
    (extraLinkArgs : Array String := #[])
    (triple        : String       := "riscv64-unknown-none-elf")
    (outputName    : String       := "kernel.elf")
    : FetchM (Job FilePath) := do
  let some firstMod := mods[0]?
    | error "buildFreestandingProgram: at least one Lean module is required"
  withRegisterJob s!"{outputName}:freestanding" do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let pkg := firstMod.pkg
    let outDir := pkg.buildDir / "freestanding"
    let outFile := outDir / outputName
    let bcFiles := mods.map fun mod =>
      outDir / s!"{mod.name.toString}.bc"
    let spec := mkFreestandingSpec triple entry extraSources linkerScript extraLinkArgs
    let oleanJobs ← mods.mapM (·.olean.fetch)
    (Job.collectArray oleanJobs "oleans").mapM fun _ => do
      for (mod, bc) in mods.zip bcFiles do
        compileLeanCrossModule bc mod.leanFile spec leanPath lean
      buildCrossProgram outFile bcFiles spec leanc.toString
      pure outFile

/-- Build a `freestanding_program` declaration into a deployable ELF. -/
def FreestandingProgram.recBuildExe (self : FreestandingProgram) : FetchM (Job FilePath) :=
  withRegisterJob s!"{self.name}:elf" <| withCurrPackage self.pkg do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let mods := self.rootModules
    let some firstMod := mods[0]?
      | error s!"freestanding_program '{self.name}': must declare at least one root module"
    let _ := firstMod
    let cfg := self.config
    let outDir := self.pkg.buildDir / "freestanding"
    let outFile := self.file
    let bcFiles := mods.map fun mod => outDir / s!"{mod.name.toString}.bc"
    let spec := mkFreestandingSpec cfg.triple cfg.entry cfg.extraSources cfg.linkerScript cfg.extraLinkArgs
    let rootDir : FilePath := self.pkg.dir / cfg.rootDir
    let oleanJobs ← mods.mapM (·.olean.fetch)
    (Job.collectArray oleanJobs "oleans").mapM fun _ => do
      for (mod, bc) in mods.zip bcFiles do
        compileLeanCrossModule bc mod.leanFile spec leanPath lean (root? := some rootDir)
      buildCrossProgram outFile bcFiles spec leanc.toString
      pure outFile

/-- The facet configuration for the builtin `FreestandingProgram.elfFacet`. -/
public def FreestandingProgram.elfFacetConfig : FreestandingProgramFacetConfig FreestandingProgram.elfFacet :=
  mkFacetJobConfig recBuildExe

def FreestandingProgram.recBuildDefault (self : FreestandingProgram) : FetchM (Job FilePath) :=
  self.elf.fetch

/-- The facet configuration for the freestanding program's default facet. -/
public def FreestandingProgram.defaultFacetConfig : FreestandingProgramFacetConfig defaultFacet :=
  mkFacetJobConfig recBuildDefault (memoize := false)

/-- A name-configuration map for the initial set of freestanding program facets. -/
public def FreestandingProgram.initFacetConfigs : DNameMap FreestandingProgramFacetConfig :=
  DNameMap.empty
  |>.insert defaultFacet defaultFacetConfig
  |>.insert FreestandingProgram.elfFacet elfFacetConfig

end Lake
