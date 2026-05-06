import Kernel.Memory

namespace Kernel

structure Heap where
  capacity : Nat
  used : Nat
  allocated : List Nat

def totalAllocated : List Nat -> Nat
  | [] => 0
  | n :: ns => n + totalAllocated ns

def Accounted (h : Heap) : Prop :=
  h.used = totalAllocated h.allocated ∧ h.used ≤ h.capacity

def align8 (n : Nat) : Nat :=
  ((n + 7) / 8) * 8

def Heap.allocUnchecked (h : Heap) (size : Nat) : Heap :=
  { h with used := h.used + align8 size, allocated := align8 size :: h.allocated }

def Heap.alloc? (h : Heap) (size : Nat) : Option Heap :=
  if h.used + align8 size ≤ h.capacity then some (h.allocUnchecked size) else none

structure BumpAllocator where
  base : Nat
  cursor : Nat
  endAddr : Nat
  prefixBytes : Nat

def BumpAllocator.start (b : BumpAllocator) : Nat :=
  b.base + b.prefixBytes

def BumpAllocator.nextCursor (b : BumpAllocator) : Nat := b.cursor

def BumpAllocator.capacity (b : BumpAllocator) : Nat :=
  b.endAddr - b.start

def BumpAllocator.used (b : BumpAllocator) : Nat :=
  b.nextCursor - b.start

def BumpAllocator.WF (b : BumpAllocator) : Prop :=
  b.start ≤ b.nextCursor ∧ b.nextCursor ≤ b.endAddr

def BumpAllocator.alloc? (b : BumpAllocator) (size : Nat) :
    Option (Nat × BumpAllocator) :=
  let cursor := b.nextCursor
  let aligned := align8 size
  if cursor + aligned ≤ b.endAddr then
    some (cursor, { b with cursor := cursor + aligned })
  else
    none

structure BumpRefinesHeap (b : BumpAllocator) (h : Heap) : Prop where
  wf : b.WF
  capacity_eq : h.capacity = b.capacity
  used_eq : h.used = b.used
  accounted : Accounted h

