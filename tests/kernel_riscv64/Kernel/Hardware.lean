namespace Kernel.Hardware

@[extern "kernel_store8", never_extract]
opaque store8Impl (addr : UInt64) (value : UInt8) : Unit

@[extern "kernel_store64", never_extract]
opaque store64Impl (addr value : UInt64) : Unit

@[extern "kernel_load8", never_extract]
opaque load8Impl (addr : UInt64) : UInt8

@[extern "kernel_load64", never_extract]
opaque load64Impl (addr : UInt64) : UInt64

@[extern "kernel_write_stvec", never_extract]
opaque writeStvecImpl (addr : UInt64) : Unit

@[extern "kernel_write_satp", never_extract]
opaque writeSatpImpl (satp : UInt64) : Unit

@[extern "kernel_write_sepc", never_extract]
opaque writeSepcImpl (sepc : UInt64) : Unit

@[extern "kernel_set_timer", never_extract]
opaque setTimerImpl (_ : Unit) : Unit

@[extern "kernel_enter_user", never_extract]
opaque enterUserImpl (entry : UInt64) : Unit

@[extern "kernel_sfence_vma", never_extract]
opaque sfenceVmaImpl (_ : Unit) : Unit

@[extern "kernel_probe_breakpoint_trap", never_extract]
opaque probeBreakpointTrapImpl (_ : Unit) : Unit

@[extern "kernel_trap_vector_addr", never_extract]
opaque trapVectorAddrImpl (_ : Unit) : UInt64

@[extern "kernel_deny_bad_page_table_action", never_extract]
opaque denyBadPageTableActionImpl (_ : Unit) : Unit

@[extern "kernel_deny_unhandled_trap", never_extract]
opaque denyUnhandledTrapImpl (scause stval : UInt64) : Unit

@[inline] def store8 (addr : UInt64) (value : UInt8) : BaseIO Unit :=
  pure (store8Impl addr value)

@[inline] def store64 (addr value : UInt64) : BaseIO Unit :=
  pure (store64Impl addr value)

@[inline] def load8 (addr : UInt64) : BaseIO UInt8 :=
  pure (load8Impl addr)

@[inline] def load64 (addr : UInt64) : BaseIO UInt64 :=
  pure (load64Impl addr)

@[inline] def writeStvec (addr : UInt64) : BaseIO Unit :=
  pure (writeStvecImpl addr)

@[inline] def writeSatp (satp : UInt64) : BaseIO Unit :=
  pure (writeSatpImpl satp)

@[inline] def writeSepc (sepc : UInt64) : BaseIO Unit :=
  pure (writeSepcImpl sepc)

@[inline] def setTimer : BaseIO Unit :=
  pure (setTimerImpl ())

@[inline] def enterUser (entry : UInt64) : BaseIO Unit :=
  pure (enterUserImpl entry)

@[inline] def sfenceVma : BaseIO Unit :=
  pure (sfenceVmaImpl ())

@[inline] def probeBreakpointTrap : BaseIO Unit :=
  pure (probeBreakpointTrapImpl ())

@[inline] def trapVectorAddr : BaseIO UInt64 :=
  pure (trapVectorAddrImpl ())

@[inline] def denyBadPageTableAction : BaseIO Unit :=
  pure (denyBadPageTableActionImpl ())

@[inline] def denyUnhandledTrap (scause stval : UInt64) : BaseIO Unit :=
  pure (denyUnhandledTrapImpl scause stval)

def uart0 : UInt64 := 0x10000000

def pageSize : Nat := 4096

def pteSize : Nat := 8

def satpSv39Mode : UInt64 := 8

def satpModeShift : UInt64 := 60

def supervisorTimerScause : UInt64 := 0x8000000000000005

@[inline] def satpSv39 (rootFrame : UInt64) : UInt64 :=
  (satpSv39Mode <<< satpModeShift) ||| rootFrame

def installTrapVector : BaseIO Unit := do
  let addr ← trapVectorAddr
  writeStvec addr

def setSatpSv39 (rootFrame : UInt64) : BaseIO Unit :=
  writeSatp (satpSv39 rootFrame)

@[inline] def putc (c : UInt8) : BaseIO Unit :=
  store8 uart0 c

def writeBytes (bytes : ByteArray) : BaseIO Unit :=
  go bytes.size 0
where
  go : Nat → Nat → BaseIO Unit
    | 0, _ => pure ()
    | fuel + 1, i => do
      if h : i < bytes.size then
        putc bytes[i]
        go fuel (i + 1)
      else
        pure ()

def log (s : String) : BaseIO Unit := do
  writeBytes s.toUTF8
  putc 10

structure Cell (α : Type) where
  private mk ::
  addr : UInt64

namespace Cell

@[inline] def ofAddr {α : Type} (addr : UInt64) : Cell α :=
  Cell.mk addr

end Cell

@[inline] def Cell.getU8 (c : Cell UInt8) : BaseIO UInt8 :=
  load8 c.addr

@[inline] def Cell.setU8 (c : Cell UInt8) (v : UInt8) : BaseIO Unit :=
  store8 c.addr v

@[inline] def Cell.getU64 (c : Cell UInt64) : BaseIO UInt64 :=
  load64 c.addr

@[inline] def Cell.setU64 (c : Cell UInt64) (v : UInt64) : BaseIO Unit :=
  store64 c.addr v

@[inline] def Cell.modifyU64 (c : Cell UInt64) (f : UInt64 → UInt64) : BaseIO Unit := do
  let v ← Cell.getU64 c
  Cell.setU64 c (f v)

end Kernel.Hardware
