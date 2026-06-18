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
public import Lake.Config.SolanaProgram
public import Lake.Config.FacetConfig
import Lake.Build.Job.Register
import Lake.Build.Common
import Lake.Build.Infos

/-! # Solana SBF Program Build Action

Builds a Lean module into a deployable Solana SBF `.so` program. -/

namespace Lake
open System

/--
The `CrossTargetSpec` for Solana SBF programs.

* `triple = sbf-solana-solana` — Anza's SBF triple.
* `outputExt = "so"` — Solana programs are loaded as shared objects.
* `entrySymbol = "lean_sol_entry_typed"` — the typed-entrypoint shape
  `(ProgramContext) -> UInt64` that `Std.Solana` exports.
-/
public def solanaSpec : CrossTargetSpec where
  triple      := "sbf-solana-solana"
  outputExt   := "so"
  entrySymbol := "lean_sol_entry_typed"
  validate fp := do
    unless ← fp.pathExists do
      error s!"solana_program: linker did not produce {fp}"
    let sz := (← fp.metadata).byteSize
    if sz == 0 then
      error s!"solana_program: linker produced empty file {fp}"

/--
Run the Solana SBF cross-compile pipeline given a root Lean module path,
the LEAN_PATH search dirs already populated by lake's host build, the
`lean` binary, the `leanc` binary, and the desired output `.so` location.
-/
private def runSolanaCompile
    (rootLean : FilePath) (outFile : FilePath)
    (leanPath : SearchPath) (lean : FilePath) (leanc : FilePath)
    : LogIO Unit := do
  let outDir := outFile.parent.getD ("." : FilePath)
  let bcFile := outDir / FilePath.withExtension outFile.fileName.get! "bc"
  compileLeanCrossModule bcFile rootLean solanaSpec leanPath lean
  buildCrossProgram outFile #[bcFile] solanaSpec leanc.toString

/--
Build a Solana SBF program from a single root module referenced via `target` in
a `lakefile.lean`. Kept for back-compat with the helper-function lakefile shape.
-/
public def buildSolanaProgram (mod : Module) : FetchM (Job FilePath) :=
  withRegisterJob s!"{mod.name}:solana" do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let outFile := mod.pkg.buildDir / "solana" / s!"{mod.name.toString}.so"
    (← mod.olean.fetch).mapM fun _oleanPath => do
      runSolanaCompile mod.leanFile outFile leanPath lean leanc
      pure outFile

/--
Build a `solana_program` declaration into a deployable `.so`.

Pipeline:
1. Fetch the root module's `olean` facet — host build of the program's
   modules so `lean` can resolve `import` when re-invoked for SBF.
2. Run `lean --target=sbf-solana-solana --bc=…` on the root source.
3. Run `leanc --target=sbf-solana-solana … -o …` to link the bitcode.
4. Run the `solanaSpec` validator on the linked artifact.
-/
def SolanaProgram.recBuildExe (self : SolanaProgram) : FetchM (Job FilePath) :=
  withRegisterJob s!"{self.name}:so" <| withCurrPackage self.pkg do
    let leanPath ← getLeanPath
    let lean ← getLean
    let leanc := (← getLeanInstall).leanc
    let outFile := self.file
    (← self.root.olean.fetch).mapM fun _oleanPath => do
      runSolanaCompile self.root.leanFile outFile leanPath lean leanc
      pure outFile

/-- The facet configuration for the builtin `SolanaProgram.soFacet`. -/
public def SolanaProgram.soFacetConfig : SolanaProgramFacetConfig SolanaProgram.soFacet :=
  mkFacetJobConfig recBuildExe

def SolanaProgram.recBuildDefault (self : SolanaProgram) : FetchM (Job FilePath) :=
  self.so.fetch

/-- The facet configuration for the Solana program's default facet. -/
public def SolanaProgram.defaultFacetConfig : SolanaProgramFacetConfig defaultFacet :=
  mkFacetJobConfig recBuildDefault (memoize := false)

/--
A name-configuration map for the initial set of Solana program facets
(`default`, `so`).
-/
public def SolanaProgram.initFacetConfigs : DNameMap SolanaProgramFacetConfig :=
  DNameMap.empty
  |>.insert defaultFacet defaultFacetConfig
  |>.insert SolanaProgram.soFacet soFacetConfig

end Lake