theorem bump_alloc_refines_alloc {b b' : BumpAllocator} {h : Heap}
    {addr size : Nat} (href : BumpRefinesHeap b h)
    (hbump : b.alloc? size = some (addr, b')) :
    ∃ h',
      h.alloc? size = some h' ∧
        BumpRefinesHeap b' h' ∧
        addr = b.nextCursor ∧
        b'.nextCursor = b.nextCursor + align8 size := by
  by_cases hfit : b.nextCursor + align8 size ≤ b.endAddr
  · simp [BumpAllocator.alloc?, hfit] at hbump
    rcases hbump with ⟨rfl, rfl⟩
    have hHeapFit : h.used + align8 size ≤ h.capacity := by
      rw [href.used_eq, href.capacity_eq]
      simp [BumpAllocator.used, BumpAllocator.capacity]
      have hstart := href.wf.1
      omega
    refine ⟨h.allocUnchecked size, ?_, ?_, rfl, ?_⟩
    · simp [Heap.alloc?, hHeapFit]
    · refine
        { wf := ?_
          capacity_eq := ?_
          used_eq := ?_
          accounted := by
            rcases href.accounted with ⟨hused, _⟩
            constructor
            · simp [Heap.allocUnchecked, totalAllocated, hused]
              omega
            · simpa [Heap.allocUnchecked] using hHeapFit }
      · constructor
        · simp [BumpAllocator.nextCursor]
          exact Nat.le_trans href.wf.1 (Nat.le_add_right _ _)
        · simp [BumpAllocator.nextCursor]
          exact hfit
      · simpa [Heap.allocUnchecked, BumpAllocator.capacity, BumpAllocator.start] using
          href.capacity_eq
      · dsimp [Heap.allocUnchecked, BumpAllocator.used, BumpAllocator.nextCursor,
          BumpAllocator.start]
        rw [href.used_eq]
        dsimp [BumpAllocator.used, BumpAllocator.nextCursor, BumpAllocator.start]
        have hstart : b.base + b.prefixBytes ≤ b.cursor := by
          simpa [BumpAllocator.start, BumpAllocator.nextCursor] using href.wf.1
        omega
    · rfl
  · simp [BumpAllocator.alloc?, hfit] at hbump

def BumpAllocRefinesAlloc : Prop :=
  ∀ {b b' : BumpAllocator} {h : Heap} {addr size : Nat},
    BumpRefinesHeap b h →
    b.alloc? size = some (addr, b') →
    ∃ h',
      h.alloc? size = some h' ∧
        BumpRefinesHeap b' h' ∧
        addr = b.nextCursor ∧
        b'.nextCursor = b.nextCursor + align8 size

inductive TrapCause where
  | breakpoint
  | userEcall
  | timerInterrupt
  | pageFault
  | unknown

inductive Syscall where
  | yield
  | writeByte : Nat -> Syscall
  | exit : Nat -> Syscall
  | denied

def syscallYield : Nat := 0
def syscallWriteByte : Nat := 1
def syscallExit : Nat := 2

def decodeSyscall (number arg : Nat) : Syscall :=
  if number = syscallYield then .yield
  else if number = syscallWriteByte ∧ arg < 256 then .writeByte arg
  else if number = syscallExit then .exit arg
  else .denied

structure Trap where
  cause : TrapCause
  epc : Nat
  tval : Nat
  syscall : Option Syscall

def isPageFaultScause (scause : Nat) : Prop :=
  scause = 12 ∨ scause = 13 ∨ scause = 15

def supervisorTimerScause : Nat := 0x8000000000000005

@[simp] private theorem breakpointScause_ne_supervisorTimerScause :
    3 ≠ supervisorTimerScause := by decide

@[simp] private theorem supervisorTimerScause_ne_breakpointScause :
    supervisorTimerScause ≠ 3 := by decide

@[simp] private theorem userEcallScause_ne_supervisorTimerScause :
    8 ≠ supervisorTimerScause := by decide

@[simp] private theorem supervisorTimerScause_ne_userEcallScause :
    supervisorTimerScause ≠ 8 := by decide

@[simp] private theorem pageFaultInstructionScause_ne_supervisorTimerScause :
    12 ≠ supervisorTimerScause := by decide

@[simp] private theorem supervisorTimerScause_ne_pageFaultInstructionScause :
    supervisorTimerScause ≠ 12 := by decide

@[simp] private theorem pageFaultLoadScause_ne_supervisorTimerScause :
    13 ≠ supervisorTimerScause := by decide

@[simp] private theorem supervisorTimerScause_ne_pageFaultLoadScause :
    supervisorTimerScause ≠ 13 := by decide

@[simp] private theorem pageFaultStoreScause_ne_supervisorTimerScause :
    15 ≠ supervisorTimerScause := by decide

@[simp] private theorem supervisorTimerScause_ne_pageFaultStoreScause :
    supervisorTimerScause ≠ 15 := by decide

private instance isPageFaultScause_decidable (scause : Nat) :
    Decidable (isPageFaultScause scause) := by
  unfold isPageFaultScause
  infer_instance

@[simp] private theorem isPageFaultScause_iff (scause : Nat) :
    isPageFaultScause scause ↔ scause = 12 ∨ scause = 13 ∨ scause = 15 := by
  rfl

def decodeTrap (scause sepc stval syscallNo syscallArg : Nat) : Trap :=
  { cause :=
      if scause = 3 then .breakpoint
      else if scause = 8 then .userEcall
      else if isPageFaultScause scause then .pageFault
      else if scause = supervisorTimerScause then .timerInterrupt
      else .unknown,
    epc := sepc,
    tval := stval,
    syscall := if scause = 8 then some (decodeSyscall syscallNo syscallArg) else none }

def trapNextEpc? (trap : Trap) : Option Nat :=
  match trap.cause with
  | .breakpoint => some (trap.epc + 4)
  | .userEcall => some (trap.epc + 4)
  | .timerInterrupt => none
  | .pageFault => none
  | .unknown => none

inductive Event where
  | boot
  | trap : Trap -> Event

inductive TaskId where
  | task0
  | task1

def TaskId.next : TaskId -> TaskId
  | .task0 => .task1
  | .task1 => .task0

inductive Action where
  | log : String -> Action
  | installTrapVector
  | zeroFrame : Nat -> Action
  | writePte : Nat -> Nat -> Nat -> Action
  | setSatp : Nat -> Action
  | sfenceVma
  | probeBreakpointTrap
  | installTimer
  | writeUserByte : TaskId -> Nat -> Action
  | killCurrentTask
  | enterUser : Nat -> Action
  | denied
  | halt

inductive KernelError where
  | heapExhausted
  | memoryMapFailed
  | trapRejected

inductive KernelResult (α : Type) where
  | ok : α -> KernelResult α
  | error : KernelError -> α -> KernelResult α

def KernelResult.value : KernelResult α -> α
  | .ok value => value
  | .error _ value => value

inductive TaskStatus where
  | runnable
  | exited

structure Task where
  entry : Nat
  pc : Nat
  status : TaskStatus
  writes : List Nat
  exitCode : Option Nat

def bootTask : Task :=
  { entry := userEntry, pc := userEntry, status := .runnable, writes := [], exitCode := none }

def taskAfterSyscall (task : Task) : Syscall -> Task
  | .yield => task
  | .writeByte byte => { task with writes := byte :: task.writes }
  | .exit code => { task with status := .exited, exitCode := some code }
  | .denied => task

def pageFaultExitCode : Nat := 255

def killTask (task : Task) : Task :=
  { task with status := .exited, exitCode := some pageFaultExitCode }

structure SchedulerState where
  task0 : Task
  task1 : Task
  current : TaskId

def bootScheduler : SchedulerState :=
  { task0 := bootTask, task1 := bootTask, current := .task0 }

def SchedulerState.taskById (scheduler : SchedulerState) : TaskId -> Task
  | .task0 => scheduler.task0
  | .task1 => scheduler.task1

def SchedulerState.currentTask (scheduler : SchedulerState) : Task :=
  scheduler.taskById scheduler.current

def SchedulerState.updateTask (scheduler : SchedulerState) (id : TaskId) (task : Task) :
    SchedulerState :=
  match id with
  | .task0 => { scheduler with task0 := task }
  | .task1 => { scheduler with task1 := task }

def SchedulerState.updateCurrentTask (scheduler : SchedulerState) (task : Task) :
    SchedulerState :=
  scheduler.updateTask scheduler.current task

def SchedulerState.advance (scheduler : SchedulerState) : SchedulerState :=
  { scheduler with current := scheduler.current.next }

def schedulerAfterSyscall (scheduler : SchedulerState) (syscall : Syscall) : SchedulerState :=
  let updated := scheduler.updateCurrentTask (taskAfterSyscall scheduler.currentTask syscall)
  match syscall with
  | .yield => updated.advance
  | .exit _ => updated.advance
  | .writeByte _ => updated
  | .denied => updated

def schedulerAfterPageFault (scheduler : SchedulerState) : SchedulerState :=
  (scheduler.updateCurrentTask (killTask scheduler.currentTask)).advance

@[simp] private theorem schedulerAfterSyscall_yield_current (scheduler : SchedulerState) :
    (schedulerAfterSyscall scheduler .yield).current = scheduler.current.next := by
  cases scheduler with
  | mk task0 task1 current =>
    cases current <;>
      simp [schedulerAfterSyscall, SchedulerState.advance, SchedulerState.updateCurrentTask,
        SchedulerState.updateTask, SchedulerState.currentTask, SchedulerState.taskById,
        TaskId.next, taskAfterSyscall]

@[simp] private theorem schedulerAfterPageFault_current (scheduler : SchedulerState) :
    (schedulerAfterPageFault scheduler).current = scheduler.current.next := by
  cases scheduler with
  | mk task0 task1 current =>
    cases current <;>
      simp [schedulerAfterPageFault, SchedulerState.advance, SchedulerState.updateCurrentTask,
        SchedulerState.updateTask, SchedulerState.currentTask, SchedulerState.taskById,
        TaskId.next]

@[simp] private theorem schedulerAfterPageFault_kills_current (scheduler : SchedulerState) :
    ((schedulerAfterPageFault scheduler).taskById scheduler.current).status = .exited := by
  cases scheduler with
  | mk task0 task1 current =>
    cases current <;>
      simp [schedulerAfterPageFault, SchedulerState.advance, SchedulerState.updateCurrentTask,
        SchedulerState.updateTask, SchedulerState.currentTask, SchedulerState.taskById,
        TaskId.next, killTask]

structure State where
  heap : Heap
  memory : Memory
  boots : Nat
  task : Task
  scheduler : SchedulerState

structure StepOutput where
  state : State
  actions : List Action

def kernelHeapBase : Nat := 0x80303000
def kernelHeapBytes : Nat := 0x80000
def kernelHeapPrefix : Nat := 8
def kernelHeapCapacity : Nat := kernelHeapBytes - kernelHeapPrefix

def initialBumpAllocator : BumpAllocator :=
  { base := kernelHeapBase, cursor := kernelHeapBase + kernelHeapPrefix,
    endAddr := kernelHeapBase + kernelHeapBytes, prefixBytes := kernelHeapPrefix }

def initialHeap : Heap :=
  { capacity := kernelHeapCapacity, used := 0, allocated := [] }

theorem initial_heap_refines_initial_bump_allocator :
    BumpRefinesHeap initialBumpAllocator initialHeap := by
  refine
    { wf := ?_
      capacity_eq := ?_
      used_eq := ?_
      accounted := ?_ }
  · simp [BumpAllocator.WF, BumpAllocator.start, BumpAllocator.nextCursor,
      initialBumpAllocator, kernelHeapBase, kernelHeapBytes, kernelHeapPrefix]
  · simp [initialHeap, initialBumpAllocator, kernelHeapCapacity, BumpAllocator.capacity,
      BumpAllocator.start, kernelHeapBase, kernelHeapBytes, kernelHeapPrefix]
  · simp [initialHeap, initialBumpAllocator, BumpAllocator.used, BumpAllocator.nextCursor,
      BumpAllocator.start, kernelHeapBase, kernelHeapPrefix]
  · simp [Accounted, initialHeap, totalAllocated, kernelHeapCapacity]

def initialState : State :=
  { heap := initialHeap, memory := initialMemory, boots := 0, task := bootTask,
    scheduler := bootScheduler }

def bootAllocBytes : Nat := 256

@[simp] private theorem bootAllocBytes_le_kernelHeapCapacity :
    bootAllocBytes ≤ kernelHeapCapacity := by
  decide

def bootHeap : Heap :=
  { capacity := initialHeap.capacity, used := bootAllocBytes, allocated := [bootAllocBytes] }

def bootPlan : Sv39.MapPlan :=
  Sv39.buildMapPlan pageTableRootPfn pageTableKernelL1Pfn pageTableMmioL1Pfn kernelPfn
    kernelNextPfn uartPfn clintPfn userPfn kernelVpn kernelNextVpn uartVpn clintVpn userVpn

def bootMemory : Memory :=
  { frames :=
      { free := [],
        used := [pageTableMmioL1Pfn, pageTableKernelL1Pfn, pageTableRootPfn,
          kernelPfn, kernelNextPfn, userPfn, uartPfn, clintPfn] },
    pageTable :=
      { entries :=
          [{ vpn := clintVpn, pfn := clintPfn, flags := mmioFlags },
            { vpn := uartVpn, pfn := uartPfn, flags := mmioFlags },
            { vpn := userVpn, pfn := userPfn, flags := userFlags },
            { vpn := kernelVpn, pfn := kernelPfn, flags := kernelFlags }] } }

def bootActions : List Action :=
  [.log "hello from Lean kernel",
    .log "Lean theorem: boot heap has exact allocation accounting",
    .installTrapVector,
    .installTimer,
    .log "Lean action: build Sv39 page tables",
    .zeroFrame bootPlan.rootFrame,
    .zeroFrame bootPlan.kernelL1Frame,
    .zeroFrame bootPlan.mmioL1Frame,
    .writePte bootPlan.rootFrame bootPlan.kernelRootIndex bootPlan.kernelRootPte,
    .writePte bootPlan.rootFrame bootPlan.uartRootIndex bootPlan.uartRootPte,
    .writePte bootPlan.kernelL1Frame bootPlan.kernelBaseIndex bootPlan.kernelBasePte,
    .writePte bootPlan.kernelL1Frame bootPlan.kernelNextIndex bootPlan.kernelNextPte,
    .writePte bootPlan.kernelL1Frame bootPlan.userIndex bootPlan.userPte,
    .writePte bootPlan.mmioL1Frame bootPlan.uartIndex bootPlan.uartPte,
    .writePte bootPlan.mmioL1Frame bootPlan.clintIndex bootPlan.clintPte,
    .setSatp bootPlan.rootFrame,
    .sfenceVma,
    .log "Lean theorem: boot Sv39 identity mapping is live",
    .probeBreakpointTrap,
    .log "Lean theorem: hardware breakpoint trap returned after paging",
    .log "Lean theorem: boot Sv39 page-table actions are validated",
    .log "Lean theorem: boot frame allocator preserves accounting",
    .log "Lean theorem: boot page-table frames are not free",
    .log "Lean theorem: user code page is mapped for U-mode",
    .log "Lean theorem: boot page walk resolves mapped frame",
    .log "Lean theorem: boot preserves kernel invariant",
    .enterUser userEntry]

def bootOutput (s : State) : StepOutput :=
  { state :=
      { heap := bootHeap, memory := bootMemory, boots := s.boots + 1, task := bootTask,
        scheduler := bootScheduler },
    actions := bootActions }

def natEq : Nat -> Nat -> Bool
  | 0, 0 => true
  | n + 1, m + 1 => natEq n m
  | _, _ => false

@[simp] private theorem natEq_self (n : Nat) : natEq n n = true := by
  induction n with
  | zero => simp [natEq]
  | succ n ih => simpa [natEq] using ih

def bootable (s : State) : Bool :=
  natEq s.boots 0 &&
    natEq (frameAccount s.memory.frames) (frameAccount initialMemory.frames)

def failClosed (s : State) (err : KernelError) : KernelResult StepOutput :=
  .error err { state := s, actions := [.log "kernel operation denied without panic", .denied] }

def stateAfterPageFault (s : State) : State :=
  { s with
    task := killTask s.task,
    scheduler := schedulerAfterPageFault s.scheduler }

def stateAfterTimerInterrupt (s : State) : State :=
  { s with scheduler := schedulerAfterSyscall s.scheduler .yield }

@[simp] private theorem stateAfterPageFault_heap (s : State) :
    (stateAfterPageFault s).heap = s.heap := by
  rfl

@[simp] private theorem stateAfterPageFault_memory (s : State) :
    (stateAfterPageFault s).memory = s.memory := by
  rfl

@[simp] private theorem stateAfterPageFault_boots (s : State) :
    (stateAfterPageFault s).boots = s.boots := by
  rfl

@[simp] private theorem stateAfterPageFault_task (s : State) :
    (stateAfterPageFault s).task = killTask s.task := by
  rfl

@[simp] private theorem stateAfterPageFault_scheduler (s : State) :
    (stateAfterPageFault s).scheduler = schedulerAfterPageFault s.scheduler := by
  rfl

@[simp] private theorem bootable_stateAfterPageFault (s : State) :
    bootable (stateAfterPageFault s) = bootable s := by
  simp [bootable, stateAfterPageFault]

@[simp] private theorem stateAfterTimerInterrupt_heap (s : State) :
    (stateAfterTimerInterrupt s).heap = s.heap := by
  rfl

@[simp] private theorem stateAfterTimerInterrupt_memory (s : State) :
    (stateAfterTimerInterrupt s).memory = s.memory := by
  rfl

@[simp] private theorem stateAfterTimerInterrupt_boots (s : State) :
    (stateAfterTimerInterrupt s).boots = s.boots := by
  rfl

@[simp] private theorem stateAfterTimerInterrupt_task (s : State) :
    (stateAfterTimerInterrupt s).task = s.task := by
  rfl

@[simp] private theorem stateAfterTimerInterrupt_scheduler (s : State) :
    (stateAfterTimerInterrupt s).scheduler = schedulerAfterSyscall s.scheduler .yield := by
  rfl

@[simp] private theorem bootable_stateAfterTimerInterrupt (s : State) :
    bootable (stateAfterTimerInterrupt s) = bootable s := by
  simp [bootable, stateAfterTimerInterrupt]

def handleSyscall (s : State) : Syscall -> KernelResult StepOutput
  | .yield =>
    let nextScheduler := schedulerAfterSyscall s.scheduler Syscall.yield;
    let nextState := { s with scheduler := nextScheduler };
    KernelResult.ok
      (StepOutput.mk nextState [.log "Lean theorem: user yield syscall preserves kernel state"])
  | .writeByte byte =>
    if byte < 256 then
      let nextScheduler := schedulerAfterSyscall s.scheduler (.writeByte byte);
      let nextState :=
        { s with
          task := taskAfterSyscall s.task (.writeByte byte),
          scheduler := nextScheduler };
      KernelResult.ok (StepOutput.mk nextState [
        .writeUserByte s.scheduler.current byte,
        .log "Lean theorem: user writeByte syscall authorized"])
    else
      KernelResult.ok
        (StepOutput.mk s [.log "Lean theorem: user syscall rejected without state change"])
  | .exit code =>
    let nextScheduler := schedulerAfterSyscall s.scheduler (.exit code);
    let nextState :=
      { s with
        task := taskAfterSyscall s.task (.exit code),
        scheduler := nextScheduler };
    KernelResult.ok
      (StepOutput.mk nextState [.log "Lean theorem: user exit syscall records task termination"])
  | .denied =>
    KernelResult.ok
      (StepOutput.mk s [.log "Lean theorem: user syscall rejected without state change"])

def handleTrap (s : State) (trap : Trap) : KernelResult StepOutput :=
  match trap.cause with
  | .breakpoint =>
    .ok { state := s, actions := [.log "Lean theorem: breakpoint trap is total"] }
  | .timerInterrupt =>
    .ok (StepOutput.mk (stateAfterTimerInterrupt s) [.installTimer,
      .log "Lean theorem: timer interrupt forces scheduler yield and preserves invariant"])
  | .userEcall =>
    match trap.syscall with
    | some syscall => handleSyscall s syscall
    | none => handleSyscall s .denied
  | .pageFault =>
    .ok (StepOutput.mk (stateAfterPageFault s) [.killCurrentTask,
      .log "Lean theorem: page fault kills current task and preserves kernel invariant"])
  | .unknown => failClosed s .trapRejected

structure TrapStepOutput where
  state : State
  nextEpc : Nat
  syscall : Option Syscall

def step (s : State) : Event -> KernelResult StepOutput
  | .boot => .ok (bootOutput s)
  | .trap trap => handleTrap s trap

def stateForTrapExport (boots : Nat) : State :=
  { (step initialState .boot).value.state with boots }

def trapStep? (s : State) (scause sepc stval syscallNo syscallArg : Nat) :
    Option TrapStepOutput :=
  let trap := decodeTrap scause sepc stval syscallNo syscallArg
    match step s (.trap trap) with
  | .ok out =>
    match trap.cause with
    | .timerInterrupt =>
      some (TrapStepOutput.mk out.state out.state.scheduler.currentTask.pc trap.syscall)
    | .pageFault =>
      some (TrapStepOutput.mk out.state out.state.scheduler.currentTask.pc trap.syscall)
    | _ =>
      match trapNextEpc? trap with
      | some nextEpc => some { state := out.state, nextEpc, syscall := trap.syscall }
      | none => none
  | .error _ _ => none

structure KernelInvariant (s : State) : Prop where
  heapAccounted : Accounted s.heap
  memorySafe : MemoryInvariant s.memory

@[simp] private theorem kernelInvariant_stateAfterPageFault (s : State) :
    KernelInvariant (stateAfterPageFault s) ↔ KernelInvariant s := by
  constructor
  · intro h
    constructor
    · simpa using h.heapAccounted
    · simpa using h.memorySafe
  · intro h
    constructor
    · simpa using h.heapAccounted
    · simpa using h.memorySafe

@[simp] private theorem kernelInvariant_stateAfterTimerInterrupt (s : State) :
    KernelInvariant (stateAfterTimerInterrupt s) ↔ KernelInvariant s := by
  constructor
  · intro h
    constructor
    · simpa using h.heapAccounted
    · simpa using h.memorySafe
  · intro h
    constructor
    · simpa using h.heapAccounted
    · simpa using h.memorySafe

inductive RawEvent where
  | boot
  | trap : Nat -> Nat -> Nat -> Nat -> Nat -> RawEvent

def decodeRawEvent : RawEvent -> Event
  | .boot => .boot
  | .trap scause sepc stval syscallNo syscallArg =>
    .trap (decodeTrap scause sepc stval syscallNo syscallArg)

def concreteStep (s : State) (raw : RawEvent) : KernelResult StepOutput :=
  step s (decodeRawEvent raw)

structure AbstractState where
  boots : Nat
  frameAccount : Nat
  bootable : Bool

def erase (s : State) : AbstractState :=
  { boots := s.boots, frameAccount := frameAccount s.memory.frames, bootable := bootable s }

def Refines (s : State) (a : AbstractState) : Prop :=
  a = erase s

def ResourceLedger (s : State) : Nat :=
  frameAccount s.memory.frames

@[simp] private theorem erase_stateAfterPageFault (s : State) :
    erase (stateAfterPageFault s) = erase s := by
  simp [erase]

@[simp] private theorem erase_stateAfterTimerInterrupt (s : State) :
    erase (stateAfterTimerInterrupt s) = erase s := by
  simp [erase]

@[simp] private theorem resourceLedger_stateAfterPageFault (s : State) :
    ResourceLedger (stateAfterPageFault s) = ResourceLedger s := by
  simp [ResourceLedger]

@[simp] private theorem resourceLedger_stateAfterTimerInterrupt (s : State) :
    ResourceLedger (stateAfterTimerInterrupt s) = ResourceLedger s := by
  simp [ResourceLedger]

inductive Obs where
  | log : String -> Obs
  | writeUserByte : Nat -> Obs
  | enterUser : Nat -> Obs
  | denied
  | halt

def observeAction : Action -> List Obs
  | .log msg => [.log msg]
  | .writeUserByte _ byte => [.writeUserByte byte]
  | .enterUser entry => [.enterUser entry]
  | .denied => [.denied]
  | .halt => [.halt]
  | _ => []

def observeActions : List Action -> List Obs
  | [] => []
  | action :: actions => observeAction action ++ observeActions actions

def RawEvent.isUserEcall : RawEvent -> Prop
  | .trap 8 _ _ _ _ => True
  | _ => False

def RawEvent.isBreakpoint : RawEvent -> Prop
  | .trap 3 _ _ _ _ => True
  | _ => False

def RawEvent.isPageFault : RawEvent -> Prop
  | .trap scause _ _ _ _ => isPageFaultScause scause
  | _ => False

def RawEvent.isTimerInterrupt : RawEvent -> Prop
  | .trap scause _ _ _ _ => scause = supervisorTimerScause
  | _ => False

def RawEvent.isWriteByte (raw : RawEvent) (byte : Nat) : Prop :=
  match raw with
  | .trap 8 _ _ syscallNo syscallArg =>
    decodeSyscall syscallNo syscallArg = .writeByte byte
  | _ => False

private theorem decodeSyscall_writeByte_lt {number arg byte : Nat}
    (h : decodeSyscall number arg = .writeByte byte) :
    byte < 256 := by
  unfold decodeSyscall at h
  by_cases hyield : number = syscallYield
  · simp [hyield] at h
  · by_cases hwrite : number = syscallWriteByte ∧ arg < 256
    · have hwrite' := hwrite
      rcases hwrite with ⟨_, harg⟩
      simp [hwrite'] at h
      cases h
      exact harg
    · by_cases hexit : number = syscallExit
      · subst number
        simp [syscallYield, syscallWriteByte, syscallExit] at h
      · simp [hyield, hwrite, hexit] at h

def userExitEvent : RawEvent :=
  .trap 8 0 0 syscallExit 0

def taskAfterRaw (task : Task) : RawEvent -> Task
  | .boot => bootTask
  | .trap 8 _ _ syscallNo syscallArg => taskAfterSyscall task (decodeSyscall syscallNo syscallArg)
  | .trap scause _ _ _ _ =>
    if isPageFaultScause scause then killTask task
    else if scause = supervisorTimerScause then task else task

def taskAfterEvents : Task -> List RawEvent -> Task
  | task, [] => task
  | task, raw :: events => taskAfterEvents (taskAfterRaw task raw) events

def schedulerAfterRaw (scheduler : SchedulerState) : RawEvent -> SchedulerState
  | .boot => bootScheduler
  | .trap 8 _ _ syscallNo syscallArg =>
    schedulerAfterSyscall scheduler (decodeSyscall syscallNo syscallArg)
  | .trap scause _ _ _ _ =>
    if isPageFaultScause scause then schedulerAfterPageFault scheduler
    else if scause = supervisorTimerScause then schedulerAfterSyscall scheduler .yield else scheduler

def schedulerAfterEvents : SchedulerState -> List RawEvent -> SchedulerState
  | scheduler, [] => scheduler
  | scheduler, raw :: events => schedulerAfterEvents (schedulerAfterRaw scheduler raw) events

def schedulerYieldEvent : RawEvent :=
  .trap 8 0 0 syscallYield 0

def schedulerTimerEvent : RawEvent :=
  .trap supervisorTimerScause 0 0 0 0

def bootCount : List RawEvent -> Nat
  | [] => 0
  | .boot :: events => bootCount events + 1
  | .trap _ _ _ _ _ :: events => bootCount events

inductive AuthorityCause where
  | kernelBoot
  | trapHandler
  | userSyscall : TaskId -> AuthorityCause
  | failClosed

def CauseAllows (_a : AbstractState) (raw : RawEvent) :
    AuthorityCause -> Obs -> Prop
  | .kernelBoot, .log _ => raw = .boot
  | .kernelBoot, .enterUser _ => raw = .boot
  | .trapHandler, .log _ =>
    raw.isBreakpoint ∨ raw.isUserEcall ∨ raw.isTimerInterrupt ∨ raw.isPageFault
  | .userSyscall _, .writeUserByte byte => raw.isWriteByte byte
  | .userSyscall _, .log _ => raw.isUserEcall
  | .userSyscall _, .denied => raw.isUserEcall
  | .failClosed, .log _ => True
  | .failClosed, .denied => True
  | .failClosed, .halt => True
  | _, _ => False

def ActionCauseAllows (_a : AbstractState) (raw : RawEvent) :
    AuthorityCause -> Action -> Prop
  | .kernelBoot, .log _ => raw = .boot
  | .kernelBoot, .installTrapVector => raw = .boot
  | .kernelBoot, .zeroFrame _ => raw = .boot
  | .kernelBoot, .writePte _ _ _ => raw = .boot
  | .kernelBoot, .setSatp _ => raw = .boot
  | .kernelBoot, .sfenceVma => raw = .boot
  | .kernelBoot, .probeBreakpointTrap => raw = .boot
  | .kernelBoot, .installTimer => raw = .boot
  | .kernelBoot, .enterUser _ => raw = .boot
  | .trapHandler, .log _ =>
    raw.isBreakpoint ∨ raw.isUserEcall ∨ raw.isTimerInterrupt ∨ raw.isPageFault
  | .trapHandler, .installTimer => raw.isTimerInterrupt
  | .trapHandler, .killCurrentTask => raw.isPageFault
  | .userSyscall task, .writeUserByte source byte => source = task ∧ raw.isWriteByte byte
  | .userSyscall _, .log _ => raw.isUserEcall
  | .userSyscall _, .denied => raw.isUserEcall
  | .failClosed, .log _ => True
  | .failClosed, .denied => True
  | .failClosed, .halt => True
  | _, _ => False

def TraceHasAuthorityProvenance (a : AbstractState) (raw : RawEvent)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs -> ∃ cause, CauseAllows a raw cause ob

def ActionsAuthorized (a : AbstractState) (raw : RawEvent)
    (actions : List Action) : Prop :=
  TraceHasAuthorityProvenance a raw (observeActions actions)

def AbstractOkNext (a : AbstractState) : RawEvent -> AbstractState
  | .boot => { a with boots := a.boots + 1, bootable := false }
  | .trap _ _ _ _ _ => a

inductive AbstractStep (a : AbstractState) (raw : RawEvent) :
    AbstractState -> List Obs -> Prop
  | ok {a' : AbstractState} {obs : List Obs} :
      a' = AbstractOkNext a raw ->
      TraceHasAuthorityProvenance a raw obs ->
      AbstractStep a raw a' obs
  | rejected {obs : List Obs} :
      TraceHasAuthorityProvenance a raw obs ->
      AbstractStep a raw a obs

inductive ConcreteRun : State -> List RawEvent -> State -> List Obs -> Prop
  | nil (s : State) : ConcreteRun s [] s []
  | ok {s : State} {raw : RawEvent} {out : StepOutput} {events : List RawEvent}
      {final : State} {obsTail : List Obs} :
      concreteStep s raw = .ok out ->
      ConcreteRun out.state events final obsTail ->
      ConcreteRun s (raw :: events) final (observeActions out.actions ++ obsTail)
  | error {s : State} {raw : RawEvent} {err : KernelError} {out : StepOutput}
      {events : List RawEvent} {final : State} {obsTail : List Obs} :
      concreteStep s raw = .error err out ->
      ConcreteRun out.state events final obsTail ->
      ConcreteRun s (raw :: events) final (observeActions out.actions ++ obsTail)

structure RunOutput where
  state : State
  obs : List Obs

def runKernel : State -> List RawEvent -> RunOutput
  | s, [] => { state := s, obs := [] }
  | s, raw :: events =>
    let out := (concreteStep s raw).value
    let rest := runKernel out.state events
    { state := rest.state, obs := observeActions out.actions ++ rest.obs }

theorem runKernel_concreteRun (s : State) (events : List RawEvent) :
    ConcreteRun s events (runKernel s events).state (runKernel s events).obs := by
  induction events generalizing s with
  | nil =>
    exact ConcreteRun.nil s
  | cons raw events ih =>
    cases hstep : concreteStep s raw with
    | ok out =>
      simpa [runKernel, hstep, KernelResult.value] using
        ConcreteRun.ok hstep (ih out.state)
    | error err out =>
      simpa [runKernel, hstep, KernelResult.value] using
        ConcreteRun.error hstep (ih out.state)

theorem ConcreteRun.append {s mid final : State} {events₁ events₂ : List RawEvent}
    {obs₁ obs₂ : List Obs} (h₁ : ConcreteRun s events₁ mid obs₁)
    (h₂ : ConcreteRun mid events₂ final obs₂) :
    ConcreteRun s (events₁ ++ events₂) final (obs₁ ++ obs₂) := by
  induction h₁ with
  | nil _ => simpa using h₂
  | ok hstep _ ih => simpa [List.append_assoc] using ConcreteRun.ok hstep (ih h₂)
  | error hstep _ ih => simpa [List.append_assoc] using ConcreteRun.error hstep (ih h₂)

theorem ConcreteRun.deterministic {s : State} {events : List RawEvent}
    {final₁ final₂ : State} {obs₁ obs₂ : List Obs}
    (h₁ : ConcreteRun s events final₁ obs₁)
    (h₂ : ConcreteRun s events final₂ obs₂) :
    final₁ = final₂ ∧ obs₁ = obs₂ := by
  induction h₁ generalizing final₂ obs₂ with
  | nil s =>
    cases h₂
    exact ⟨rfl, rfl⟩
  | ok hstep₁ htail₁ ih =>
    cases h₂ with
    | ok hstep₂ htail₂ =>
      rw [hstep₁] at hstep₂
      cases hstep₂
      rcases ih htail₂ with ⟨hfinal, hobs⟩
      exact ⟨hfinal, by simp [hobs]⟩
    | error hstep₂ _ =>
      rw [hstep₁] at hstep₂
      contradiction
  | error hstep₁ htail₁ ih =>
    cases h₂ with
    | ok hstep₂ _ =>
      rw [hstep₁] at hstep₂
      contradiction
    | error hstep₂ htail₂ =>
      rw [hstep₁] at hstep₂
      cases hstep₂
      rcases ih htail₂ with ⟨hfinal, hobs⟩
      exact ⟨hfinal, by simp [hobs]⟩

theorem runKernel_unique_concreteRun (s : State) (events : List RawEvent)
    {final : State} {obs : List Obs}
    (h : ConcreteRun s events final obs) :
    final = (runKernel s events).state ∧ obs = (runKernel s events).obs :=
  ConcreteRun.deterministic h (runKernel_concreteRun s events)

theorem runKernel_append (s : State) (events₁ events₂ : List RawEvent) :
    runKernel s (events₁ ++ events₂) =
      let first := runKernel s events₁
      let second := runKernel first.state events₂
      { state := second.state, obs := first.obs ++ second.obs } := by
  induction events₁ generalizing s with
  | nil =>
    simp [runKernel]
  | cons raw events ih =>
    simp [runKernel, ih, List.append_assoc]

inductive AbstractRun : AbstractState -> List RawEvent -> AbstractState -> List Obs -> Prop
  | nil (a : AbstractState) : AbstractRun a [] a []
  | cons {a a' final : AbstractState} {raw : RawEvent} {events : List RawEvent}
      {obs obsTail : List Obs} :
      AbstractStep a raw a' obs ->
      AbstractRun a' events final obsTail ->
      AbstractRun a (raw :: events) final (obs ++ obsTail)

theorem AbstractRun.append {a mid final : AbstractState} {events₁ events₂ : List RawEvent}
    {obs₁ obs₂ : List Obs} (h₁ : AbstractRun a events₁ mid obs₁)
    (h₂ : AbstractRun mid events₂ final obs₂) :
    AbstractRun a (events₁ ++ events₂) final (obs₁ ++ obs₂) := by
  induction h₁ with
  | nil _ => simpa using h₂
  | cons hstep _ ih => simpa [List.append_assoc] using AbstractRun.cons hstep (ih h₂)

def TraceHasRunProvenance (a : AbstractState) (events : List RawEvent)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs -> ∃ raw, raw ∈ events ∧ ∃ cause, CauseAllows a raw cause ob

theorem TraceHasRunProvenance.append {a : AbstractState}
    {events₁ events₂ : List RawEvent} {obs₁ obs₂ : List Obs}
    (h₁ : TraceHasRunProvenance a events₁ obs₁)
    (h₂ : TraceHasRunProvenance a events₂ obs₂) :
    TraceHasRunProvenance a (events₁ ++ events₂) (obs₁ ++ obs₂) := by
  intro ob hob
  simp at hob
  rcases hob with hob | hob
  · rcases h₁ ob hob with ⟨raw, hraw, hcause⟩
    exact ⟨raw, by simp [hraw], hcause⟩
  · rcases h₂ ob hob with ⟨raw, hraw, hcause⟩
    exact ⟨raw, by simp [hraw], hcause⟩

structure KernelRunSound (c0 : State) (a0 : AbstractState)
    (events : List RawEvent) (final : State) (obs : List Obs) : Prop where
  concreteRun : ConcreteRun c0 events final obs
  abstractRun : ∃ abstractFinal, AbstractRun a0 events abstractFinal obs ∧
    Refines final abstractFinal
  invariantFinal : KernelInvariant final
  resourcesConserved : ResourceLedger final = ResourceLedger c0
  traceProvenance : TraceHasRunProvenance a0 events obs

theorem KernelRunSound.append {c0 mid final : State} {a0 : AbstractState}
    {events₁ events₂ : List RawEvent} {obs₁ obs₂ : List Obs}
    (h₁ : KernelRunSound c0 a0 events₁ mid obs₁)
    (h₂ : KernelRunSound mid (erase mid) events₂ final obs₂) :
    KernelRunSound c0 a0 (events₁ ++ events₂) final (obs₁ ++ obs₂) := by
  rcases h₁.abstractRun with ⟨aMid, hAbs₁, hRefMid⟩
  rcases h₂.abstractRun with ⟨aFinal, hAbs₂, hRefFinal⟩
  change aMid = erase mid at hRefMid
  subst aMid
  refine
    { concreteRun := ConcreteRun.append h₁.concreteRun h₂.concreteRun
      abstractRun := ?_
      invariantFinal := h₂.invariantFinal
      resourcesConserved := ?_
      traceProvenance := ?_ }
  · exact ⟨aFinal, AbstractRun.append hAbs₁ hAbs₂, hRefFinal⟩
  · rw [h₂.resourcesConserved, h₁.resourcesConserved]
  · exact TraceHasRunProvenance.append h₁.traceProvenance
      (by
        intro ob hob
        rcases h₂.traceProvenance ob hob with ⟨raw, hraw, hcause⟩
        exact ⟨raw, hraw, hcause⟩)

def HardwareTrapAdmissible : RawEvent -> Prop
  | .trap _ _ _ _ _ => True
  | .boot => False

structure HardwareTrapEvent where
  scause : Nat
  sepc : Nat
  stval : Nat
  syscallNo : Nat
  syscallArg : Nat

def HardwareTrapEvent.toRaw (trap : HardwareTrapEvent) : RawEvent :=
  .trap trap.scause trap.sepc trap.stval trap.syscallNo trap.syscallArg

structure TrapTrace where
  traps : List HardwareTrapEvent

def TrapTrace.events (trace : TrapTrace) : List RawEvent :=
  trace.traps.map HardwareTrapEvent.toRaw

def TrapTrace.append (first second : TrapTrace) : TrapTrace :=
  { traps := first.traps ++ second.traps }

structure HardwareTrace where
  traps : List HardwareTrapEvent

def HardwareTrace.tail (trace : HardwareTrace) : TrapTrace :=
  { traps := trace.traps }

def HardwareTrace.events (trace : HardwareTrace) : List RawEvent :=
  .boot :: trace.tail.events

def ObservationsSatisfy (obs : List Obs) (allowed : Obs -> Prop) : Prop :=
  ∀ ob, ob ∈ obs -> allowed ob

def TrapTrace.ObservationPolicy (trace : TrapTrace) (a : AbstractState)
    (allowed : Obs -> Prop) : Prop :=
  ∀ trap cause ob, trap ∈ trace.traps -> CauseAllows a trap.toRaw cause ob ->
    allowed ob

def HardwareTrace.ObservationPolicy (trace : HardwareTrace) (a : AbstractState)
    (allowed : Obs -> Prop) : Prop :=
  (∀ cause ob, CauseAllows a .boot cause ob -> allowed ob) ∧
    ∀ trap cause ob, trap ∈ trace.traps -> CauseAllows a trap.toRaw cause ob ->
      allowed ob

structure CertifiedTrapExecution (s : State) (trace : TrapTrace)
    (final : State) (obs : List Obs)
    (stateAllowed : AbstractState -> Prop) (obsAllowed : Obs -> Prop) : Prop where
  concreteRun :
    ConcreteRun s trace.events final obs
  finalUnique :
    final = (runKernel s trace.events).state
  observationsUnique :
    obs = (runKernel s trace.events).obs
  abstractState :
    stateAllowed (erase final)
  abstractStasis :
    erase final = erase s
  observations :
    ObservationsSatisfy obs obsAllowed
  resourcesConserved :
    ResourceLedger final = ResourceLedger s

def TrapObservationsAuthorized (a : AbstractState) (trace : TrapTrace)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs ->
    ∃ trap, trap ∈ trace.traps ∧ ∃ cause, CauseAllows a trap.toRaw cause ob

def HardwareObservationsAuthorized (a : AbstractState) (trace : HardwareTrace)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs ->
    (∃ cause, CauseAllows a .boot cause ob) ∨
      ∃ trap, trap ∈ trace.traps ∧ ∃ cause, CauseAllows a trap.toRaw cause ob

structure TrapClosureTheorem (s : State) (trace : TrapTrace) : Prop where
  concreteRun :
    ConcreteRun s trace.events (runKernel s trace.events).state
      (runKernel s trace.events).obs
  exactAbstractRun :
    AbstractRun (erase s) trace.events
      (erase (runKernel s trace.events).state) (runKernel s trace.events).obs
  invariantPreserved :
    KernelInvariant s -> KernelInvariant (runKernel s trace.events).state
  abstractStasis :
    erase (runKernel s trace.events).state = erase s
  resourcesStable :
    ResourceLedger (runKernel s trace.events).state = ResourceLedger s
  traceProvenance :
    TraceHasRunProvenance (erase s) trace.events (runKernel s trace.events).obs
  noEnterUser :
    ∀ entry, .enterUser entry ∉ (runKernel s trace.events).obs
  trapObservationsAuthorized :
    TrapObservationsAuthorized (erase s) trace (runKernel s trace.events).obs
  trapObservationsSatisfy :
    ∀ allowed, trace.ObservationPolicy (erase s) allowed ->
      ObservationsSatisfy (runKernel s trace.events).obs allowed
  concreteRunUnique :
    ∀ final obs, ConcreteRun s trace.events final obs ->
      final = (runKernel s trace.events).state ∧ obs = (runKernel s trace.events).obs

structure CompositionalTrapClosureTheorem (s : State) (first second : TrapTrace) : Prop where
  firstClosure : TrapClosureTheorem s first
  secondClosure : TrapClosureTheorem (runKernel s first.events).state second
  composedClosure : TrapClosureTheorem s (first.append second)
  composedRun :
    runKernel s (first.append second).events =
      let firstOut := runKernel s first.events
      let secondOut := runKernel firstOut.state second.events
      { state := secondOut.state, obs := firstOut.obs ++ secondOut.obs }

structure TemporalTrapClosureTheorem (s : State) (trace : TrapTrace) : Prop where
  closure : TrapClosureTheorem s trace
  prefixClosure :
    ∀ tracePrefix, tracePrefix.traps <+: trace.traps -> TrapClosureTheorem s tracePrefix
  splitClosure :
    ∀ first second, first.traps ++ second.traps = trace.traps ->
      CompositionalTrapClosureTheorem s first second

structure StrongestKernelTheorem (events : List RawEvent) : Prop where
  runSound :
    KernelRunSound initialState (erase initialState) events
      (runKernel initialState events).state (runKernel initialState events).obs
  exactAbstractRun :
    AbstractRun (erase initialState) events
      (erase (runKernel initialState events).state) (runKernel initialState events).obs
  concreteRunUnique :
    ∀ final obs, ConcreteRun initialState events final obs ->
      final = (runKernel initialState events).state ∧ obs = (runKernel initialState events).obs

def RawEventTotalCorrectness : Prop :=
  ∀ events, StrongestKernelTheorem events

structure TemporalStrongestKernelTheorem (trace : HardwareTrace) : Prop where
  whole : StrongestKernelTheorem trace.events
  bootSound :
    KernelRunSound initialState (erase initialState) [.boot]
      (runKernel initialState [.boot]).state (runKernel initialState [.boot]).obs
  trapTemporal :
    TemporalTrapClosureTheorem (runKernel initialState [.boot]).state trace.tail
  hardwareObservationsAuthorized :
    HardwareObservationsAuthorized (erase initialState) trace
      (runKernel initialState trace.events).obs
  hardwareObservationsSatisfy :
    ∀ allowed, trace.ObservationPolicy (erase initialState) allowed ->
      ObservationsSatisfy (runKernel initialState trace.events).obs allowed

private theorem bootable_false_of_boots_ne_zero {s : State} (h : s.boots ≠ 0) :
    bootable s = false := by
  unfold bootable
  cases hBoots : natEq s.boots 0
  · rfl
  · exact False.elim (h ((fun {a b : Nat} (h : natEq a b = true) =>
      show a = b from by
      induction a generalizing b with
      | zero =>
        cases b <;> simp [natEq] at h ⊢
      | succ a ih =>
        cases b with
        | zero =>
          simp [natEq] at h
        | succ b =>
          simp [natEq] at h
          exact congrArg Nat.succ (ih h)) hBoots))

structure Behavior where
  final : AbstractState
  obs : List Obs

def behaviorOf (out : RunOutput) : Behavior :=
  { final := erase out.state, obs := out.obs }

structure KernelWorld where
  state : State

def KernelWorld.erase (world : KernelWorld) : AbstractState :=
  Kernel.erase world.state

def KernelWorld.runRaw (world : KernelWorld) (trace : HardwareTrace) : RunOutput :=
  runKernel world.state trace.events

def KernelWorld.runEvents (world : KernelWorld) (events : List RawEvent) : RunOutput :=
  runKernel world.state events

def KernelWorld.run (world : KernelWorld) (events : List RawEvent) : Behavior :=
  behaviorOf (runKernel world.state events)

inductive Authority where
  | kernelBoot
  | trapHandler : RawEvent -> Authority
  | userSyscall : RawEvent -> TaskId -> Syscall -> Authority
  | failClosed : RawEvent -> Authority

def Authority.toCause : Authority -> AuthorityCause
  | .kernelBoot => .kernelBoot
  | .trapHandler _ => .trapHandler
  | .userSyscall _ task _ => .userSyscall task
  | .failClosed _ => .failClosed

def initialAuthority (_s : State) : List Authority :=
  [.kernelBoot]

def eventAuthority : RawEvent -> List Authority
  | .boot => [.kernelBoot, .failClosed .boot]
  | raw@(.trap _ _ _ syscallNo syscallArg) =>
    [.trapHandler raw, .userSyscall raw .task0 (decodeSyscall syscallNo syscallArg),
      .userSyscall raw .task1 (decodeSyscall syscallNo syscallArg), .failClosed raw]

def traceAuthority (trace : HardwareTrace) : List Authority :=
  List.flatMap eventAuthority trace.events

def rawTraceAuthority (events : List RawEvent) : List Authority :=
  List.flatMap eventAuthority events

def AuthorityExplains (a : AbstractState) (raw : RawEvent) (auth : Authority)
    (ob : Obs) : Prop :=
  CauseAllows a raw auth.toCause ob

def NoPanic (obs : List Obs) : Prop :=
  .halt ∉ obs

def NoUnauthorizedObservation (s : State) (trace : HardwareTrace)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs ->
    ∃ auth raw,
      (auth ∈ initialAuthority s ∨ auth ∈ traceAuthority trace) ∧
      raw ∈ trace.events ∧
      AuthorityExplains (erase s) raw auth ob

def NoUnauthorizedRawObservation (s : State) (events : List RawEvent)
    (obs : List Obs) : Prop :=
  ∀ ob, ob ∈ obs ->
    ∃ auth raw,
      (auth ∈ initialAuthority s ∨ auth ∈ rawTraceAuthority events) ∧
      raw ∈ events ∧
      AuthorityExplains (erase s) raw auth ob

def FullAbstraction (eraseFn : KernelWorld -> AbstractState)
    (run : KernelWorld -> List RawEvent -> Behavior) : Prop :=
  ∀ s t,
    eraseFn s = eraseFn t ↔
      ∀ events, run s events = run t events

def PanicFreedom (run : KernelWorld -> List RawEvent -> Behavior) : Prop :=
  ∀ world events, NoPanic (run world events).obs

def BootCountSound (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events, (run world events).state.boots = world.state.boots + bootCount events

def UserEntrySound (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events entry, .enterUser entry ∈ (run world events).obs ->
    entry = userEntry ∧ .boot ∈ events

def UserWriteSound (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events byte, .writeUserByte byte ∈ (run world events).obs ->
    (∃ raw, raw ∈ events ∧ raw.isWriteByte byte) ∧ byte < 256

def UserWriteActionTaskProvenance : Prop :=
  ∀ s raw task byte,
    .writeUserByte task byte ∈ (concreteStep s raw).value.actions ->
      task = s.scheduler.current ∧ raw.isWriteByte byte ∧ byte < 256

def AuthorityConservation (run : KernelWorld -> HardwareTrace -> RunOutput) : Prop :=
  ∀ world trace,
    ∀ ob, ob ∈ (run world trace).obs ->
      ∃ auth raw,
        (auth ∈ initialAuthority world.state ∨ auth ∈ traceAuthority trace) ∧
        raw ∈ trace.events ∧
        AuthorityExplains (erase world.state) raw auth ob

def RawAuthorityConservation (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events, NoUnauthorizedRawObservation world.state events (run world events).obs

def ClosedWorldSafety (run : KernelWorld -> HardwareTrace -> RunOutput) : Prop :=
  ∀ world trace,
    KernelInvariant (run world trace).state ∧
    ResourceLedger (run world trace).state =
      ResourceLedger (runKernel world.state [.boot]).state ∧
    NoPanic (run world trace).obs ∧
    NoUnauthorizedObservation world.state trace (run world trace).obs

def BootSanitization (run : KernelWorld -> HardwareTrace -> RunOutput) : Prop :=
  ∀ world,
    let out := run world { traps := [] }
    KernelInvariant out.state ∧
    out.state.heap = bootHeap ∧
    out.state.memory = bootMemory ∧
    out.state.boots = world.state.boots + 1 ∧
    erase out.state =
      { boots := world.state.boots + 1,
        frameAccount := ResourceLedger (runKernel initialState [.boot]).state,
        bootable := false } ∧
    NoPanic out.obs ∧
    NoUnauthorizedObservation world.state { traps := [] } out.obs

def BootedRawEventSafety (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events,
    let out := run world (.boot :: events)
    KernelInvariant out.state ∧
    out.state.heap = bootHeap ∧
    out.state.memory = bootMemory ∧
    ResourceLedger out.state = ResourceLedger (runKernel world.state [.boot]).state ∧
    NoPanic out.obs ∧
    NoUnauthorizedRawObservation world.state (.boot :: events) out.obs

def BootRecovery (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world preEvents suffix,
    let pre := runKernel world.state preEvents
    let boot := runKernel pre.state [.boot]
    let out := run world (preEvents ++ .boot :: suffix)
    KernelInvariant out.state ∧
    out.state.heap = bootHeap ∧
    out.state.memory = bootMemory ∧
    ResourceLedger out.state = ResourceLedger boot.state ∧
    NoPanic out.obs ∧
    NoUnauthorizedRawObservation world.state (preEvents ++ .boot :: suffix) out.obs

def TaskModelSound (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events, (run world events).state.task = taskAfterEvents world.state.task events

def UserTaskProgress (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world, (run world [.boot, userExitEvent]).state.task.status = .exited

def UserCannotMutateKernelMemory (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events, (run world (.boot :: events)).state.memory = bootMemory

def SchedulerModelSound (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world events,
    (run world events).state.scheduler = schedulerAfterEvents world.state.scheduler events

def SchedulerFullAbstraction (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world₁ world₂ events,
    world₁.state.scheduler = world₂.state.scheduler →
    (run world₁ events).state.scheduler = (run world₂ events).state.scheduler

def CurrentTaskOnlyChanges (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world syscallNo syscallArg tid,
    tid ≠ world.state.scheduler.current →
    (run world [.trap 8 0 0 syscallNo syscallArg]).state.scheduler.taskById tid =
      world.state.scheduler.taskById tid

def RoundRobinFairnessSpec (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world,
    (run world [schedulerYieldEvent]).state.scheduler.current =
        world.state.scheduler.current.next ∧
      (run world [schedulerTimerEvent]).state.scheduler.current =
        world.state.scheduler.current.next ∧
      (run world [schedulerYieldEvent, schedulerYieldEvent]).state.scheduler.current =
        world.state.scheduler.current ∧
      (run world [schedulerTimerEvent, schedulerTimerEvent]).state.scheduler.current =
        world.state.scheduler.current ∧
      (run world [schedulerYieldEvent, schedulerTimerEvent]).state.scheduler.current =
        world.state.scheduler.current ∧
      (run world [schedulerTimerEvent, schedulerYieldEvent]).state.scheduler.current =
        world.state.scheduler.current

def SchedulerCannotMutateKernelMemory (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world syscallNo syscallArg,
    (run world [.trap 8 0 0 syscallNo syscallArg]).state.memory = world.state.memory

def PageFaultKillsCurrentTaskPreservesInvariant
    (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world scause sepc stval syscallNo syscallArg,
    isPageFaultScause scause →
    KernelInvariant world.state →
    let out := run world [.trap scause sepc stval syscallNo syscallArg]
    concreteStep world.state (.trap scause sepc stval syscallNo syscallArg) =
      .ok (StepOutput.mk (stateAfterPageFault world.state) [.killCurrentTask,
        .log "Lean theorem: page fault kills current task and preserves kernel invariant"]) ∧
      KernelInvariant out.state ∧
      out.state.task = killTask world.state.task ∧
      out.state.scheduler = schedulerAfterPageFault world.state.scheduler ∧
      out.state.scheduler.current = world.state.scheduler.current.next ∧
      (out.state.scheduler.taskById world.state.scheduler.current).status = .exited ∧
      .halt ∉ out.obs

def TimerInterruptPreservesInvariant
    (run : KernelWorld -> List RawEvent -> RunOutput) : Prop :=
  ∀ world sepc stval syscallNo syscallArg,
    KernelInvariant world.state →
    let out := run world [.trap supervisorTimerScause sepc stval syscallNo syscallArg]
    concreteStep world.state (.trap supervisorTimerScause sepc stval syscallNo syscallArg) =
      .ok (StepOutput.mk (stateAfterTimerInterrupt world.state) [.installTimer,
        .log "Lean theorem: timer interrupt forces scheduler yield and preserves invariant"]) ∧
      KernelInvariant out.state ∧
      out.state.task = world.state.task ∧
      out.state.scheduler = schedulerAfterSyscall world.state.scheduler .yield ∧
      out.state.scheduler.current = world.state.scheduler.current.next ∧
      out.state.heap = world.state.heap ∧
      out.state.memory = world.state.memory ∧
      .halt ∉ out.obs

def StepPreservesInvariant : Prop :=
  ∀ s e, KernelInvariant s → KernelInvariant (concreteStep s e).value.state

structure TheoremFirstKernel : Prop where
  fullAbstraction : FullAbstraction KernelWorld.erase KernelWorld.run
  panicFreedom : PanicFreedom KernelWorld.run
  bootCountSound : BootCountSound KernelWorld.runEvents
  userEntrySound : UserEntrySound KernelWorld.runEvents
  userWriteSound : UserWriteSound KernelWorld.runEvents
  userWriteActionTaskProvenance : UserWriteActionTaskProvenance
  rawAuthorityConservation : RawAuthorityConservation KernelWorld.runEvents
  authorityConservation : AuthorityConservation KernelWorld.runRaw
  closedWorldSafety : ClosedWorldSafety KernelWorld.runRaw
  bootSanitization : BootSanitization KernelWorld.runRaw
  bootedRawEventSafety : BootedRawEventSafety KernelWorld.runEvents
  bootRecovery : BootRecovery KernelWorld.runEvents
  taskModelSound : TaskModelSound KernelWorld.runEvents
  userTaskProgress : UserTaskProgress KernelWorld.runEvents
  userCannotMutateKernelMemory : UserCannotMutateKernelMemory KernelWorld.runEvents
  pageFault_kills_current_task_preserves_invariant :
    PageFaultKillsCurrentTaskPreservesInvariant KernelWorld.runEvents
  timerInterrupt_preserves_invariant :
    TimerInterruptPreservesInvariant KernelWorld.runEvents
  stepPreservesInvariant : StepPreservesInvariant
  initialHeapRefinesRuntimeBumpAllocator :
    BumpRefinesHeap initialBumpAllocator initialHeap
  bumpAllocRefinesAlloc : BumpAllocRefinesAlloc
  rawEventTotalCorrectness : RawEventTotalCorrectness
  schedulerModelSound : SchedulerModelSound KernelWorld.runEvents
  schedulerFullAbstraction : SchedulerFullAbstraction KernelWorld.runEvents
  currentTaskOnlyChanges : CurrentTaskOnlyChanges KernelWorld.runEvents
  roundRobinFairness : RoundRobinFairnessSpec KernelWorld.runEvents
  schedulerCannotMutateKernelMemory : SchedulerCannotMutateKernelMemory KernelWorld.runEvents

private theorem kernel_full_abstraction :
    FullAbstraction KernelWorld.erase KernelWorld.run := by
  intro s t
  constructor
  · intro h events
    exact ((fun {s t : State} (h : erase s = erase t) (events : List RawEvent) =>
      show behaviorOf (runKernel s events) = behaviorOf (runKernel t events) from by
      induction events generalizing s t with
      | nil =>
        simp [runKernel, behaviorOf, h]
      | cons raw events ih =>
        rcases ((fun {s t : State} (h : erase s = erase t) (raw : RawEvent) =>
          show erase (concreteStep s raw).value.state = erase (concreteStep t raw).value.state ∧
            observeActions (concreteStep s raw).value.actions =
              observeActions (concreteStep t raw).value.actions from by
          have hboots : s.boots = t.boots := congrArg AbstractState.boots h
          have hframes : frameAccount s.memory.frames = frameAccount t.memory.frames :=
            congrArg AbstractState.frameAccount h
          cases raw with
          | boot =>
            simp [concreteStep, decodeRawEvent, step, KernelResult.value, erase, bootOutput,
              hboots]
          | trap scause sepc stval syscallNo syscallArg =>
            by_cases h3 : scause = 3
            · subst scause
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, KernelResult.value, h]
            · by_cases h8 : scause = 8
              · subst scause
                cases hsys : decodeSyscall syscallNo syscallArg with
                | yield =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, erase, bootable, hboots, hframes]
                | writeByte byte =>
                  by_cases hbyte : byte < 256
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, hbyte, KernelResult.value, erase, bootable, hboots, hframes,
                      observeActions, observeAction]
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, hbyte, KernelResult.value, erase, bootable, hboots, hframes]
                | exit code =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, erase, bootable, hboots, hframes]
                | denied =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, erase, bootable, hboots, hframes]
              · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
                · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                    handleTrap, KernelResult.value, h]
                · by_cases hTimer : scause = supervisorTimerScause
                  · subst scause
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8,
                      handleTrap, KernelResult.value, erase, bootable, hboots, hframes]
                  ·
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                      hTimer, handleTrap, failClosed, KernelResult.value, h]) h raw) with
          ⟨hNext, hObs⟩
        have hTail := ih hNext
        have hFinal := congrArg Behavior.final hTail
        have hObsTail := congrArg Behavior.obs hTail
        simp [runKernel, behaviorOf, hObs]
        constructor
        · simpa [behaviorOf] using hFinal
        · simpa [behaviorOf] using hObsTail) h events)
  · intro h
    exact congrArg Behavior.final (h [])

private theorem runKernel_no_halt (s : State) (events : List RawEvent) :
    .halt ∉ (runKernel s events).obs := by
  induction events generalizing s with
  | nil =>
    simp [runKernel]
  | cons raw events ih =>
    have hHead : .halt ∉ observeActions (concreteStep s raw).value.actions := by
      cases raw with
      | boot =>
        simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput,
          bootActions, observeActions, observeAction]
      | trap scause sepc stval syscallNo syscallArg =>
        by_cases h3 : scause = 3
        · subst scause
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
            KernelResult.value, observeActions, observeAction]
        · by_cases h8 : scause = 8
          · subst scause
            cases hsys : decodeSyscall syscallNo syscallArg with
            | yield =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, observeActions, observeAction]
            | writeByte byte =>
              by_cases hbyte : byte < 256
              · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                  hsys, hbyte, KernelResult.value, observeActions, observeAction]
              · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                  hsys, hbyte, KernelResult.value, observeActions, observeAction]
            | exit code =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, observeActions, observeAction]
            | denied =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, observeActions, observeAction]
          · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
            · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, handleTrap,
                KernelResult.value, observeActions, observeAction]
            · by_cases hTimer : scause = supervisorTimerScause
              · subst scause
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, handleTrap,
                  KernelResult.value, observeActions, observeAction]
              ·
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, hTimer,
                  handleTrap, failClosed, KernelResult.value, observeActions, observeAction]
    have hTail := ih (concreteStep s raw).value.state
    simp [runKernel, hHead, hTail]

private theorem kernel_user_entry_sound :
    UserEntrySound KernelWorld.runEvents := by
  intro world events entry h
  simpa [UserEntrySound, KernelWorld.runEvents] using
    ((fun (s : State) (events : List RawEvent) (entry : Nat) =>
      show .enterUser entry ∈ (runKernel s events).obs →
          entry = userEntry ∧ .boot ∈ events from by
      induction events generalizing s with
      | nil =>
        simp [runKernel]
      | cons raw events ih =>
        intro h
        simp [runKernel] at h
        rcases h with hHead | hTail
        · rcases ((fun (s : State) (raw : RawEvent) (entry : Nat) =>
            show .enterUser entry ∈ observeActions (concreteStep s raw).value.actions →
                entry = userEntry ∧ raw = .boot from by
            cases raw with
            | boot =>
              intro h
              simpa [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput,
                bootActions, observeActions, observeAction] using h
            | trap scause sepc stval syscallNo syscallArg =>
              intro h
              by_cases h3 : scause = 3
              · subst scause
                simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                  KernelResult.value, observeActions, observeAction] at h
              · by_cases h8 : scause = 8
                · subst scause
                  cases hsys : decodeSyscall syscallNo syscallArg with
                  | yield =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, KernelResult.value, observeActions, observeAction] at h
                  | writeByte byte =>
                    by_cases hbyte : byte < 256
                    · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                        hsys, hbyte, KernelResult.value, observeActions, observeAction] at h
                    · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                        hsys, hbyte, KernelResult.value, observeActions, observeAction] at h
                  | exit code =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, KernelResult.value, observeActions, observeAction] at h
                  | denied =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, KernelResult.value, observeActions, observeAction] at h
                · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                      handleTrap, KernelResult.value, observeActions, observeAction] at h
                  · by_cases hTimer : scause = supervisorTimerScause
                    · subst scause
                      simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8,
                        handleTrap, KernelResult.value, observeActions, observeAction] at h
                    ·
                      simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                        hTimer, handleTrap, failClosed, KernelResult.value, observeActions,
                        observeAction] at h) s raw entry hHead) with ⟨hentry, hboot⟩
          exact ⟨hentry, by simp [hboot]⟩
        · rcases ih (concreteStep s raw).value.state hTail with ⟨hentry, hboot⟩
          exact ⟨hentry, by simp [hboot]⟩) world.state events entry h)

