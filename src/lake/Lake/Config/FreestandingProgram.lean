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

/-- A freestanding cross-target program -- its package plus its configuration. -/
public abbrev FreestandingProgram := ConfigTarget FreestandingProgram.configKind

/-- The freestanding programs of the package (as an Array). -/
@[inline] public def Package.freestandingPrograms (self : Package) : Array FreestandingProgram :=
  self.configTargets FreestandingProgram.configKind

/-- Try to find a freestanding program in the package with the given name. -/
@[inline] public def Package.findFreestandingProgram? (name : Name) (self : Package) : Option FreestandingProgram :=
  self.findConfigTarget? FreestandingProgram.configKind name

/-- Convert a freestanding program configuration into a Lean library
    configuration, used to build the program's `.olean` files before
    cross-compile. The lib's roots come from the program's `roots`. -/
public def FreestandingProgramConfig.toLeanLibConfig (self : FreestandingProgramConfig n) : LeanLibConfig n where
  srcDir := self.srcDir
  roots := self.roots
  libName := self.programName
  needs := self.needs
  toLeanConfig := self.toLeanConfig

namespace FreestandingProgram

/-- The program's user-defined configuration. -/
@[inline] public nonrec def config (self : FreestandingProgram) : FreestandingProgramConfig self.name :=
  self.config

/-- Convert the program into a Lean library covering all of its module roots. -/
@[inline] public def toLeanLib (self : FreestandingProgram) : LeanLib :=
  ⟨self.pkg, self.name, self.config.toLeanLibConfig⟩

/-- The program's root Lean modules. -/
@[inline] public def rootModules (self : FreestandingProgram) : Array Module :=
  let lib := self.toLeanLib
  self.config.roots.map fun rootName => { lib, name := rootName }

/-- The file name of the linked artifact (`programName` as supplied). -/
@[inline] public def fileName (self : FreestandingProgram) : FilePath :=
  FilePath.mk self.config.programName

/-- The path to the linked artifact under the package's `freestanding` build dir. -/
@[inline] public def file (self : FreestandingProgram) : FilePath :=
  self.pkg.buildDir / "freestanding" / self.fileName

end FreestandingProgram

end Lake
