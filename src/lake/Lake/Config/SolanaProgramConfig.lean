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
A Solana SBF program target's declarative configuration. A Solana program
is a Lean library cross-compiled to a deployable `sbf-solana-solana` `.so`.
-/
public configuration SolanaProgramConfig (name : Name) extends LeanConfig where
  /--
  The subdirectory of the package's source directory containing the program's
  Lean source file. Defaults to said `srcDir`.
  -/
  srcDir : FilePath := "."

  /--
  The root module of the Solana program. Should contain a definition
  marked with `@[export lean_sol_entry_typed]` typed
  `(ProgramContext) → UInt64`. Defaults to the name of the target.
  -/
  root : Name := name

  /--
  The file name (without `.so` extension) of the linked SBF artifact.
  Defaults to the target name with any `.` replaced with a `-`.
  -/
  programName : String := name.toStringWithSep "-" (escape := false)

  /-- An `Array` of targets to build before the program's modules. -/
  needs : Array PartialBuildKey := #[]

deriving Inhabited

namespace SolanaProgramConfig

/-- The program's name. -/
public abbrev name (_ : SolanaProgramConfig n) := n

end SolanaProgramConfig