private theorem kernel_boot_count_sound :
    BootCountSound KernelWorld.runEvents := by
  intro world events
  simpa [BootCountSound, KernelWorld.runEvents] using
    ((fun (s : State) (events : List RawEvent) =>
      show (runKernel s events).state.boots = s.boots + bootCount events from by
      induction events generalizing s with
      | nil =>
        simp [runKernel, bootCount]
      | cons raw events ih =>
        have hHead : (concreteStep s raw).value.state.boots =
            s.boots + bootCount [raw] := by
          cases raw with
          | boot =>
            simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput, bootCount]
          | trap scause sepc stval syscallNo syscallArg =>
            by_cases h3 : scause = 3
            · subst scause
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                KernelResult.value, bootCount]
            · by_cases h8 : scause = 8
              · subst scause
                cases hsys : decodeSyscall syscallNo syscallArg with
                | yield =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, bootCount]
                | writeByte byte =>
                  by_cases hbyte : byte < 256
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, hbyte, KernelResult.value, bootCount]
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                      hsys, hbyte, KernelResult.value, bootCount]
                | exit code =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, bootCount]
                | denied =>
                  simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                    hsys, KernelResult.value, bootCount]
              · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
                · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                    handleTrap, KernelResult.value, bootCount]
                · by_cases hTimer : scause = supervisorTimerScause
                  · subst scause
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8,
                      handleTrap, KernelResult.value, bootCount]
                  ·
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                      hTimer, handleTrap, failClosed, KernelResult.value, bootCount]
        have hTail := ih (concreteStep s raw).value.state
        cases raw <;> simp [runKernel, bootCount, hTail, hHead] <;> omega) world.state events)

