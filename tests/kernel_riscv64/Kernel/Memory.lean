import Kernel.Sv39

namespace Kernel

structure FrameAlloc where
  free : List Nat
  used : List Nat

def DisjointFrames (free used : List Nat) : Prop :=
  ∀ frame, frame ∈ free -> frame ∈ used -> False

def FrameAllocInvariant (fa : FrameAlloc) : Prop :=
  fa.free.Nodup ∧ fa.used.Nodup ∧ DisjointFrames fa.free fa.used

def natListLength : List Nat -> Nat
  | [] => 0
  | _ :: xs => natListLength xs + 1

def frameAccount (fa : FrameAlloc) : Nat :=
  natListLength fa.free + natListLength fa.used

def allocFrame? (fa : FrameAlloc) : Option (Nat × FrameAlloc) :=
  match fa.free with
  | [] => none
  | frame :: free =>
    some (frame, { free, used := frame :: fa.used })

def allocFrames? : Nat -> FrameAlloc -> Option (List Nat × FrameAlloc)
  | 0, fa => some ([], fa)
  | fuel + 1, fa =>
    match allocFrame? fa with
    | none => none
    | some (frame, fa) =>
      match allocFrames? fuel fa with
      | none => none
      | some (frames, fa) => some (frame :: frames, fa)

