namespace Kernel.Sv39

def entriesPerTable : Nat := 512
def secondLevelSpan : Nat := 262144
def ptePpnFactor : Nat := 1024

def vpnIndex (level vpn : Nat) : Nat :=
  match level with
  | 0 => vpn % entriesPerTable
  | 1 => (vpn / entriesPerTable) % entriesPerTable
  | _ => (vpn / secondLevelSpan) % entriesPerTable

theorem vpnIndex_lt_entriesPerTable (level vpn : Nat) :
    vpnIndex level vpn < entriesPerTable := by
  cases level with
  | zero =>
    exact Nat.mod_lt vpn (by decide)
  | succ level =>
    cases level with
    | zero =>
      exact Nat.mod_lt (vpn / entriesPerTable) (by decide)
    | succ _ =>
      exact Nat.mod_lt (vpn / secondLevelSpan) (by decide)

structure PteFlags where
  readable : Bool
  writable : Bool
  executable : Bool
  user : Bool
  global : Bool
  accessed : Bool
  dirty : Bool

def bitIf (enabled : Bool) (bit : Nat) : Nat :=
  if enabled then bit else 0

def PteFlags.bits (flags : PteFlags) : Nat :=
  1 +
  bitIf flags.readable 2 +
  bitIf flags.writable 4 +
  bitIf flags.executable 8 +
  bitIf flags.user 16 +
  bitIf flags.global 32 +
  bitIf flags.accessed 64 +
  bitIf flags.dirty 128

def tableFlags : PteFlags :=
  { readable := false, writable := false, executable := false, user := false,
    global := false, accessed := false, dirty := false }

def kernelFlags : PteFlags :=
  { readable := true, writable := true, executable := true, user := false,
    global := true, accessed := true, dirty := true }

def mmioFlags : PteFlags :=
  { readable := true, writable := true, executable := false, user := false,
    global := true, accessed := true, dirty := true }

def userCodeFlags : PteFlags :=
  { readable := true, writable := false, executable := true, user := true,
    global := false, accessed := true, dirty := false }

def encodePte (pfn : Nat) (flags : PteFlags) : Nat :=
  pfn * ptePpnFactor + flags.bits

structure MapPlan where
  rootFrame : Nat
  kernelL1Frame : Nat
  mmioL1Frame : Nat
  kernelBasePfn : Nat
  kernelNextPfn : Nat
  uartPfn : Nat
  clintPfn : Nat
  userPfn : Nat
  kernelRootIndex : Nat
  uartRootIndex : Nat
  kernelBaseIndex : Nat
  kernelNextIndex : Nat
  uartIndex : Nat
  clintIndex : Nat
  userIndex : Nat
  kernelRootPte : Nat
  uartRootPte : Nat
  kernelBasePte : Nat
  kernelNextPte : Nat
  uartPte : Nat
  clintPte : Nat
  userPte : Nat

def buildMapPlan (rootFrame kernelL1Frame mmioL1Frame kernelBasePfn kernelNextPfn
    uartPfn clintPfn userPfn kernelBaseVpn kernelNextVpn uartVpn clintVpn userVpn : Nat) :
    MapPlan :=
  { rootFrame,
    kernelL1Frame,
    mmioL1Frame,
    kernelBasePfn,
    kernelNextPfn,
    uartPfn,
    clintPfn,
    userPfn,
    kernelRootIndex := vpnIndex 2 kernelBaseVpn,
    uartRootIndex := vpnIndex 2 uartVpn,
    kernelBaseIndex := vpnIndex 1 kernelBaseVpn,
    kernelNextIndex := vpnIndex 1 kernelNextVpn,
    uartIndex := vpnIndex 1 uartVpn,
    clintIndex := vpnIndex 1 clintVpn,
    userIndex := vpnIndex 1 userVpn,
    kernelRootPte := encodePte kernelL1Frame tableFlags,
    uartRootPte := encodePte mmioL1Frame tableFlags,
    kernelBasePte := encodePte kernelBasePfn kernelFlags,
    kernelNextPte := encodePte kernelNextPfn kernelFlags,
    uartPte := encodePte uartPfn mmioFlags,
    clintPte := encodePte clintPfn mmioFlags,
    userPte := encodePte userPfn userCodeFlags }

end Kernel.Sv39