private theorem runKernel_preserves_boot_storage (s : State) (events : List RawEvent)
    (hHeap : s.heap = bootHeap) (hMemory : s.memory = bootMemory) :
    (runKernel s events).state.heap = bootHeap ∧
      (runKernel s events).state.memory = bootMemory := by
  induction events generalizing s with
  | nil =>
    simp [runKernel, hHeap, hMemory]
  | cons raw events ih =>
    rcases ((fun (s : State) (raw : RawEvent)
        (hHeap : s.heap = bootHeap) (hMemory : s.memory = bootMemory) =>
      show (concreteStep s raw).value.state.heap = bootHeap ∧
          (concreteStep s raw).value.state.memory = bootMemory from by
      cases raw with
      | boot =>
        simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput]
      | trap scause sepc stval syscallNo syscallArg =>
        by_cases h3 : scause = 3
        · subst scause
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
            KernelResult.value, hHeap, hMemory]
        · by_cases h8 : scause = 8
          · subst scause
            cases hsys : decodeSyscall syscallNo syscallArg with
            | yield =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, hHeap, hMemory]
            | writeByte byte =>
              by_cases hbyte : byte < 256
              · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                  hsys, hbyte, KernelResult.value, hHeap, hMemory]
              · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                  hsys, hbyte, KernelResult.value, hHeap, hMemory]
            | exit code =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, hHeap, hMemory]
            | denied =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, hHeap, hMemory]
          · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
            · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, handleTrap,
                KernelResult.value, hHeap, hMemory]
            · by_cases hTimer : scause = supervisorTimerScause
              · subst scause
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, handleTrap,
                  KernelResult.value, hHeap, hMemory]
              ·
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, hTimer,
                  handleTrap, failClosed, KernelResult.value, hHeap, hMemory]) s raw hHeap hMemory) with
      ⟨hHeap', hMemory'⟩
    exact ih (concreteStep s raw).value.state hHeap' hMemory'