theorem allocFrame?_records {fa fa' : FrameAlloc} {frame : Nat}
    (hr : allocFrame? fa = some (frame, fa')) : frame ∈ fa'.used := by
  cases fa with
  | mk free used =>
    cases free with
    | nil =>
      simp [allocFrame?] at hr
    | cons frame' free' =>
      simp [allocFrame?] at hr
      rcases hr with ⟨hframe, hfa⟩
      subst frame
      subst fa'
      simp

theorem allocFrame?_removes_from_free {fa fa' : FrameAlloc} {frame : Nat}
    (hn : fa.free.Nodup) (hr : allocFrame? fa = some (frame, fa')) :
    frame ∉ fa'.free := by
  cases fa with
  | mk free used =>
    cases free with
    | nil =>
      simp [allocFrame?] at hr
    | cons frame' free' =>
      simp [allocFrame?] at hr
      rcases hr with ⟨hframe, hfa⟩
      subst frame
      subst fa'
      have hnodup : (frame' :: free').Nodup := hn
      simp at hnodup
      exact hnodup.1

theorem allocFrame?_preserves_invariant {fa fa' : FrameAlloc} {frame : Nat}
    (hi : FrameAllocInvariant fa) (hr : allocFrame? fa = some (frame, fa')) :
    FrameAllocInvariant fa' := by
  cases fa with
  | mk free used =>
    cases free with
    | nil =>
      simp [allocFrame?] at hr
    | cons frame' free' =>
      simp [allocFrame?] at hr
      rcases hr with ⟨hframe, hfa⟩
      subst frame
      subst fa'
      rcases hi with ⟨hfree, hused, hdisjoint⟩
      simp at hfree
      constructor
      · exact hfree.2
      · constructor
        · constructor
          · intro frame hmem
            intro heq
            exact hdisjoint frame' (by simp) (heq ▸ hmem)
          · exact hused
        · intro frame hfree' hused'
          simp at hused'
          rcases hused' with rfl | husedOld
          · exact hfree.1 hfree'
          ·
            exact hdisjoint frame (by simp [hfree']) husedOld

theorem allocFrame?_preserves_account {fa fa' : FrameAlloc} {frame : Nat}
    (hr : allocFrame? fa = some (frame, fa')) :
    frameAccount fa' = frameAccount fa := by
  cases fa with
  | mk free used =>
    cases free with
    | nil =>
      simp [allocFrame?] at hr
    | cons frame' free' =>
      simp [allocFrame?] at hr
      rcases hr with ⟨hframe, hfa⟩
      subst frame
      subst fa'
      unfold frameAccount
      simp [natListLength]
      omega

theorem allocFrames?_preserves_invariant {n : Nat} {fa fa' : FrameAlloc}
    {frames : List Nat} (hi : FrameAllocInvariant fa)
    (hr : allocFrames? n fa = some (frames, fa')) :
    FrameAllocInvariant fa' := by
  induction n generalizing fa frames fa' with
  | zero =>
    simp [allocFrames?] at hr
    rcases hr with ⟨_, hfa⟩
    subst fa'
    exact hi
  | succ n ih =>
    unfold allocFrames? at hr
    cases halloc : allocFrame? fa with
    | none =>
      simp [halloc] at hr
    | some frameAndAlloc =>
      rcases frameAndAlloc with ⟨frame, fa1⟩
      cases hrest : allocFrames? n fa1 with
      | none =>
        simp [halloc, hrest] at hr
      | some framesAndAlloc =>
        rcases framesAndAlloc with ⟨frames1, fa2⟩
        simp [halloc, hrest] at hr
        rcases hr with ⟨_, hfa⟩
        subst fa'
        exact ih (allocFrame?_preserves_invariant hi halloc) hrest

theorem allocFrames?_preserves_account {n : Nat} {fa fa' : FrameAlloc}
    {frames : List Nat} (hr : allocFrames? n fa = some (frames, fa')) :
    frameAccount fa' = frameAccount fa := by
  induction n generalizing fa frames fa' with
  | zero =>
    simp [allocFrames?] at hr
    rcases hr with ⟨_, hfa⟩
    subst fa'
    rfl
  | succ n ih =>
    unfold allocFrames? at hr
    cases halloc : allocFrame? fa with
    | none =>
      simp [halloc] at hr
    | some frameAndAlloc =>
      rcases frameAndAlloc with ⟨frame, fa1⟩
      cases hrest : allocFrames? n fa1 with
      | none =>
        simp [halloc, hrest] at hr
      | some framesAndAlloc =>
        rcases framesAndAlloc with ⟨frames1, fa2⟩
        simp [halloc, hrest] at hr
        rcases hr with ⟨_, hfa⟩
        subst fa'
        exact (ih hrest).trans (allocFrame?_preserves_account halloc)

structure PteFlags where
  readable : Bool
  writable : Bool
  executable : Bool

structure Mapping where
  vpn : Nat
  pfn : Nat
  flags : PteFlags

structure PageTable where
  entries : List Mapping

def walkEntries : List Mapping -> Nat -> Option Mapping
  | [], _ => none
  | m :: rest, vpn =>
    if m.vpn = vpn then some m else walkEntries rest vpn

def walk (pt : PageTable) (vpn : Nat) : Option Mapping :=
  walkEntries pt.entries vpn

def mapPage? (pt : PageTable) (vpn pfn : Nat) (flags : PteFlags) : Option PageTable :=
  match walk pt vpn with
  | some _ => none
  | none => some { entries := { vpn, pfn, flags } :: pt.entries }

theorem walk_after_mapPage? {pt pt' : PageTable} {vpn pfn : Nat} {flags : PteFlags}
    (hr : mapPage? pt vpn pfn flags = some pt') :
    walk pt' vpn = some { vpn, pfn, flags } := by
  unfold mapPage? at hr
  split at hr
  · contradiction
  · cases hr
    simp [walk, walkEntries]

structure Memory where
  frames : FrameAlloc
  pageTable : PageTable

def MappingsUnique (pt : PageTable) : Prop :=
  (pt.entries.map Mapping.vpn).Nodup

def MappedFramesAllocated (m : Memory) : Prop :=
  ∀ entry, entry ∈ m.pageTable.entries -> entry.pfn ∈ m.frames.used

def MemoryInvariant (m : Memory) : Prop :=
  m.frames.free.Nodup ∧
  m.frames.used.Nodup ∧
  DisjointFrames m.frames.free m.frames.used ∧
  MappingsUnique m.pageTable ∧
  MappedFramesAllocated m

def kernelPfn : Nat := 0x80200
def kernelNextPfn : Nat := 0x80400
def userPfn : Nat := 0x80600
def uartPfn : Nat := 0x10000
def clintPfn : Nat := 0x2000
def pageTableRootPfn : Nat := 0x80300
def pageTableKernelL1Pfn : Nat := 0x80301
def pageTableMmioL1Pfn : Nat := 0x80302

def initialFrames : FrameAlloc :=
  { free := [pageTableRootPfn, pageTableKernelL1Pfn, pageTableMmioL1Pfn],
    used := [kernelPfn, kernelNextPfn, userPfn, uartPfn, clintPfn] }

theorem initialFrameAllocInvariant : FrameAllocInvariant initialFrames := by
  simp [FrameAllocInvariant, initialFrames, DisjointFrames, kernelPfn, kernelNextPfn,
    userPfn, uartPfn, clintPfn, pageTableRootPfn, pageTableKernelL1Pfn,
    pageTableMmioL1Pfn]

def initialPageTable : PageTable :=
  { entries := [] }

def initialMemory : Memory :=
  { frames := initialFrames, pageTable := initialPageTable }

theorem initialMemoryInvariant : MemoryInvariant initialMemory := by
  simp [MemoryInvariant, initialMemory, initialFrames, initialPageTable, DisjointFrames,
    MappingsUnique, MappedFramesAllocated, kernelPfn, kernelNextPfn, userPfn, uartPfn,
    clintPfn, pageTableRootPfn, pageTableKernelL1Pfn, pageTableMmioL1Pfn]

def kernelVpn : Nat := 0x80200
def kernelNextVpn : Nat := 0x80400
def userVpn : Nat := 0x80600
def uartVpn : Nat := 0x10000
def clintVpn : Nat := 0x2000
def userEntry : Nat := userVpn * 4096

def kernelFlags : PteFlags :=
  { readable := true, writable := true, executable := true }

def mmioFlags : PteFlags :=
  { readable := true, writable := true, executable := false }

def userFlags : PteFlags :=
  { readable := true, writable := false, executable := true }

end Kernel
