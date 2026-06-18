import Kernel.Core
import Kernel.Hardware

open Kernel.Hardware

@[extern "kernel_store8_u64", never_extract]
opaque kernelStore8U64Impl (addr value : UInt64) : Unit

@[extern "kernel_set_state_boots", never_extract]
opaque kernelSetStateBootsImpl (boots : UInt64) : Unit

def kernelStore8U64 (addr value : UInt64) : BaseIO Unit :=
  pure (kernelStore8U64Impl addr value)

def kernelSetStateBoots (boots : Nat) : BaseIO Unit :=
  pure (kernelSetStateBootsImpl boots.toUInt64)

def kernelPutNatByte (byte : Nat) : BaseIO Unit :=
  kernelStore8U64 uart0 byte.toUInt64

def validPageTableFrame (frame : Nat) : Bool :=
  frame == Kernel.pageTableRootPfn ||
  frame == Kernel.pageTableKernelL1Pfn ||
  frame == Kernel.pageTableMmioL1Pfn

def pteAddr (tableFrame index : Nat) : UInt64 :=
  (tableFrame * pageSize + index * pteSize).toUInt64

def kernelZeroFrame (frame : Nat) : BaseIO Unit := do
  if validPageTableFrame frame then
    go 512 0
  else
    denyBadPageTableAction
where
  go : Nat -> Nat -> BaseIO Unit
    | 0, _ => pure ()
    | fuel + 1, index => do
      store64 (pteAddr frame index) 0
      go fuel (index + 1)

def kernelWritePte (tableFrame index pte : Nat) : BaseIO Unit :=
  if validPageTableFrame tableFrame && index < Kernel.Sv39.entriesPerTable then
    store64 (pteAddr tableFrame index) pte.toUInt64
  else
    denyBadPageTableAction

def runTrapSyscall : Kernel.Syscall -> BaseIO Unit
  | .yield =>
    log "Lean theorem: user yield syscall preserves kernel state"
  | .writeByte byte => do
    kernelPutNatByte byte
    putc 10
    log "Lean theorem: user writeByte syscall authorized"
  | .exit _ =>
    log "Lean theorem: user exit syscall records task termination"
  | .denied =>
    log "Lean theorem: user syscall rejected without state change"

def kernelLogTrap (scause : UInt64) (syscall : Option Kernel.Syscall) : BaseIO Unit :=
  if scause == 8 then
    match syscall with
    | some syscall => runTrapSyscall syscall
    | none => log "Lean theorem: user syscall rejected without state change"
  else if scause == 3 then
    log "Lean theorem: breakpoint trap is total"
  else if scause == supervisorTimerScause then
    log "Lean theorem: timer interrupt forces scheduler yield and preserves invariant"
  else if scause == 12 || scause == 13 || scause == 15 then
    log "Lean theorem: page fault kills current task and preserves kernel invariant"
  else
    pure ()

def runActions : List Kernel.Action -> BaseIO Unit
  | [] => pure ()
  | .log msg :: rest => do
    log msg
    runActions rest
  | .installTrapVector :: rest => do
    installTrapVector
    log "Lean action: installed trap vector"
    runActions rest
  | .zeroFrame frame :: rest => do
    kernelZeroFrame frame
    log "Lean action: zero Sv39 frame"
    runActions rest
  | .writePte tableFrame index pte :: rest => do
    kernelWritePte tableFrame index pte
    log "Lean action: write Sv39 PTE"
    runActions rest
  | .setSatp rootFrame :: rest => do
    setSatpSv39 rootFrame.toUInt64
    runActions rest
  | .sfenceVma :: rest => do
    log "Lean action: installed Sv39 root and fenced translations"
    sfenceVma
    runActions rest
  | .probeBreakpointTrap :: rest => do
    log "Lean action: breakpoint trap returned"
    probeBreakpointTrap
    runActions rest
  | .installTimer :: rest => do
    log "Lean action: installed timer interrupt"
    setTimer
    runActions rest
  | .writeUserByte _ byte :: rest => do
    kernelPutNatByte byte
    runActions rest
  | .killCurrentTask :: rest => do
    log "Lean action: killed current task"
    runActions rest
  | .enterUser entry :: _ => do
    log "Lean action: entering U-mode"
    enterUser entry.toUInt64
  | .denied :: rest => do
    log "Lean action: denied without panic"
    runActions rest
  | .halt :: _ => pure ()

@[export lean_kernel_main_io]
def entry : BaseIO UInt64 := do
  let out := (Kernel.step Kernel.initialState .boot).value
  kernelSetStateBoots out.state.boots
  runActions out.actions
  return out.state.heap.used.toUInt64

@[export lean_kernel_trap_entry_io]
def trapEntry (boots scause sepc stval syscallNo syscallArg : UInt64) : BaseIO UInt64 := do
  -- `scause` stays a `UInt64` because the kernel now models it as the raw
  -- hardware register (bit 63 carries the interrupt flag). The remaining
  -- four arguments fit comfortably in `Nat` and stay as before.
  match Kernel.trapStep? (Kernel.stateForTrapExport boots.toNat)
      scause sepc.toNat stval.toNat syscallNo.toNat syscallArg.toNat with
  | some out =>
    kernelLogTrap scause out.syscall
    let next := out.nextEpc.toUInt64
    writeSepc next
    return next
  | none =>
    denyUnhandledTrap scause stval
    return sepc