private theorem kernel_panic_freedom :
    PanicFreedom KernelWorld.run := by
  intro world events
  simpa [PanicFreedom, KernelWorld.run, behaviorOf, NoPanic] using
    runKernel_no_halt world.state events

private theorem boot_invariant (s : State) :
    KernelInvariant (runKernel s [.boot]).state := by
  simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step, bootOutput,
    bootHeap, bootMemory]
  constructor
  · simp [Accounted, totalAllocated, bootAllocBytes, initialHeap, kernelHeapCapacity,
      kernelHeapBytes, kernelHeapPrefix]
  · simp [MemoryInvariant, DisjointFrames, MappingsUnique, MappedFramesAllocated,
      pageTableMmioL1Pfn, pageTableKernelL1Pfn, pageTableRootPfn, kernelPfn,
      kernelNextPfn, userPfn, uartPfn, clintPfn, clintVpn, uartVpn, userVpn,
      kernelVpn, mmioFlags]

theorem trap_closure_theorem (s : State) (trace : TrapTrace) :
    TrapClosureTheorem s trace := by
  have hEventsAdmissible :
      ∀ raw, raw ∈ trace.events -> HardwareTrapAdmissible raw := by
    intro raw hraw
    obtain ⟨trap, _, rfl⟩ := List.mem_map.mp hraw
    cases trap
    simp [HardwareTrapEvent.toRaw, HardwareTrapAdmissible]
  have trapFacts : ∀ (s : State) (raw : RawEvent),
      HardwareTrapAdmissible raw →
      erase (runKernel s [raw]).state = erase s ∧
        ResourceLedger (runKernel s [raw]).state = ResourceLedger s ∧
        (KernelInvariant s → KernelInvariant (runKernel s [raw]).state) ∧
        TraceHasAuthorityProvenance (erase s) raw (runKernel s [raw]).obs := by
    intro s raw hraw
    cases raw with
    | boot =>
      cases hraw
    | trap scause sepc stval syscallNo syscallArg =>
      by_cases h3 : scause = 3
      · subst scause
        refine ⟨?_, ?_, ?_, ?_⟩
        · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
            decodeTrap, handleTrap]
        · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
            decodeTrap, handleTrap, ResourceLedger]
        · intro hInv
          simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
            decodeTrap, handleTrap] using hInv
        · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
            decodeTrap, handleTrap, TraceHasAuthorityProvenance, observeActions,
            observeAction, CauseAllows, RawEvent.isBreakpoint]
          exact ⟨.trapHandler, trivial⟩
      · by_cases h8 : scause = 8
        · subst scause
          by_cases hyield : syscallNo = syscallYield
          · subst syscallNo
            refine ⟨?_, ?_, ?_, ?_⟩
            · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, decodeSyscall, syscallYield, handleTrap, handleSyscall, erase,
                bootable]
            · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, decodeSyscall, syscallYield, handleTrap, handleSyscall,
                ResourceLedger]
            · intro hInv
              constructor
              · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, decodeSyscall, syscallYield, handleTrap, handleSyscall] using
                  hInv.heapAccounted
              · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, decodeSyscall, syscallYield, handleTrap, handleSyscall] using
                  hInv.memorySafe
            · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, decodeSyscall, syscallYield, handleTrap, handleSyscall,
                TraceHasAuthorityProvenance, observeActions, observeAction, CauseAllows,
                RawEvent.isUserEcall]
              exact ⟨.userSyscall s.scheduler.current, trivial⟩
          · by_cases hwrite : syscallNo = syscallWriteByte ∧ syscallArg < 256
            · rcases hwrite with ⟨hno, harg⟩
              subst syscallNo
              refine ⟨?_, ?_, ?_, ?_⟩
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, handleTrap,
                  handleSyscall, harg, erase, bootable]
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, handleTrap,
                  handleSyscall, harg, ResourceLedger]
              · intro hInv
                constructor
                · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, handleTrap,
                    handleSyscall, harg] using hInv.heapAccounted
                · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, handleTrap,
                    handleSyscall, harg] using hInv.memorySafe
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, handleTrap,
                  handleSyscall, harg, TraceHasAuthorityProvenance, observeActions,
                  observeAction, CauseAllows, RawEvent.isUserEcall, RawEvent.isWriteByte]
                constructor
                · exact ⟨.userSyscall s.scheduler.current, rfl⟩
                · exact ⟨.trapHandler, trivial⟩
            · by_cases hexit : syscallNo = syscallExit
              · subst syscallNo
                refine ⟨?_, ?_, ?_, ?_⟩
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, syscallExit,
                    handleTrap, handleSyscall, erase, bootable]
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, syscallExit,
                    handleTrap, handleSyscall, ResourceLedger]
                · intro hInv
                  constructor
                  · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                      decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, syscallExit,
                      handleTrap, handleSyscall] using hInv.heapAccounted
                  · simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                      decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, syscallExit,
                      handleTrap, handleSyscall] using hInv.memorySafe
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, decodeSyscall, syscallYield, syscallWriteByte, syscallExit,
                    handleTrap, handleSyscall, TraceHasAuthorityProvenance, observeActions,
                    observeAction, CauseAllows, RawEvent.isUserEcall]
                  exact ⟨.userSyscall s.scheduler.current, trivial⟩
              · have hDenied : decodeSyscall syscallNo syscallArg = .denied := by
                  simp [decodeSyscall, hyield, hwrite, hexit]
                refine ⟨?_, ?_, ?_, ?_⟩
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, handleTrap, hDenied, handleSyscall]
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, handleTrap, hDenied, handleSyscall, ResourceLedger]
                · intro hInv
                  simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, handleTrap, hDenied, handleSyscall] using hInv
                · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                    decodeTrap, handleTrap, hDenied, handleSyscall,
                    TraceHasAuthorityProvenance, observeActions, observeAction, CauseAllows,
                    RawEvent.isUserEcall]
                  exact ⟨.userSyscall s.scheduler.current, trivial⟩
        · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
          · refine ⟨?_, ?_, ?_, ?_⟩
            · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, h3, h8, hPage, handleTrap]
            · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, h3, h8, hPage, handleTrap, ResourceLedger]
            · intro hInv
              simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, h3, h8, hPage, handleTrap] using hInv
            · intro ob hob
              simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                decodeTrap, h3, h8, hPage, handleTrap, observeActions, observeAction] at hob
              subst ob
              exact ⟨.trapHandler, by
                right
                right
                right
                simpa [RawEvent.isPageFault] using hPage⟩
          ·
            by_cases hTimer : scause = supervisorTimerScause
            · subst scause
              refine ⟨?_, ?_, ?_, ?_⟩
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, handleTrap]
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, handleTrap, ResourceLedger]
              · intro hInv
                simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, hPage, handleTrap] using hInv
              · intro ob hob
                simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, handleTrap, observeActions, observeAction] at hob
                subst ob
                exact ⟨.trapHandler, by
                  right
                  right
                  left
                  simp [RawEvent.isTimerInterrupt]⟩
            · refine ⟨?_, ?_, ?_, ?_⟩
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, hPage, hTimer, handleTrap, failClosed]
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, hPage, hTimer, handleTrap, failClosed, ResourceLedger]
              · intro hInv
                simpa [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, hPage, hTimer, handleTrap, failClosed] using hInv
              · simp [runKernel, concreteStep, decodeRawEvent, KernelResult.value, step,
                  decodeTrap, h3, h8, hPage, hTimer, handleTrap, failClosed,
                  TraceHasAuthorityProvenance, observeActions, observeAction, CauseAllows]
                constructor
                · exact ⟨.failClosed, trivial⟩
                · exact ⟨.failClosed, trivial⟩
  have hStasis :
      erase (runKernel s trace.events).state = erase s := by
    have aux : ∀ (s : State) (events : List RawEvent),
        (∀ raw, raw ∈ events -> HardwareTrapAdmissible raw) →
        erase (runKernel s events).state = erase s := by
      intro s events hEvents
      induction events generalizing s with
      | nil =>
        simp [runKernel]
      | cons raw events ih =>
        have hStep := (trapFacts s raw (hEvents raw (by simp))).1
        have hTail := ih (runKernel s [raw]).state
          fun tailRaw hmem => hEvents tailRaw (by simp [hmem])
        simpa [runKernel] using hTail.trans hStep
    exact aux s trace.events hEventsAdmissible
  have hResources :
      ResourceLedger (runKernel s trace.events).state = ResourceLedger s := by
    have aux : ∀ (s : State) (events : List RawEvent),
        (∀ raw, raw ∈ events -> HardwareTrapAdmissible raw) →
        ResourceLedger (runKernel s events).state = ResourceLedger s := by
      intro s events hEvents
      induction events generalizing s with
      | nil =>
        simp [runKernel, ResourceLedger]
      | cons raw events ih =>
        have hStep := (trapFacts s raw (hEvents raw (by simp))).2.1
        have hTail := ih (runKernel s [raw]).state
          fun tailRaw hmem => hEvents tailRaw (by simp [hmem])
        simpa [runKernel] using hTail.trans hStep
    exact aux s trace.events hEventsAdmissible
  have hInvariantPreserved :
      KernelInvariant s -> KernelInvariant (runKernel s trace.events).state := by
    have aux : ∀ (s : State) (events : List RawEvent),
        (∀ raw, raw ∈ events -> HardwareTrapAdmissible raw) →
        KernelInvariant s -> KernelInvariant (runKernel s events).state := by
      intro s events hEvents
      induction events generalizing s with
      | nil =>
        intro hInv
        simpa [runKernel] using hInv
      | cons raw events ih =>
        intro hInv
        have hStep := (trapFacts s raw (hEvents raw (by simp))).2.2.1 hInv
        have hTail := ih (runKernel s [raw]).state
          (fun tailRaw hmem => hEvents tailRaw (by simp [hmem])) hStep
        simpa [runKernel] using hTail
    exact aux s trace.events hEventsAdmissible
  have hAbstract :
      AbstractRun (erase s) trace.events
        (erase (runKernel s trace.events).state) (runKernel s trace.events).obs := by
    have aux : ∀ (s : State) (events : List RawEvent),
        (∀ raw, raw ∈ events -> HardwareTrapAdmissible raw) →
        AbstractRun (erase s) events (erase (runKernel s events).state)
          (runKernel s events).obs := by
      intro s events hEvents
      induction events generalizing s with
      | nil =>
        simpa [runKernel] using AbstractRun.nil (erase s)
      | cons raw events ih =>
        have hraw : HardwareTrapAdmissible raw := hEvents raw (by simp)
        obtain ⟨hEraseStep, _, _, hAuth⟩ := trapFacts s raw hraw
        have hValueErase : erase (concreteStep s raw).value.state = erase s := by
          simpa [runKernel] using hEraseStep
        have hTailEvents : ∀ tailRaw, tailRaw ∈ events -> HardwareTrapAdmissible tailRaw :=
          fun tailRaw hmem => hEvents tailRaw (by simp [hmem])
        cases hstep : concreteStep s raw with
        | ok out =>
          have hOutErase : erase out.state = erase s := by
            simpa [hstep, KernelResult.value] using hValueErase
          have hStep : AbstractStep (erase s) raw (erase out.state) (observeActions out.actions) :=
            AbstractStep.ok (by
              cases raw with
              | boot =>
                cases hraw
              | trap scause sepc stval syscallNo syscallArg =>
                simpa [AbstractOkNext] using hOutErase)
              (by simpa [runKernel, hstep, KernelResult.value] using hAuth)
          simpa [runKernel, hstep, KernelResult.value] using
            AbstractRun.cons hStep (ih out.state hTailEvents)
        | error err out =>
          have hValueState : (concreteStep s raw).value.state = s := by
            cases raw with
            | boot =>
              cases hraw
            | trap scause sepc stval syscallNo syscallArg =>
              by_cases h3 : scause = 3
              · subst scause
                simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap] at hstep
              · by_cases h8 : scause = 8
                · subst scause
                  cases hsys : decodeSyscall syscallNo syscallArg with
                  | yield =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                      handleSyscall, hsys] at hstep
                  | writeByte byte =>
                    by_cases hbyte : byte < 256
                    · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                        handleSyscall, hsys, hbyte] at hstep
                    · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                        handleSyscall, hsys, hbyte] at hstep
                  | exit code =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                      handleSyscall, hsys] at hstep
                  | denied =>
                    simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
                      handleSyscall, hsys] at hstep
                · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
                  · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                      handleTrap] at hstep
                  · by_cases hTimer : scause = supervisorTimerScause
                    · subst scause
                      simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8,
                        handleTrap] at hstep
                    ·
                      simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                        hTimer, handleTrap, failClosed, KernelResult.value]
          have hOutErase : erase out.state = erase s := by
            simpa [hstep, KernelResult.value] using hValueErase
          have hOutState : out.state = s := by
            simpa [hstep, KernelResult.value] using hValueState
          have hStep : AbstractStep (erase s) raw (erase s) (observeActions out.actions) :=
            AbstractStep.rejected
              (by simpa [runKernel, hstep, KernelResult.value] using hAuth)
          simpa [runKernel, hstep, KernelResult.value, hOutErase] using
            AbstractRun.cons hStep (by simpa [hOutState] using ih out.state hTailEvents)
    exact aux s trace.events hEventsAdmissible
  have hProvenance :
      TraceHasRunProvenance (erase s) trace.events (runKernel s trace.events).obs := by
    have aux : ∀ (s : State) (events : List RawEvent),
        (∀ raw, raw ∈ events -> HardwareTrapAdmissible raw) →
        TraceHasRunProvenance (erase s) events (runKernel s events).obs := by
      intro s events hEvents
      induction events generalizing s with
      | nil =>
        simp [runKernel, TraceHasRunProvenance]
      | cons raw events ih =>
        have hraw : HardwareTrapAdmissible raw := hEvents raw (by simp)
        obtain ⟨hEraseStep, _, _, hAuth⟩ := trapFacts s raw hraw
        have hValueErase : erase (concreteStep s raw).value.state = erase s := by
          simpa [runKernel] using hEraseStep
        have hTailEvents : ∀ tailRaw, tailRaw ∈ events -> HardwareTrapAdmissible tailRaw :=
          fun tailRaw hmem => hEvents tailRaw (by simp [hmem])
        intro ob hob
        simp [runKernel] at hob
        rcases hob with hHead | hTail
        · exact ⟨raw, by simp, hAuth ob (by simpa [runKernel] using hHead)⟩
        · rcases ih (concreteStep s raw).value.state hTailEvents ob hTail with
            ⟨tailRaw, htailRaw, cause, hcause⟩
          exact ⟨tailRaw, by simp [htailRaw], cause, by simpa [hValueErase] using hcause⟩
    exact aux s trace.events hEventsAdmissible
  have hTrapAuth :
      TrapObservationsAuthorized (erase s) trace (runKernel s trace.events).obs := by
    intro ob hob
    obtain ⟨raw, hraw, cause, hcause⟩ := hProvenance ob hob
    obtain ⟨trap, htrap, rfl⟩ := List.mem_map.mp (by simpa [TrapTrace.events] using hraw)
    exact ⟨trap, htrap, cause, hcause⟩
  exact
    { concreteRun := runKernel_concreteRun s trace.events
      exactAbstractRun := hAbstract
      invariantPreserved := hInvariantPreserved
      abstractStasis := hStasis
      resourcesStable := hResources
      traceProvenance := hProvenance
      noEnterUser := by
        intro entry hobs
        rcases hProvenance (.enterUser entry) hobs with ⟨raw, hraw, cause, hcause⟩
        cases cause <;> simp [CauseAllows] at hcause
        exact hEventsAdmissible .boot (by simpa [hcause] using hraw)
      trapObservationsAuthorized := hTrapAuth
      trapObservationsSatisfy := by
        intro allowed hpolicy ob hob
        rcases hTrapAuth ob hob with ⟨trap, htrap, cause, hcause⟩
        exact hpolicy trap cause ob htrap hcause
      concreteRunUnique := fun _ _ => runKernel_unique_concreteRun s trace.events }

