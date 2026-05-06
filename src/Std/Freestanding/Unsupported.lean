/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

prelude
public meta import Lean.Compiler.UnsupportedOnTargetCmd

/-! Stdlib decls denied at compile time on every freestanding cross-compile
target: filesystem, processes, threads, real-time clock, host environment,
stdin. Triple pattern `*` matches any non-host triple. -/

register_unsupported_on_target IO.FS.readFile      "*" "uses host filesystem"
register_unsupported_on_target IO.FS.writeFile     "*" "uses host filesystem"
register_unsupported_on_target IO.FS.realPath      "*" "uses host filesystem"
register_unsupported_on_target IO.FS.readBinFile   "*" "uses host filesystem"
register_unsupported_on_target IO.FS.writeBinFile  "*" "uses host filesystem"
register_unsupported_on_target IO.FS.createDir     "*" "uses host filesystem"
register_unsupported_on_target IO.FS.createDirAll  "*" "uses host filesystem"
register_unsupported_on_target IO.FS.removeDir     "*" "uses host filesystem"
register_unsupported_on_target IO.FS.removeFile    "*" "uses host filesystem"
register_unsupported_on_target IO.FS.rename        "*" "uses host filesystem"
register_unsupported_on_target IO.FS.lines         "*" "uses host filesystem"

register_unsupported_on_target IO.Process.spawn    "*" "spawns a host process"
register_unsupported_on_target IO.Process.run      "*" "spawns a host process"
register_unsupported_on_target IO.Process.exit     "*" "exits the host process"
register_unsupported_on_target IO.Process.output   "*" "spawns a host process"

register_unsupported_on_target IO.sleep            "*" "blocks on real time"
register_unsupported_on_target IO.monoMsNow        "*" "reads host real time"
register_unsupported_on_target IO.monoNanosNow     "*" "reads host real time"

register_unsupported_on_target IO.getEnv           "*" "reads host environment"
register_unsupported_on_target IO.setEnv           "*" "writes host environment"
register_unsupported_on_target IO.appPath          "*" "reads host filesystem"
register_unsupported_on_target IO.appDir           "*" "reads host filesystem"

register_unsupported_on_target Task.spawn          "*" "requires host threads"
register_unsupported_on_target Task.map            "*" "requires host threads"
register_unsupported_on_target Task.bind           "*" "requires host threads"
register_unsupported_on_target Task.get            "*" "requires host threads"

register_unsupported_on_target IO.getStdin         "*" "reads host stdin"
