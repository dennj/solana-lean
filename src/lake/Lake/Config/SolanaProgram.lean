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

/-- A Solana SBF program -- its package plus its configuration. -/
public abbrev SolanaProgram := ConfigTarget SolanaProgram.configKind

/-- The Solana programs of the package (as an Array). -/
@[inline] public def Package.solanaPrograms (self : Package) : Array SolanaProgram :=
  self.configTargets SolanaProgram.configKind

/-- Try to find a Solana program in the package with the given name. -/
@[inline] public def Package.findSolanaProgram? (name : Name) (self : Package) : Option SolanaProgram :=
  self.findConfigTarget? SolanaProgram.configKind name

/--
Convert a Solana program configuration into a single-module Lean library
configuration, used to build the program's `.olean` files before SBF
cross-compile.
-/
public def SolanaProgramConfig.toLeanLibConfig (self : SolanaProgramConfig n) : LeanLibConfig n where
  srcDir := self.srcDir
  roots := #[]
  libName := self.programName
  needs := self.needs
  toLeanConfig := self.toLeanConfig

namespace SolanaProgram

/-- The program's user-defined configuration. -/
@[inline] public nonrec def config (self : SolanaProgram) : SolanaProgramConfig self.name :=
  self.config

/-- Convert the program into a Lean library with a single module (the root). -/
@[inline] public def toLeanLib (self : SolanaProgram) : LeanLib :=
  ⟨self.pkg, self.name, self.config.toLeanLibConfig⟩

/-- The program's root Lean module. -/
@[inline] public def root (self : SolanaProgram) : Module where
  lib := self.toLeanLib
  name := self.config.root

/-- The file name of the linked SBF artifact (`programName` + `.so`). -/
@[inline] public def fileName (self : SolanaProgram) : FilePath :=
  FilePath.addExtension self.config.programName "so"

/-- The path to the linked SBF artifact under the package's `solana` build dir. -/
@[inline] public def file (self : SolanaProgram) : FilePath :=
  self.pkg.buildDir / "solana" / self.fileName

end SolanaProgram

end Lake