theorem TrapClosureTheorem.certifies_concrete_run {s final : State}
    {trace : TrapTrace} {obs : List Obs}
    (h : TrapClosureTheorem s trace)
    (hrun : ConcreteRun s trace.events final obs)
    (stateAllowed : AbstractState -> Prop) (obsAllowed : Obs -> Prop)
    (hState : stateAllowed (erase s))
    (hObsPolicy : trace.ObservationPolicy (erase s) obsAllowed) :
    CertifiedTrapExecution s trace final obs stateAllowed obsAllowed := by
  rcases h.concreteRunUnique final obs hrun with ⟨hfinal, hobs⟩
  exact
    { concreteRun := hrun
      finalUnique := hfinal
      observationsUnique := hobs
      abstractState := by
        rw [hfinal, h.abstractStasis]
        exact hState
      abstractStasis := by
        rw [hfinal]
        exact h.abstractStasis
      observations := by
        rw [hobs]
        exact h.trapObservationsSatisfy obsAllowed hObsPolicy
      resourcesConserved := by
        rw [hfinal]
        exact h.resourcesStable }

theorem step_preserves_invariant : StepPreservesInvariant := by
  intro s e hInv
  cases e with
  | boot =>
    simpa [runKernel] using boot_invariant s
  | trap scause sepc stval syscallNo syscallArg =>
    let trap : HardwareTrapEvent := { scause, sepc, stval, syscallNo, syscallArg }
    have hClosure := trap_closure_theorem s { traps := [trap] }
    have hStepInvariant := hClosure.invariantPreserved hInv
    simpa [trap, TrapTrace.events, HardwareTrapEvent.toRaw, runKernel] using hStepInvariant

theorem compositional_trap_closure_theorem (s : State) (first second : TrapTrace) :
    CompositionalTrapClosureTheorem s first second := by
  have hFirst := trap_closure_theorem s first
  have hSecond := trap_closure_theorem (runKernel s first.events).state second
  exact
    { firstClosure := hFirst
      secondClosure := hSecond
      composedClosure := trap_closure_theorem s (first.append second)
      composedRun := by
        simpa [TrapTrace.append, TrapTrace.events, List.map_append] using
          runKernel_append s first.events second.events }

theorem temporal_trap_closure_theorem (s : State) (trace : TrapTrace) :
    TemporalTrapClosureTheorem s trace where
  closure := trap_closure_theorem s trace
  prefixClosure := by
    intro tracePrefix _
    exact trap_closure_theorem s tracePrefix
  splitClosure := by
    intro first second _
    exact compositional_trap_closure_theorem s first second

theorem TemporalTrapClosureTheorem.prefix_certifies_concrete_run {s final : State}
    {trace tracePrefix : TrapTrace} {obs : List Obs}
    (h : TemporalTrapClosureTheorem s trace)
    (hprefix : tracePrefix.traps <+: trace.traps)
    (hrun : ConcreteRun s tracePrefix.events final obs)
    (stateAllowed : AbstractState -> Prop) (obsAllowed : Obs -> Prop)
    (hState : stateAllowed (erase s))
    (hpolicy : trace.ObservationPolicy (erase s) obsAllowed) :
    CertifiedTrapExecution s tracePrefix final obs stateAllowed obsAllowed :=
  (h.prefixClosure tracePrefix hprefix).certifies_concrete_run hrun
    stateAllowed obsAllowed hState
    (by
      intro trap cause ob htrap hcause
      exact hpolicy trap cause ob (hprefix.subset htrap) hcause)

theorem TemporalTrapClosureTheorem.split_certifies_concrete_run {s final : State}
    {trace first second : TrapTrace} {obs : List Obs}
    (h : TemporalTrapClosureTheorem s trace)
    (hsplit : first.traps ++ second.traps = trace.traps)
    (hrun : ConcreteRun s (first.append second).events final obs)
    (stateAllowed : AbstractState -> Prop) (obsAllowed : Obs -> Prop)
    (hState : stateAllowed (erase s))
    (hFirst : first.ObservationPolicy (erase s) obsAllowed)
    (hSecond :
      second.ObservationPolicy (erase (runKernel s first.events).state) obsAllowed) :
    CertifiedTrapExecution s (first.append second) final obs
      stateAllowed obsAllowed :=
  (h.splitClosure first second hsplit).composedClosure.certifies_concrete_run hrun
    stateAllowed obsAllowed hState
    (by
      intro trap cause ob htrap hcause
      simp [TrapTrace.append] at htrap
      rcases htrap with htrap | htrap
      · exact hFirst trap cause ob htrap hcause
      · exact hSecond trap cause ob htrap (by simpa [CauseAllows] using hcause))

private theorem raw_events_run_sound_from (s : State)
    (hInv : KernelInvariant s)
    (hResource : ResourceLedger s = ResourceLedger initialState)
    (events : List RawEvent) :
    KernelRunSound s (erase s) events
      (runKernel s events).state (runKernel s events).obs := by
  induction events generalizing s with
  | nil =>
    exact
      { concreteRun := ConcreteRun.nil s
        abstractRun := ⟨erase s, AbstractRun.nil (erase s), rfl⟩
        invariantFinal := by simpa [runKernel] using hInv
        resourcesConserved := by simp [runKernel, ResourceLedger]
        traceProvenance := by simp [runKernel, TraceHasRunProvenance] }
  | cons raw events ih =>
    cases raw with
    | boot =>
      have hHead : KernelRunSound s (erase s) [.boot]
          (runKernel s [.boot]).state (runKernel s [.boot]).obs := by
        let out := (concreteStep s .boot).value
        have hstep : concreteStep s .boot = .ok out := by
          simp [out, concreteStep, decodeRawEvent, KernelResult.value, step]
        have hout : out = bootOutput s := by
          simpa [concreteStep, decodeRawEvent, step] using hstep.symm
        have hResourceBoot : ResourceLedger out.state = ResourceLedger s := by
          rw [hout, hResource]
          simp [ResourceLedger, bootOutput, bootMemory, initialState, initialMemory,
            initialFrames, frameAccount, natListLength]
        have hFrameBoot : frameAccount out.state.memory.frames = frameAccount s.memory.frames := by
          simpa [ResourceLedger] using hResourceBoot
        have hBootable : bootable out.state = false := by
          rw [hout]
          exact bootable_false_of_boots_ne_zero (by simp [bootOutput])
        have hnext : erase out.state = AbstractOkNext (erase s) .boot := by
          cases s
          simp [hout, erase, AbstractOkNext, bootOutput]
          constructor
          · simpa [hout, bootOutput] using hFrameBoot
          · simpa [hout, bootOutput] using hBootable
        have hauth : ActionsAuthorized (erase s) .boot out.actions := by
          rw [hout]
          simp [bootOutput, bootActions, ActionsAuthorized, TraceHasAuthorityProvenance,
            observeActions, observeAction, CauseAllows]
          repeat (first | exact ⟨AuthorityCause.kernelBoot, trivial⟩ | constructor)
        simpa [runKernel, hstep, KernelResult.value] using
          { concreteRun := by
              simpa using ConcreteRun.ok hstep (ConcreteRun.nil out.state)
            abstractRun :=
              ⟨erase out.state,
                by simpa using
                  AbstractRun.cons (AbstractStep.ok hnext hauth)
                    (AbstractRun.nil (erase out.state)),
                rfl⟩
            invariantFinal := by
              simpa [runKernel, hstep, KernelResult.value] using boot_invariant s
            resourcesConserved := hResourceBoot
            traceProvenance := fun ob hob => ⟨.boot, by simp, hauth ob hob⟩ }
      have hTail := ih (runKernel s [.boot]).state hHead.invariantFinal
        (by rw [hHead.resourcesConserved, hResource])
      simpa [runKernel] using KernelRunSound.append hHead hTail
    | trap scause sepc stval syscallNo syscallArg =>
      have hHead : KernelRunSound s (erase s) [.trap scause sepc stval syscallNo syscallArg]
          (runKernel s [.trap scause sepc stval syscallNo syscallArg]).state
          (runKernel s [.trap scause sepc stval syscallNo syscallArg]).obs := by
        let trap : HardwareTrapEvent :=
          { scause, sepc, stval, syscallNo, syscallArg }
        have hClosure := trap_closure_theorem s { traps := [trap] }
        have hSound := ((fun {s : State} {trace : TrapTrace}
            (h : TrapClosureTheorem s trace) (hInv : KernelInvariant s) =>
          show KernelRunSound s (erase s) trace.events
              (runKernel s trace.events).state (runKernel s trace.events).obs from
          { concreteRun := h.concreteRun
            abstractRun := ⟨erase (runKernel s trace.events).state, h.exactAbstractRun, rfl⟩
            invariantFinal := h.invariantPreserved hInv
            resourcesConserved := h.resourcesStable
            traceProvenance := h.traceProvenance }) hClosure hInv)
        simpa [trap, TrapTrace.events, HardwareTrapEvent.toRaw] using hSound
      have hTail := ih (runKernel s [.trap scause sepc stval syscallNo syscallArg]).state
        hHead.invariantFinal
        (by rw [hHead.resourcesConserved, hResource])
      simpa [runKernel] using KernelRunSound.append hHead hTail

