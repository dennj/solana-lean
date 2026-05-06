/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Siddharth Bhat
-/
module

prelude
public meta import Lean.Compiler.UnsupportedOnTarget
public meta import Lean.Elab.Command

public section

namespace Lean

open Lean.Elab.Command in
/--
Mark `decl` as unsupported when compiling for any target whose triple matches
`pattern`, surfacing `reason` to the user. Useful for denying stdlib decls
(e.g. `IO.FS.readFile`) on restricted-runtime targets without patching upstream.

```
register_unsupported_on_target IO.FS.readFile "sbf-*" "uses host filesystem"
```
-/
elab "register_unsupported_on_target" decl:ident pattern:str reason:str : command => do
  modifyEnv (Compiler.unsupportedOnTargetExt.addEntry · (decl.getId,
    { triplePattern := pattern.getString, reason := reason.getString }))

end Lean