theorem raw_events_strongest_kernel_theorem :
    RawEventTotalCorrectness := by
  intro events
  have hSound := raw_events_run_sound_from initialState
    (show KernelInvariant initialState by
      constructor
      · simp [Accounted, initialState, initialHeap, totalAllocated]
      · exact initialMemoryInvariant)
    (by rfl) events
  exact
    { runSound := hSound
      exactAbstractRun := by
        rcases hSound.abstractRun with ⟨abstractFinal, hRun, hRefines⟩
        change abstractFinal = erase (runKernel initialState events).state at hRefines
        simpa [hRefines] using hRun
      concreteRunUnique := by
        intro final obs hrun
        exact runKernel_unique_concreteRun initialState events hrun }

theorem hardware_trace_temporal_kernel_theorem (trace : HardwareTrace) :
    TemporalStrongestKernelTheorem trace := by
  have hBoot : KernelRunSound initialState (erase initialState) [.boot]
      (runKernel initialState [.boot]).state (runKernel initialState [.boot]).obs := by
    let out := (concreteStep initialState .boot).value
    have hstep : concreteStep initialState .boot = .ok out := by
      simp [out, concreteStep, decodeRawEvent, KernelResult.value, step]
    have hnext : erase out.state = AbstractOkNext (erase initialState) .boot := by
      simp [out, AbstractOkNext, concreteStep, decodeRawEvent, KernelResult.value, step,
        bootOutput, bootHeap, bootMemory, erase, bootable, natEq, frameAccount, initialState,
        initialMemory, initialFrames, natListLength]
    have hauth : ActionsAuthorized (erase initialState) .boot out.actions := by
      have hp : match concreteStep initialState .boot with
          | .ok out => ActionsAuthorized (erase initialState) .boot out.actions
          | .error _ out => ActionsAuthorized (erase initialState) .boot out.actions := by
        simp [concreteStep, decodeRawEvent, step, bootOutput,
          bootActions, ActionsAuthorized, TraceHasAuthorityProvenance, observeActions,
          observeAction, CauseAllows]
        repeat (first | exact ⟨AuthorityCause.kernelBoot, trivial⟩ | constructor)
      simpa [hstep] using hp
    simpa [runKernel, hstep, KernelResult.value] using
      { concreteRun := by
          simpa using ConcreteRun.ok hstep (ConcreteRun.nil out.state)
        abstractRun :=
          ⟨erase out.state,
            by simpa using
              AbstractRun.cons (AbstractStep.ok hnext hauth)
                (AbstractRun.nil (erase out.state)),
            rfl⟩
        invariantFinal := by
          simp [out, concreteStep, decodeRawEvent, KernelResult.value, step,
            bootOutput, bootHeap, bootMemory]
          constructor
          · simp [Accounted, totalAllocated, bootAllocBytes, initialHeap, kernelHeapCapacity,
              kernelHeapBytes, kernelHeapPrefix]
          · simp [MemoryInvariant, DisjointFrames, MappingsUnique, MappedFramesAllocated,
              pageTableMmioL1Pfn, pageTableKernelL1Pfn, pageTableRootPfn, kernelPfn,
              kernelNextPfn, userPfn, uartPfn, clintPfn, clintVpn, uartVpn, userVpn,
              kernelVpn, mmioFlags]
        resourcesConserved := by
          have hout : out = bootOutput initialState := by
            simpa [concreteStep, decodeRawEvent, step] using hstep.symm
          simp [hout, ResourceLedger, bootOutput, bootMemory, initialState, initialMemory,
            initialFrames, frameAccount, natListLength]
        traceProvenance := fun ob hob => ⟨.boot, by simp, hauth ob hob⟩ }
  have hWhole := raw_events_strongest_kernel_theorem trace.events
  have hHardwareAuth :
      HardwareObservationsAuthorized (erase initialState) trace
        (runKernel initialState trace.events).obs := by
    intro ob hob
    rcases hWhole.runSound.traceProvenance ob hob with
      ⟨raw, hraw, cause, hcause⟩
    cases raw with
    | boot =>
      exact Or.inl ⟨cause, hcause⟩
    | trap scause sepc stval syscallNo syscallArg =>
      have htail :
          RawEvent.trap scause sepc stval syscallNo syscallArg ∈ trace.tail.events := by
        simpa [HardwareTrace.events] using hraw
      rcases List.mem_map.mp (by simpa [HardwareTrace.tail, TrapTrace.events] using htail) with
        ⟨trap, htrap, hrawEq⟩
      exact Or.inr ⟨trap, htrap, cause, by simpa [hrawEq] using hcause⟩
  exact
    { whole := hWhole
      bootSound := hBoot
      trapTemporal :=
        temporal_trap_closure_theorem (runKernel initialState [.boot]).state trace.tail
      hardwareObservationsAuthorized := hHardwareAuth
      hardwareObservationsSatisfy := by
        intro allowed hpolicy ob hob
        rcases hHardwareAuth ob hob with ⟨cause, hcause⟩ |
          ⟨trap, htrap, cause, hcause⟩
        · exact hpolicy.left cause ob hcause
        · exact hpolicy.right trap cause ob htrap hcause }

private theorem eventAuthority_contains_cause {a b : AbstractState} {raw : RawEvent}
    {cause : AuthorityCause} {ob : Obs}
    (hcause : CauseAllows a raw cause ob) :
    ∃ auth, auth ∈ eventAuthority raw ∧ AuthorityExplains b raw auth ob := by
  cases raw with
  | boot =>
    cases cause <;> cases ob <;>
      simp [CauseAllows, eventAuthority, AuthorityExplains, Authority.toCause,
        RawEvent.isBreakpoint, RawEvent.isUserEcall, RawEvent.isPageFault,
        RawEvent.isWriteByte] at hcause ⊢ <;>
      try exact hcause
  | trap scause sepc stval syscallNo syscallArg =>
    cases cause <;> cases ob <;>
      simp [CauseAllows, eventAuthority, AuthorityExplains, Authority.toCause,
        RawEvent.isBreakpoint, RawEvent.isUserEcall, RawEvent.isPageFault,
        RawEvent.isWriteByte] at hcause ⊢ <;>
      try exact hcause

private theorem kernel_raw_authority_conservation :
    RawAuthorityConservation KernelWorld.runEvents := by
  intro world events
  simpa [RawAuthorityConservation, KernelWorld.runEvents] using
    ((fun (s0 s : State) (events : List RawEvent) =>
      show NoUnauthorizedRawObservation s0 events (runKernel s events).obs from by
      induction events generalizing s with
      | nil =>
        simp [NoUnauthorizedRawObservation, runKernel]
      | cons raw events ih =>
        intro ob hob
        simp [runKernel] at hob
        rcases hob with hHead | hTail
        · rcases ((fun (s0 s : State) (raw : RawEvent) =>
            show ∀ ob, ob ∈ observeActions (concreteStep s raw).value.actions →
                ∃ auth, auth ∈ eventAuthority raw ∧ AuthorityExplains (erase s0) raw auth ob from by
            cases raw with
            | boot =>
              intro ob hob
              have hBootAuth : ActionsAuthorized (erase s0) .boot (bootOutput s).actions := by
                simp [ActionsAuthorized, TraceHasAuthorityProvenance, bootOutput, bootActions,
                  observeActions, observeAction, CauseAllows]
                repeat (first | exact ⟨AuthorityCause.kernelBoot, trivial⟩ | constructor)
              have hob' : ob ∈ observeActions (bootOutput s).actions := by
                simpa [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput] using hob
              rcases hBootAuth ob hob' with ⟨cause, hcause⟩
              exact eventAuthority_contains_cause hcause
            | trap scause sepc stval syscallNo syscallArg =>
              intro ob hob
              let trap : HardwareTrapEvent := { scause, sepc, stval, syscallNo, syscallArg }
              have hClosure := trap_closure_theorem s { traps := [trap] }
              have hobRun :
                  ob ∈ (runKernel s [.trap scause sepc stval syscallNo syscallArg]).obs := by
                simpa [runKernel] using hob
              rcases hClosure.traceProvenance ob
                  (by simpa [trap, TrapTrace.events, HardwareTrapEvent.toRaw] using hobRun) with
                ⟨raw', hraw', cause, hcause⟩
              have hraw' : raw' = .trap scause sepc stval syscallNo syscallArg := by
                simpa [trap, TrapTrace.events, HardwareTrapEvent.toRaw] using hraw'
              subst raw'
              exact eventAuthority_contains_cause hcause) s0 s raw ob hHead) with ⟨auth, hauth, hexplains⟩
          exact ⟨auth, raw, Or.inr (List.mem_flatMap_of_mem (by simp) hauth), by simp,
            hexplains⟩
        · rcases ih (concreteStep s raw).value.state ob hTail with
            ⟨auth, tailRaw, hauth, hraw, hexplains⟩
          refine ⟨auth, tailRaw, ?_, by simp [hraw], hexplains⟩
          rcases hauth with hinit | htrace
          · exact Or.inl hinit
          · refine Or.inr ?_
            rcases List.mem_flatMap.mp (by simpa [rawTraceAuthority] using htrace) with
              ⟨event, hevent, hauthEvent⟩
            exact List.mem_flatMap_of_mem (by simp [hevent]) hauthEvent) world.state world.state events)

private theorem kernel_user_write_sound :
    UserWriteSound KernelWorld.runEvents := by
  intro world events byte h
  rcases kernel_raw_authority_conservation world events (.writeUserByte byte) h with
    ⟨auth, raw, _, hraw, hexplains⟩
  have hwrite := ((fun {a : AbstractState} {raw : RawEvent} {auth : Authority} {byte : Nat}
      (h : AuthorityExplains a raw auth (.writeUserByte byte)) =>
    show raw.isWriteByte byte from by
    cases auth <;> simp [AuthorityExplains, Authority.toCause, CauseAllows] at h
    exact h) hexplains)
  exact ⟨⟨raw, hraw, hwrite⟩, ((fun {raw : RawEvent} {byte : Nat}
      (h : raw.isWriteByte byte) =>
    show byte < 256 from by
    cases raw with
    | boot =>
      simp [RawEvent.isWriteByte] at h
    | trap scause sepc stval syscallNo syscallArg =>
      by_cases h8 : scause = 8
      · subst scause
        exact ((fun {number arg byte : Nat}
            (h : decodeSyscall number arg = .writeByte byte) =>
          show byte < 256 from decodeSyscall_writeByte_lt h)
          (by simpa [RawEvent.isWriteByte] using h))
      · simp [RawEvent.isWriteByte, h8] at h) hwrite)⟩

private theorem kernel_user_write_action_task_provenance :
    UserWriteActionTaskProvenance := by
  intro s raw task byte h
  cases raw with
  | boot =>
    simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput, bootActions] at h
  | trap scause sepc stval syscallNo syscallArg =>
    by_cases h3 : scause = 3
    · subst scause
      simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, KernelResult.value] at h
    · by_cases h8 : scause = 8
      · subst scause
        cases hsys : decodeSyscall syscallNo syscallArg with
        | yield =>
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value] at h
        | writeByte syscallByte =>
          have hbyte := decodeSyscall_writeByte_lt hsys
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, hbyte, KernelResult.value, RawEvent.isWriteByte] at h ⊢
          exact ⟨h.1, h.2.symm, by simpa [h.2] using hbyte⟩
        | exit code =>
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value] at h
        | denied =>
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value] at h
      · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
        · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, handleTrap,
            KernelResult.value] at h
        · by_cases hTimer : scause = supervisorTimerScause
          · subst scause
            simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, handleTrap,
              KernelResult.value] at h
          ·
            simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, hTimer,
              handleTrap, failClosed, KernelResult.value] at h

private theorem kernel_authority_conservation :
    AuthorityConservation KernelWorld.runRaw := by
  intro world trace ob hob
  rcases kernel_raw_authority_conservation world trace.events ob
      (by simpa [KernelWorld.runEvents, KernelWorld.runRaw] using hob) with
    ⟨auth, raw, hauth, hraw, hexplains⟩
  refine ⟨auth, raw, ?_, hraw, hexplains⟩
  rcases hauth with hinit | htrace
  · exact Or.inl hinit
  · exact Or.inr (by simpa [traceAuthority, rawTraceAuthority] using htrace)

private theorem kernel_closed_world_safety :
    ClosedWorldSafety KernelWorld.runRaw := by
  intro world trace
  have hBootInv := boot_invariant world.state
  have hTail := trap_closure_theorem (runKernel world.state [.boot]).state trace.tail
  refine ⟨?_, ?_, ?_, ?_⟩
  · simpa [KernelWorld.runRaw, HardwareTrace.events, runKernel_append] using
      hTail.invariantPreserved hBootInv
  · simpa [KernelWorld.runRaw, HardwareTrace.events, runKernel_append] using
      hTail.resourcesStable
  · simpa [NoPanic, KernelWorld.runRaw] using runKernel_no_halt world.state trace.events
  · intro ob hob
    exact kernel_authority_conservation world trace ob hob

private theorem kernel_boot_sanitization :
    BootSanitization KernelWorld.runRaw := by
  intro world
  have hState :
      (KernelWorld.runRaw world { traps := [] }).state = (bootOutput world.state).state := by
    simp [KernelWorld.runRaw, HardwareTrace.events, HardwareTrace.tail, TrapTrace.events,
      runKernel, concreteStep, decodeRawEvent, step, KernelResult.value]
  have hBootable : bootable (bootOutput world.state).state = false :=
    bootable_false_of_boots_ne_zero (by simp [bootOutput])
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · simpa [KernelWorld.runRaw, HardwareTrace.events, HardwareTrace.tail, TrapTrace.events]
      using boot_invariant world.state
  · simp [hState, bootOutput]
  · simp [hState, bootOutput]
  · simp [hState, bootOutput]
  · rw [hState]
    simp [erase, bootOutput, bootMemory, ResourceLedger, initialState, initialMemory,
      initialFrames, frameAccount, natListLength, runKernel, concreteStep, decodeRawEvent,
      step, KernelResult.value]
    exact hBootable
  · simpa [NoPanic, KernelWorld.runRaw] using
      runKernel_no_halt world.state (HardwareTrace.events { traps := [] })
  · intro ob hob
    exact kernel_authority_conservation world { traps := [] } ob hob

private theorem kernel_booted_raw_event_safety :
    BootedRawEventSafety KernelWorld.runEvents := by
  intro world events
  let bootRun := runKernel world.state [.boot]
  let tailRun := runKernel bootRun.state events
  have hRun :
      KernelWorld.runEvents world (.boot :: events) =
        { state := tailRun.state, obs := bootRun.obs ++ tailRun.obs } := by
    simpa [KernelWorld.runEvents, bootRun, tailRun] using
      runKernel_append world.state [.boot] events
  have hBootInv : KernelInvariant bootRun.state := by
    simpa [bootRun] using boot_invariant world.state
  have hBootResourceInitial :
      ResourceLedger bootRun.state = ResourceLedger initialState := by
    simp [bootRun, runKernel, concreteStep, decodeRawEvent, step, KernelResult.value,
      bootOutput, bootMemory, initialState, initialMemory, initialFrames, ResourceLedger,
      frameAccount, natListLength]
  have hBootStorage :
      bootRun.state.heap = bootHeap ∧ bootRun.state.memory = bootMemory := by
    simp [bootRun, runKernel, concreteStep, decodeRawEvent, step, KernelResult.value,
      bootOutput]
  have hTailStorage := runKernel_preserves_boot_storage bootRun.state events
    hBootStorage.1 hBootStorage.2
  have hTailSound := raw_events_run_sound_from bootRun.state hBootInv
    hBootResourceInitial events
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hRun]
    exact hTailSound.invariantFinal
  · rw [hRun]
    simpa [tailRun] using hTailStorage.1
  · rw [hRun]
    simpa [tailRun] using hTailStorage.2
  · rw [hRun]
    exact hTailSound.resourcesConserved
  · simpa [BootedRawEventSafety, KernelWorld.runEvents, NoPanic] using
      runKernel_no_halt world.state (.boot :: events)
  · intro ob hob
    exact kernel_raw_authority_conservation world (.boot :: events) ob hob

private theorem kernel_boot_recovery :
    BootRecovery KernelWorld.runEvents := by
  intro world preEvents suffix
  let preRun := runKernel world.state preEvents
  let bootRun := runKernel preRun.state [.boot]
  let tailRun := runKernel bootRun.state suffix
  have hRun :
      KernelWorld.runEvents world (preEvents ++ .boot :: suffix) =
        { state := tailRun.state, obs := preRun.obs ++ bootRun.obs ++ tailRun.obs } := by
    have hPrefix := runKernel_append world.state preEvents (.boot :: suffix)
    have hBoot :
        runKernel preRun.state (.boot :: suffix) =
          { state := tailRun.state, obs := bootRun.obs ++ tailRun.obs } := by
      simpa [bootRun, tailRun] using runKernel_append preRun.state [.boot] suffix
    rw [KernelWorld.runEvents, hPrefix]
    simp [preRun, hBoot, List.append_assoc]
  have hBootInv : KernelInvariant bootRun.state := by
    simpa [bootRun] using boot_invariant preRun.state
  have hBootResourceInitial :
      ResourceLedger bootRun.state = ResourceLedger initialState := by
    simp [bootRun, runKernel, concreteStep, decodeRawEvent, step, KernelResult.value,
      bootOutput, bootMemory, initialState, initialMemory, initialFrames, ResourceLedger,
      frameAccount, natListLength]
  have hBootStorage :
      bootRun.state.heap = bootHeap ∧ bootRun.state.memory = bootMemory := by
    simp [bootRun, runKernel, concreteStep, decodeRawEvent, step, KernelResult.value,
      bootOutput]
  have hTailStorage := runKernel_preserves_boot_storage bootRun.state suffix
    hBootStorage.1 hBootStorage.2
  have hTailSound := raw_events_run_sound_from bootRun.state hBootInv
    hBootResourceInitial suffix
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hRun]
    exact hTailSound.invariantFinal
  · rw [hRun]
    simpa [tailRun] using hTailStorage.1
  · rw [hRun]
    simpa [tailRun] using hTailStorage.2
  · rw [hRun]
    exact hTailSound.resourcesConserved
  · simpa [BootRecovery, KernelWorld.runEvents, NoPanic] using
      runKernel_no_halt world.state (preEvents ++ .boot :: suffix)
  · intro ob hob
    exact kernel_raw_authority_conservation world (preEvents ++ .boot :: suffix) ob hob

private theorem runKernel_task (s : State) (events : List RawEvent) :
    (runKernel s events).state.task = taskAfterEvents s.task events := by
  induction events generalizing s with
  | nil =>
    simp [runKernel, taskAfterEvents]
  | cons raw events ih =>
    have hHead :
        (concreteStep s raw).value.state.task = taskAfterRaw s.task raw := by
      cases raw with
      | boot =>
        simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput, taskAfterRaw]
      | trap scause sepc stval syscallNo syscallArg =>
        by_cases h3 : scause = 3
        · subst scause
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, KernelResult.value,
            taskAfterRaw]
        · by_cases h8 : scause = 8
          · subst scause
            cases hsys : decodeSyscall syscallNo syscallArg with
            | yield =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, taskAfterRaw, taskAfterSyscall]
            | writeByte byte =>
              have hbyte := decodeSyscall_writeByte_lt hsys
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, hbyte, KernelResult.value, taskAfterRaw, taskAfterSyscall]
            | exit code =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, taskAfterRaw, taskAfterSyscall]
            | denied =>
              simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
                hsys, KernelResult.value, taskAfterRaw, taskAfterSyscall]
          · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
            · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage,
                handleTrap, KernelResult.value, taskAfterRaw]
            · by_cases hTimer : scause = supervisorTimerScause
              · subst scause
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, handleTrap,
                  KernelResult.value, taskAfterRaw]
              ·
                simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, hTimer,
                  handleTrap, failClosed, KernelResult.value, taskAfterRaw]
    have hTail := ih (concreteStep s raw).value.state
    simpa [runKernel, taskAfterEvents, hHead] using hTail

private theorem kernel_task_model_sound :
    TaskModelSound KernelWorld.runEvents := by
  intro world events
  simpa [TaskModelSound, KernelWorld.runEvents] using runKernel_task world.state events

private theorem kernel_user_task_progress :
    UserTaskProgress KernelWorld.runEvents := by
  intro world
  have hTask := congrArg Task.status (runKernel_task world.state [.boot, userExitEvent])
  simpa [UserTaskProgress, KernelWorld.runEvents, userExitEvent, taskAfterEvents,
    taskAfterRaw, taskAfterSyscall, decodeSyscall, syscallYield, syscallWriteByte, syscallExit]
    using hTask

private theorem kernel_user_cannot_mutate_kernel_memory :
    UserCannotMutateKernelMemory KernelWorld.runEvents := by
  intro world events
  let bootRun := runKernel world.state [.boot]
  have hBootStorage :
      bootRun.state.heap = bootHeap ∧ bootRun.state.memory = bootMemory := by
    simp [bootRun, runKernel, concreteStep, decodeRawEvent, step, KernelResult.value,
      bootOutput]
  have hTailStorage := runKernel_preserves_boot_storage bootRun.state events
    hBootStorage.1 hBootStorage.2
  simpa [UserCannotMutateKernelMemory, KernelWorld.runEvents, bootRun, runKernel] using
    hTailStorage.2

private theorem concreteStep_scheduler (s : State) (raw : RawEvent) :
    (concreteStep s raw).value.state.scheduler = schedulerAfterRaw s.scheduler raw := by
  cases raw with
  | boot =>
    simp [concreteStep, decodeRawEvent, step, KernelResult.value, bootOutput, schedulerAfterRaw]
  | trap scause sepc stval syscallNo syscallArg =>
    by_cases h3 : scause = 3
    · subst scause
      simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, KernelResult.value,
        schedulerAfterRaw]
    · by_cases h8 : scause = 8
      · subst scause
        cases hsys : decodeSyscall syscallNo syscallArg with
        | yield =>
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value, schedulerAfterRaw]
        | writeByte byte =>
          have hbyte := decodeSyscall_writeByte_lt hsys
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, hbyte, KernelResult.value, schedulerAfterRaw]
        | exit code =>
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value, schedulerAfterRaw]
        | denied =>
          have hDenied : schedulerAfterSyscall s.scheduler .denied = s.scheduler := by
            cases s.scheduler with
            | mk task0 task1 current =>
              cases current <;>
                simp [schedulerAfterSyscall, SchedulerState.updateCurrentTask,
                  SchedulerState.updateTask, SchedulerState.currentTask, SchedulerState.taskById,
                  taskAfterSyscall]
          simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall,
            hsys, KernelResult.value, schedulerAfterRaw, hDenied]
      · by_cases hPage : scause = 12 ∨ scause = 13 ∨ scause = 15
        · simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, handleTrap,
            KernelResult.value, schedulerAfterRaw]
        · by_cases hTimer : scause = supervisorTimerScause
          · subst scause
            simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, handleTrap,
              KernelResult.value, schedulerAfterRaw]
          ·
            simp [concreteStep, decodeRawEvent, step, decodeTrap, h3, h8, hPage, hTimer,
              handleTrap, failClosed, KernelResult.value, schedulerAfterRaw]

private theorem runKernel_scheduler (s : State) (events : List RawEvent) :
    (runKernel s events).state.scheduler = schedulerAfterEvents s.scheduler events := by
  induction events generalizing s with
  | nil =>
    simp [runKernel, schedulerAfterEvents]
  | cons raw events ih =>
    have hHead := concreteStep_scheduler s raw
    have hTail := ih (concreteStep s raw).value.state
    simpa [runKernel, schedulerAfterEvents, hHead] using hTail

private theorem kernel_scheduler_model_sound :
    SchedulerModelSound KernelWorld.runEvents := by
  intro world events
  simpa [SchedulerModelSound, KernelWorld.runEvents] using runKernel_scheduler world.state events

private theorem kernel_scheduler_full_abstraction :
    SchedulerFullAbstraction KernelWorld.runEvents := by
  intro world₁ world₂ events h
  rw [kernel_scheduler_model_sound world₁ events, kernel_scheduler_model_sound world₂ events, h]

private theorem kernel_current_task_only_changes :
    CurrentTaskOnlyChanges KernelWorld.runEvents := by
  intro world syscallNo syscallArg tid h
  have hStep := congrArg (fun scheduler => scheduler.taskById tid)
    (concreteStep_scheduler world.state (.trap 8 0 0 syscallNo syscallArg))
  have hOther := ((fun {scheduler : SchedulerState} {syscall : Syscall} {tid : TaskId}
      (h : tid ≠ scheduler.current) =>
    show (schedulerAfterSyscall scheduler syscall).taskById tid = scheduler.taskById tid from by
    cases scheduler with
    | mk task0 task1 current =>
      cases current <;> cases tid <;> cases syscall <;>
        simp [schedulerAfterSyscall, SchedulerState.advance, SchedulerState.updateCurrentTask,
          SchedulerState.updateTask, SchedulerState.currentTask, SchedulerState.taskById,
          TaskId.next, taskAfterSyscall] at h ⊢)
    (scheduler := world.state.scheduler) (syscall := decodeSyscall syscallNo syscallArg) h)
  simpa [CurrentTaskOnlyChanges, KernelWorld.runEvents, runKernel, schedulerAfterRaw] using
    hStep.trans hOther

theorem RoundRobinFairness :
    RoundRobinFairnessSpec KernelWorld.runEvents := by
  intro world
  have hModel :
      (schedulerAfterEvents world.state.scheduler [schedulerYieldEvent]).current =
          world.state.scheduler.current.next ∧
        (schedulerAfterEvents world.state.scheduler [schedulerTimerEvent]).current =
          world.state.scheduler.current.next ∧
        (schedulerAfterEvents world.state.scheduler [schedulerYieldEvent, schedulerYieldEvent]).current =
          world.state.scheduler.current ∧
        (schedulerAfterEvents world.state.scheduler [schedulerTimerEvent, schedulerTimerEvent]).current =
          world.state.scheduler.current ∧
        (schedulerAfterEvents world.state.scheduler [schedulerYieldEvent, schedulerTimerEvent]).current =
          world.state.scheduler.current ∧
        (schedulerAfterEvents world.state.scheduler [schedulerTimerEvent, schedulerYieldEvent]).current =
          world.state.scheduler.current := by
    cases world.state.scheduler with
    | mk task0 task1 current =>
      cases current <;>
        simp [schedulerAfterEvents, schedulerAfterRaw, schedulerYieldEvent, schedulerTimerEvent,
          decodeSyscall, syscallYield, schedulerAfterSyscall, SchedulerState.advance,
          SchedulerState.updateCurrentTask, SchedulerState.updateTask, SchedulerState.currentTask,
          SchedulerState.taskById, TaskId.next, taskAfterSyscall]
  have hOne := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerYieldEvent])
  have hTimer := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerTimerEvent])
  have hTwo := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerYieldEvent, schedulerYieldEvent])
  have hTimerTwo := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerTimerEvent, schedulerTimerEvent])
  have hYieldTimer := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerYieldEvent, schedulerTimerEvent])
  have hTimerYield := congrArg SchedulerState.current
    (runKernel_scheduler world.state [schedulerTimerEvent, schedulerYieldEvent])
  exact
    ⟨by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using hOne.trans hModel.1,
      by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using hTimer.trans hModel.2.1,
      by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using hTwo.trans hModel.2.2.1,
      by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using
        hTimerTwo.trans hModel.2.2.2.1,
      by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using
        hYieldTimer.trans hModel.2.2.2.2.1,
      by simpa [RoundRobinFairnessSpec, KernelWorld.runEvents] using
        hTimerYield.trans hModel.2.2.2.2.2⟩

private theorem kernel_scheduler_cannot_mutate_kernel_memory :
    SchedulerCannotMutateKernelMemory KernelWorld.runEvents := by
  intro world syscallNo syscallArg
  cases hsys : decodeSyscall syscallNo syscallArg with
  | yield =>
    simp [KernelWorld.runEvents, runKernel, concreteStep,
      decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall, hsys, KernelResult.value]
  | writeByte byte =>
    have hbyte := decodeSyscall_writeByte_lt hsys
    simp [KernelWorld.runEvents, runKernel, concreteStep,
      decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall, hsys, hbyte,
      KernelResult.value]
  | exit code =>
    simp [KernelWorld.runEvents, runKernel, concreteStep,
      decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall, hsys, KernelResult.value]
  | denied =>
    simp [KernelWorld.runEvents, runKernel, concreteStep,
      decodeRawEvent, step, decodeTrap, handleTrap, handleSyscall, hsys, KernelResult.value]

private theorem kernel_pageFault_kills_current_task_preserves_invariant :
    PageFaultKillsCurrentTaskPreservesInvariant KernelWorld.runEvents := by
  intro world scause sepc stval syscallNo syscallArg hPage hInv
  change scause = 12 ∨ scause = 13 ∨ scause = 15 at hPage
  rcases hPage with hPage | hPage | hPage <;> subst scause
  all_goals
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap]
    · simpa [PageFaultKillsCurrentTaskPreservesInvariant, KernelWorld.runEvents,
        runKernel, concreteStep, decodeRawEvent, step, decodeTrap, handleTrap,
        KernelResult.value] using hInv
    · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
        handleTrap, KernelResult.value]
    · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
        handleTrap, KernelResult.value]
    · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
        handleTrap, KernelResult.value]
    · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
        handleTrap, KernelResult.value]
    · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
        handleTrap, KernelResult.value, observeActions, observeAction]

private theorem kernel_timerInterrupt_preserves_invariant :
    TimerInterruptPreservesInvariant KernelWorld.runEvents := by
  intro world sepc stval syscallNo syscallArg hInv
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · simp [concreteStep, decodeRawEvent, step, decodeTrap, handleTrap]
  · simpa [TimerInterruptPreservesInvariant, KernelWorld.runEvents, runKernel, concreteStep,
      decodeRawEvent, step, decodeTrap, handleTrap, KernelResult.value] using hInv
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value]
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value]
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value]
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value]
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value]
  · simp [KernelWorld.runEvents, runKernel, concreteStep, decodeRawEvent, step, decodeTrap,
      handleTrap, KernelResult.value, observeActions, observeAction]

theorem lean_kernel_satisfies_contract : TheoremFirstKernel where
  fullAbstraction := kernel_full_abstraction
  panicFreedom := kernel_panic_freedom
  bootCountSound := kernel_boot_count_sound
  userEntrySound := kernel_user_entry_sound
  userWriteSound := kernel_user_write_sound
  userWriteActionTaskProvenance := kernel_user_write_action_task_provenance
  rawAuthorityConservation := kernel_raw_authority_conservation
  authorityConservation := kernel_authority_conservation
  closedWorldSafety := kernel_closed_world_safety
  bootSanitization := kernel_boot_sanitization
  bootedRawEventSafety := kernel_booted_raw_event_safety
  bootRecovery := kernel_boot_recovery
  taskModelSound := kernel_task_model_sound
  userTaskProgress := kernel_user_task_progress
  userCannotMutateKernelMemory := kernel_user_cannot_mutate_kernel_memory
  pageFault_kills_current_task_preserves_invariant :=
    kernel_pageFault_kills_current_task_preserves_invariant
  timerInterrupt_preserves_invariant := kernel_timerInterrupt_preserves_invariant
  stepPreservesInvariant := step_preserves_invariant
  initialHeapRefinesRuntimeBumpAllocator := initial_heap_refines_initial_bump_allocator
  bumpAllocRefinesAlloc := @bump_alloc_refines_alloc
  rawEventTotalCorrectness := raw_events_strongest_kernel_theorem
  schedulerModelSound := kernel_scheduler_model_sound
  schedulerFullAbstraction := kernel_scheduler_full_abstraction
  currentTaskOnlyChanges := kernel_current_task_only_changes
  roundRobinFairness := RoundRobinFairness
  schedulerCannotMutateKernelMemory := kernel_scheduler_cannot_mutate_kernel_memory

end Kernel
