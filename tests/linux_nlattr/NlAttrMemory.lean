namespace LeanNlAttr
namespace Memory

def nlaHeaderBytes : Nat := 4
def nlaFlagNested : UInt64 := 0x8000
def nlaTypeMask : UInt64 := 0x3fff

structure Region where
  bytes : ByteArray
  totalLen : Nat
  totalLen_le_size : totalLen ≤ bytes.size

def Region.ofBytes (bytes : ByteArray) : Region :=
  { bytes := bytes, totalLen := bytes.size, totalLen_le_size := Nat.le_refl _ }

@[always_inline]
def attrHeaderLen (header : UInt64) : UInt64 :=
  header &&& 0xffffffff

@[always_inline]
def attrHeaderType (header : UInt64) : UInt64 :=
  ((header >>> 32) &&& 0xffff) &&& nlaTypeMask

@[always_inline]
def attrHeaderIsNested (header : UInt64) : UInt64 :=
  if (((header >>> 32) &&& 0xffff) &&& nlaFlagNested) != 0 then 1 else 0

@[always_inline]
def align4Nat (n : Nat) : Nat :=
  ((n + 3) / 4) * 4

@[always_inline]
def Region.byteAt (r : Region) (i : Nat) (h : i < r.bytes.size) : UInt64 :=
  (r.bytes.get i h).toUInt64

@[always_inline]
def Region.header (r : Region) (off : Nat)
    (h : off + nlaHeaderBytes ≤ r.totalLen) : UInt64 :=
  let b0 := r.byteAt off (by
    have hs := r.totalLen_le_size
    unfold nlaHeaderBytes at h
    omega)
  let b1 := r.byteAt (off + 1) (by
    have hs := r.totalLen_le_size
    unfold nlaHeaderBytes at h
    omega)
  let b2 := r.byteAt (off + 2) (by
    have hs := r.totalLen_le_size
    unfold nlaHeaderBytes at h
    omega)
  let b3 := r.byteAt (off + 3) (by
    have hs := r.totalLen_le_size
    unfold nlaHeaderBytes at h
    omega)
  b0 ||| (b1 <<< 8) ||| ((b2 ||| (b3 <<< 8)) <<< 32)

@[always_inline]
def Region.payloadByte (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix < r.totalLen) : UInt64 :=
  r.byteAt (off + nlaHeaderBytes + ix) (by
    have hs := r.totalLen_le_size
    omega)

def Region.attrWordAux (r : Region) (off ix count : Nat)
    (shift acc : UInt64)
    (h : off + nlaHeaderBytes + ix + count ≤ r.totalLen) : UInt64 :=
  match count with
  | 0 => acc
  | count' + 1 =>
      let byte := r.payloadByte off ix (by
        unfold nlaHeaderBytes at h
        unfold nlaHeaderBytes
        omega)
      r.attrWordAux off (ix + 1) count' (shift + 8)
        (acc ||| (byte <<< shift)) (by
          unfold nlaHeaderBytes at h
          unfold nlaHeaderBytes
          omega)

def Region.attrWord (r : Region) (off ix count : Nat)
    (h : off + nlaHeaderBytes + ix + count ≤ r.totalLen) : UInt64 :=
  r.attrWordAux off ix count 0 0 h

@[always_inline]
def Region.readPayloadLE16 (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix + 2 ≤ r.totalLen) : UInt64 :=
  r.attrWord off ix 2 h

@[always_inline]
def Region.readPayloadLE32 (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix + 4 ≤ r.totalLen) : UInt64 :=
  r.attrWord off ix 4 h

@[always_inline]
def Region.readPayloadLE64 (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix + 8 ≤ r.totalLen) : UInt64 :=
  r.attrWord off ix 8 h

@[always_inline]
def Region.readPayloadBE16 (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix + 2 ≤ r.totalLen) : UInt64 :=
  (r.payloadByte off ix (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega) <<< 8)
    + r.payloadByte off (ix + 1) (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega)

@[always_inline]
def Region.readPayloadBE32 (r : Region) (off ix : Nat)
    (h : off + nlaHeaderBytes + ix + 4 ≤ r.totalLen) : UInt64 :=
  (r.payloadByte off ix (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega) <<< 24)
    + (r.payloadByte off (ix + 1) (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega) <<< 16)
    + (r.payloadByte off (ix + 2) (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega) <<< 8)
    + r.payloadByte off (ix + 3) (by
      unfold nlaHeaderBytes at h
      unfold nlaHeaderBytes
      omega)

def findLoop (r : Region) (target : UInt64) (fuel off : Nat) : Option Nat :=
  match fuel with
  | 0 => none
  | fuel' + 1 =>
      if off == r.totalLen then
        none
      else if hHeader : off + nlaHeaderBytes ≤ r.totalLen then
        let header := r.header off hHeader
        let len := (attrHeaderLen header).toNat
        if len < nlaHeaderBytes then
          none
        else if _hEnd : off + len ≤ r.totalLen then
          if attrHeaderType header == target then
            some off
          else
            let next := off + align4Nat len
            if next > r.totalLen then
              none
            else
              findLoop r target fuel' next
        else
          none
      else
        none

def find? (r : Region) (target : UInt64) : Option Nat :=
  findLoop r target (r.totalLen + 1) 0

namespace Layout

def headerLen : Nat := nlaHeaderBytes

@[always_inline]
def align4 (n : Nat) : Nat :=
  align4Nat n

def attrSize (payloadLen : Nat) : Nat :=
  headerLen + payloadLen

def totalSize (payloadLen : Nat) : Nat :=
  align4 (attrSize payloadLen)

def padLen (payloadLen : Nat) : Nat :=
  totalSize payloadLen - attrSize payloadLen

structure WireAttr where
  ty : Nat
  payloadLen : Nat
  nested : Bool
deriving Inhabited, Repr

def wireAttrSize (attr : WireAttr) : Nat :=
  attrSize attr.payloadLen

def wireTotalSize (attr : WireAttr) : Nat :=
  totalSize attr.payloadLen

def headerFits (total off : Nat) : Prop :=
  off + headerLen ≤ total

def payloadFits (total off : Nat) (attr : WireAttr) : Prop :=
  off + wireAttrSize attr ≤ total

def nextOff (off : Nat) (attr : WireAttr) : Nat :=
  off + wireTotalSize attr

def streamSize : List WireAttr → Nat
  | [] => 0
  | attr :: rest => wireTotalSize attr + streamSize rest

def entries (off : Nat) : List WireAttr → List (Nat × WireAttr)
  | [] => []
  | attr :: rest => (off, attr) :: entries (nextOff off attr) rest

def findOffset (target off : Nat) : List WireAttr → Option Nat
  | [] => none
  | attr :: rest =>
      if attr.ty == target then
        some off
      else
        findOffset target (nextOff off attr) rest

def findLoop (target fuel off : Nat) (attrs : List WireAttr) : Option Nat :=
  match fuel, attrs with
  | 0, _ => none
  | _, [] => none
  | fuel' + 1, attr :: rest =>
      if attr.ty == target then
        some off
      else
        findLoop target fuel' (nextOff off attr) rest

def find? (attrs : List WireAttr) (target : Nat) : Option Nat :=
  findLoop target (attrs.length + 1) 0 attrs

def regionCheckedAttrAt?
    (r : Region) (off : Nat) :
    Option { attr : WireAttr // payloadFits r.totalLen off attr } :=
  if hHeader : off + headerLen ≤ r.totalLen then
    let header := r.header off hHeader
    let len := (attrHeaderLen header).toNat
    if hLen : len < headerLen then
      none
    else if hPayload : off + len ≤ r.totalLen then
      some
        ⟨{ ty := (attrHeaderType header).toNat,
           payloadLen := len - headerLen,
           nested := attrHeaderIsNested header != 0 },
          by
            unfold payloadFits wireAttrSize attrSize
            change off + (headerLen + (len - headerLen)) ≤ r.totalLen
            omega⟩
    else
      none
  else
    none

def regionWireAttrAt? (r : Region) (off : Nat) : Option WireAttr :=
  match regionCheckedAttrAt? r off with
  | some attr => some attr.val
  | none => none

def regionParseAttrsLoop
    (r : Region) (fuel off : Nat) : Option (List WireAttr) :=
  match fuel with
  | 0 => none
  | fuel' + 1 =>
      if off == r.totalLen then
        some []
      else
        match regionCheckedAttrAt? r off with
        | none => none
        | some checked =>
            let attr := checked.val
            let next := off + wireTotalSize attr
            if next > r.totalLen then
              some [attr]
            else
              match regionParseAttrsLoop r fuel' next with
              | some rest => some (attr :: rest)
              | none => none

def regionParseAttrs? (r : Region) : Option (List WireAttr) :=
  regionParseAttrsLoop r (r.totalLen + 1) 0

theorem regionWireAttrAt?_some_payloadFits
    {r : Region} {off : Nat} {attr : WireAttr} :
    regionWireAttrAt? r off = some attr →
      payloadFits r.totalLen off attr := by
  intro hAttr
  unfold regionWireAttrAt? at hAttr
  cases hChecked : regionCheckedAttrAt? r off with
  | none =>
      simp [hChecked] at hAttr
  | some checked =>
      simp [hChecked] at hAttr
      cases hAttr
      exact checked.property

theorem regionCheckedAttrAt?_some_header_fields
    {r : Region} {off : Nat}
    {checked : { attr : WireAttr // payloadFits r.totalLen off attr }} :
    regionCheckedAttrAt? r off = some checked →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        let header := r.header off hHeader
        checked.val.ty = (attrHeaderType header).toNat ∧
          checked.val.payloadLen = (attrHeaderLen header).toNat - headerLen ∧
          checked.val.nested = (attrHeaderIsNested header != 0) := by
  intro hAttr
  unfold regionCheckedAttrAt? at hAttr
  by_cases hHeader : off + headerLen ≤ r.totalLen
  · simp [hHeader] at hAttr
    let header := r.header off hHeader
    let len := (attrHeaderLen header).toNat
    by_cases hLen : len < headerLen
    · exfalso
      rcases hAttr with ⟨hLenGe, _⟩
      have hGe : headerLen ≤ len := by
        simpa [header, len] using hLenGe
      omega
    · by_cases hPayload : off + len ≤ r.totalLen
      · simp [header, len, hPayload] at hAttr
        rcases hAttr with ⟨_, hEq⟩
        have hVal :
            checked.val =
              { ty := (attrHeaderType header).toNat,
                payloadLen := len - headerLen,
                nested := attrHeaderIsNested header != 0 } :=
          congrArg Subtype.val hEq.symm
        exact ⟨hHeader, by simp [header, len, hVal]⟩
      · simp [header, len, hPayload] at hAttr
        rcases hAttr with ⟨_hLenGe, hPayloadProof, _⟩
        have hPayloadOk : off + len ≤ r.totalLen := by
          simp at hPayloadProof
        exact False.elim (hPayload hPayloadOk)
  · simp [hHeader] at hAttr

theorem regionWireAttrAt?_some_header_fields
    {r : Region} {off : Nat} {attr : WireAttr} :
    regionWireAttrAt? r off = some attr →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        let header := r.header off hHeader
        attr.ty = (attrHeaderType header).toNat ∧
          attr.payloadLen = (attrHeaderLen header).toNat - headerLen ∧
          attr.nested = (attrHeaderIsNested header != 0) := by
  intro hAttr
  unfold regionWireAttrAt? at hAttr
  cases hChecked : regionCheckedAttrAt? r off with
  | none =>
      simp [hChecked] at hAttr
  | some checked =>
      simp [hChecked] at hAttr
      cases hAttr
      exact regionCheckedAttrAt?_some_header_fields hChecked

theorem regionCheckedAttrAt?_some_header_len_ge
    {r : Region} {off : Nat}
    {checked : { attr : WireAttr // payloadFits r.totalLen off attr }} :
    regionCheckedAttrAt? r off = some checked →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        headerLen ≤ (attrHeaderLen (r.header off hHeader)).toNat := by
  intro hAttr
  unfold regionCheckedAttrAt? at hAttr
  by_cases hHeader : off + headerLen ≤ r.totalLen
  · simp [hHeader] at hAttr
    let header := r.header off hHeader
    let len := (attrHeaderLen header).toNat
    by_cases hLen : len < headerLen
    · exfalso
      rcases hAttr with ⟨hLenGe, _⟩
      have hGe : headerLen ≤ len := by
        simpa [header, len] using hLenGe
      omega
    · exact ⟨hHeader, by
        have hGe : headerLen ≤ len := Nat.le_of_not_gt hLen
        simpa [header, len] using hGe⟩
  · simp [hHeader] at hAttr

theorem regionWireAttrAt?_some_header_len_ge
    {r : Region} {off : Nat} {attr : WireAttr} :
    regionWireAttrAt? r off = some attr →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        headerLen ≤ (attrHeaderLen (r.header off hHeader)).toNat := by
  intro hAttr
  unfold regionWireAttrAt? at hAttr
  cases hChecked : regionCheckedAttrAt? r off with
  | none =>
      simp [hChecked] at hAttr
  | some checked =>
      simp [hChecked] at hAttr
      exact regionCheckedAttrAt?_some_header_len_ge hChecked

theorem regionCheckedAttrAt?_some_declared_end_le
    {r : Region} {off : Nat}
    {checked : { attr : WireAttr // payloadFits r.totalLen off attr }} :
    regionCheckedAttrAt? r off = some checked →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        off + (attrHeaderLen (r.header off hHeader)).toNat ≤ r.totalLen := by
  intro hAttr
  unfold regionCheckedAttrAt? at hAttr
  by_cases hHeader : off + headerLen ≤ r.totalLen
  · simp [hHeader] at hAttr
    let header := r.header off hHeader
    let len := (attrHeaderLen header).toNat
    by_cases hLen : len < headerLen
    · exfalso
      rcases hAttr with ⟨hLenGe, _⟩
      have hGe : headerLen ≤ len := by
        simpa [header, len] using hLenGe
      omega
    · by_cases hPayload : off + len ≤ r.totalLen
      · exact ⟨hHeader, by simpa [header, len] using hPayload⟩
      · simp [header, len, hPayload] at hAttr
        rcases hAttr with ⟨_hLenGe, hPayloadProof, _⟩
        have hPayloadOk : off + len ≤ r.totalLen := by
          simp at hPayloadProof
        exact False.elim (hPayload hPayloadOk)
  · simp [hHeader] at hAttr

theorem regionWireAttrAt?_some_declared_end_le
    {r : Region} {off : Nat} {attr : WireAttr} :
    regionWireAttrAt? r off = some attr →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        off + (attrHeaderLen (r.header off hHeader)).toNat ≤ r.totalLen := by
  intro hAttr
  unfold regionWireAttrAt? at hAttr
  cases hChecked : regionCheckedAttrAt? r off with
  | none =>
      simp [hChecked] at hAttr
  | some checked =>
      simp [hChecked] at hAttr
      exact regionCheckedAttrAt?_some_declared_end_le hChecked

theorem regionParseAttrsLoop_entries_payloadFits
    (r : Region) :
    ∀ (fuel off : Nat) (attrs : List WireAttr),
      regionParseAttrsLoop r fuel off = some attrs →
        ∀ (entry : Nat × WireAttr),
          entry ∈ entries off attrs →
            payloadFits r.totalLen entry.1 entry.2 := by
  intro fuel
  induction fuel with
  | zero =>
      intro off attrs hParse entry hEntry
      simp [regionParseAttrsLoop] at hParse
  | succ fuel' ih =>
      intro off attrs hParse entry hEntry
      unfold regionParseAttrsLoop at hParse
      by_cases hDone : off == r.totalLen
      · simp [hDone] at hParse
        cases hParse
        simp [entries] at hEntry
      · simp [hDone] at hParse
        cases hWire : regionCheckedAttrAt? r off with
        | none =>
            simp [hWire] at hParse
        | some checked =>
            simp [hWire] at hParse
            let head := checked.val
            let next := off + wireTotalSize head
            have hHeadFit :
                payloadFits r.totalLen off head :=
              checked.property
            change
              (if next > r.totalLen then
                some [head]
              else
                match regionParseAttrsLoop r fuel' next with
                | some rest => some (head :: rest)
                | none => none) = some attrs at hParse
            by_cases hPast : next > r.totalLen
            · simp [next, hPast] at hParse
              cases hParse
              simp [entries] at hEntry
              rcases hEntry with ⟨rfl, rfl⟩
              exact hHeadFit
            · simp [next, hPast] at hParse
              cases hRest : regionParseAttrsLoop r fuel' next with
              | none =>
                  rw [hRest] at hParse
                  simp at hParse
              | some rest =>
                  rw [hRest] at hParse
                  simp at hParse
                  cases hParse
                  simp [entries] at hEntry
                  cases hEntry with
                  | inl hHere =>
                      rcases hHere with ⟨rfl, rfl⟩
                      exact hHeadFit
                  | inr hTail =>
                      exact ih next rest hRest entry hTail

theorem regionParseAttrs?_entries_payloadFits
    (r : Region) (attrs : List WireAttr) :
    regionParseAttrs? r = some attrs →
      ∀ (entry : Nat × WireAttr),
        entry ∈ entries 0 attrs →
          payloadFits r.totalLen entry.1 entry.2 := by
  intro hParse
  exact regionParseAttrsLoop_entries_payloadFits r (r.totalLen + 1) 0 attrs
    hParse

theorem regionParseAttrsLoop_entries_wireAttrAt?
    (r : Region) :
    ∀ (fuel off : Nat) (attrs : List WireAttr),
      regionParseAttrsLoop r fuel off = some attrs →
        ∀ (entry : Nat × WireAttr),
          entry ∈ entries off attrs →
            regionWireAttrAt? r entry.1 = some entry.2 := by
  intro fuel
  induction fuel with
  | zero =>
      intro off attrs hParse entry hEntry
      simp [regionParseAttrsLoop] at hParse
  | succ fuel' ih =>
      intro off attrs hParse entry hEntry
      unfold regionParseAttrsLoop at hParse
      by_cases hDone : off == r.totalLen
      · simp [hDone] at hParse
        cases hParse
        simp [entries] at hEntry
      · simp [hDone] at hParse
        cases hWire : regionCheckedAttrAt? r off with
        | none =>
            simp [hWire] at hParse
        | some checked =>
            simp [hWire] at hParse
            let head := checked.val
            let next := off + wireTotalSize head
            have hAtHead : regionWireAttrAt? r off = some head := by
              unfold regionWireAttrAt?
              simp [hWire, head]
            change
              (if next > r.totalLen then
                some [head]
              else
                match regionParseAttrsLoop r fuel' next with
                | some rest => some (head :: rest)
                | none => none) = some attrs at hParse
            by_cases hPast : next > r.totalLen
            · simp [next, hPast] at hParse
              cases hParse
              simp [entries] at hEntry
              rcases hEntry with ⟨rfl, rfl⟩
              exact hAtHead
            · simp [next, hPast] at hParse
              cases hRest : regionParseAttrsLoop r fuel' next with
              | none =>
                  rw [hRest] at hParse
                  simp at hParse
              | some rest =>
                  rw [hRest] at hParse
                  simp at hParse
                  cases hParse
                  simp [entries] at hEntry
                  cases hEntry with
                  | inl hHere =>
                      rcases hHere with ⟨rfl, rfl⟩
                      exact hAtHead
                  | inr hTail =>
                      exact ih next rest hRest entry hTail

theorem regionParseAttrs?_entries_wireAttrAt?
    (r : Region) (attrs : List WireAttr) :
    regionParseAttrs? r = some attrs →
      ∀ (entry : Nat × WireAttr),
        entry ∈ entries 0 attrs →
          regionWireAttrAt? r entry.1 = some entry.2 := by
  intro hParse
  exact regionParseAttrsLoop_entries_wireAttrAt? r (r.totalLen + 1) 0 attrs
    hParse

theorem regionParseAttrsLoop_cons_head_wireAttrAt?
    (r : Region) (fuel off : Nat) (attr : WireAttr)
    (rest : List WireAttr) :
    regionParseAttrsLoop r fuel off = some (attr :: rest) →
      regionWireAttrAt? r off = some attr := by
  intro hParse
  have hEntry : (off, attr) ∈ entries off (attr :: rest) := by
    simp [entries]
  exact regionParseAttrsLoop_entries_wireAttrAt? r fuel off (attr :: rest)
    hParse (off, attr) hEntry

theorem regionParseAttrsLoop_cons_head_declared_end_le
    (r : Region) (fuel off : Nat) (attr : WireAttr)
    (rest : List WireAttr) :
    regionParseAttrsLoop r fuel off = some (attr :: rest) →
      ∃ hHeader : off + headerLen ≤ r.totalLen,
        off + (attrHeaderLen (r.header off hHeader)).toNat ≤ r.totalLen := by
  intro hParse
  exact regionWireAttrAt?_some_declared_end_le
    (regionParseAttrsLoop_cons_head_wireAttrAt? r fuel off attr rest hParse)

theorem regionParseAttrsLoop_cons_tail_of_next_le
    (r : Region) :
    ∀ (fuel off : Nat) (attr : WireAttr) (rest : List WireAttr),
      regionParseAttrsLoop r fuel off = some (attr :: rest) →
        off + wireTotalSize attr ≤ r.totalLen →
          ∃ fuel',
            fuel = fuel' + 1 ∧
              regionParseAttrsLoop r fuel' (off + wireTotalSize attr) =
                some rest := by
  intro fuel
  induction fuel with
  | zero =>
      intro off attr rest hParse _hNext
      simp [regionParseAttrsLoop] at hParse
  | succ fuel' _ih =>
      intro off attr rest hParse hNextLe
      unfold regionParseAttrsLoop at hParse
      by_cases hDone : off == r.totalLen
      · simp [hDone] at hParse
      · simp [hDone] at hParse
        cases hWire : regionCheckedAttrAt? r off with
        | none =>
            simp [hWire] at hParse
        | some checked =>
            simp [hWire] at hParse
            let head := checked.val
            let next := off + wireTotalSize head
            change
              (if next > r.totalLen then
                some [head]
              else
                match regionParseAttrsLoop r fuel' next with
                | some parsedRest => some (head :: parsedRest)
                | none => none) = some (attr :: rest) at hParse
            by_cases hPast : next > r.totalLen
            · simp [next, hPast] at hParse
              rcases hParse with ⟨hHeadEq, hRestEq⟩
              subst attr
              subst rest
              omega
            · simp [next, hPast] at hParse
              cases hRest : regionParseAttrsLoop r fuel' next with
              | none =>
                  rw [hRest] at hParse
                  simp at hParse
              | some parsedRest =>
                  rw [hRest] at hParse
                  simp at hParse
                  rcases hParse with ⟨hHeadEq, hRestEq⟩
                  subst attr
                  subst rest
                  exact ⟨fuel', rfl, by simpa [next] using hRest⟩

theorem regionParseAttrsLoop_cons_next_le_of_rest_ne_nil
    (r : Region) :
    ∀ (fuel off : Nat) (attr : WireAttr) (rest : List WireAttr),
      regionParseAttrsLoop r fuel off = some (attr :: rest) →
        rest ≠ [] →
          off + wireTotalSize attr ≤ r.totalLen := by
  intro fuel
  induction fuel with
  | zero =>
      intro off attr rest hParse _hRest
      simp [regionParseAttrsLoop] at hParse
  | succ fuel' _ih =>
      intro off attr rest hParse hRestNe
      unfold regionParseAttrsLoop at hParse
      by_cases hDone : off == r.totalLen
      · simp [hDone] at hParse
      · simp [hDone] at hParse
        cases hWire : regionCheckedAttrAt? r off with
        | none =>
            simp [hWire] at hParse
        | some checked =>
            simp [hWire] at hParse
            let head := checked.val
            let next := off + wireTotalSize head
            change
              (if next > r.totalLen then
                some [head]
              else
                match regionParseAttrsLoop r fuel' next with
                | some parsedRest => some (head :: parsedRest)
                | none => none) = some (attr :: rest) at hParse
            by_cases hPast : next > r.totalLen
            · simp [next, hPast] at hParse
              rcases hParse with ⟨_hHeadEq, hRestEq⟩
              subst rest
              exact False.elim (hRestNe rfl)
            · simp [next, hPast] at hParse
              cases hRest : regionParseAttrsLoop r fuel' next with
              | none =>
                  rw [hRest] at hParse
                  simp at hParse
              | some parsedRest =>
                  rw [hRest] at hParse
                  simp at hParse
                  rcases hParse with ⟨hHeadEq, _hRestEq⟩
                  subst attr
                  exact Nat.le_of_not_gt hPast

structure WireEntryMatchesRegion
    (r : Region) (off : Nat) (attr : WireAttr) : Prop where
  payload : payloadFits r.totalLen off attr
  header :
    ∃ hHeader : off + headerLen ≤ r.totalLen,
      let header := r.header off hHeader
      attr.ty = (attrHeaderType header).toNat ∧
        attr.payloadLen = (attrHeaderLen header).toNat - headerLen ∧
        attr.nested = (attrHeaderIsNested header != 0)

def WireStreamMatchesRegion (r : Region) (attrs : List WireAttr) : Prop :=
  ∀ entry : Nat × WireAttr,
    entry ∈ entries 0 attrs →
      WireEntryMatchesRegion r entry.1 entry.2

theorem regionWireAttrAt?_some_matchesRegion
    {r : Region} {off : Nat} {attr : WireAttr} :
    regionWireAttrAt? r off = some attr →
      WireEntryMatchesRegion r off attr := by
  intro hAttr
  exact
    { payload := regionWireAttrAt?_some_payloadFits hAttr,
      header := regionWireAttrAt?_some_header_fields hAttr }

theorem regionParseAttrs?_matchesRegion
    (r : Region) (attrs : List WireAttr) :
    regionParseAttrs? r = some attrs →
      WireStreamMatchesRegion r attrs := by
  intro hParse entry hEntry
  exact regionWireAttrAt?_some_matchesRegion
    (regionParseAttrs?_entries_wireAttrAt? r attrs hParse entry hEntry)

theorem align4_ge (n : Nat) : n ≤ align4 n := by
  unfold align4 align4Nat
  omega

theorem attrSize_ge_header (payloadLen : Nat) :
    headerLen ≤ attrSize payloadLen := by
  unfold attrSize headerLen nlaHeaderBytes
  omega

theorem attrSize_le_totalSize (payloadLen : Nat) :
    attrSize payloadLen ≤ totalSize payloadLen := by
  unfold totalSize align4
  exact align4_ge (attrSize payloadLen)

theorem payloadFits_implies_headerFits {total off : Nat} {attr : WireAttr} :
    payloadFits total off attr → headerFits total off := by
  intro h
  unfold payloadFits headerFits wireAttrSize attrSize headerLen nlaHeaderBytes at *
  omega

theorem payloadFits_header_index_lt
    {total off : Nat} {attr : WireAttr} {ix : Nat} :
    payloadFits total off attr →
      ix < headerLen →
        off + ix < total := by
  intro hFits hIx
  unfold payloadFits wireAttrSize attrSize headerLen nlaHeaderBytes at *
  omega

theorem payloadFits_payload_index_lt
    {total off : Nat} {attr : WireAttr} {ix : Nat} :
    payloadFits total off attr →
      ix < attr.payloadLen →
        off + headerLen + ix < total := by
  intro hFits hIx
  unfold payloadFits wireAttrSize attrSize headerLen nlaHeaderBytes at *
  omega

theorem payloadFits_implies_off_le_total {total off : Nat} {attr : WireAttr} :
    payloadFits total off attr → off ≤ total := by
  intro h
  unfold payloadFits wireAttrSize attrSize headerLen nlaHeaderBytes at *
  omega

theorem nextOff_ge (off : Nat) (attr : WireAttr) :
    off ≤ nextOff off attr := by
  unfold nextOff
  omega

theorem nextOff_gt (off : Nat) (attr : WireAttr) :
    off < nextOff off attr := by
  have hSize := attrSize_le_totalSize attr.payloadLen
  unfold nextOff wireTotalSize totalSize attrSize headerLen nlaHeaderBytes at *
  omega

theorem entries_payloadFits_streamSize :
    ∀ (attrs : List WireAttr) (base off : Nat) (attr : WireAttr),
      (off, attr) ∈ entries base attrs →
        payloadFits (base + streamSize attrs) off attr := by
  intro attrs
  induction attrs with
  | nil =>
      intro base off attr hMem
      simp [entries] at hMem
  | cons head rest ih =>
      intro base off attr hMem
      simp [entries] at hMem
      cases hMem with
      | inl hHere =>
          rcases hHere with ⟨rfl, rfl⟩
          have hSize := attrSize_le_totalSize attr.payloadLen
          simp [payloadFits, wireAttrSize, streamSize, wireTotalSize]
          omega
      | inr hRest =>
          have hFit := ih (nextOff base head) off attr hRest
          simpa [payloadFits, nextOff, streamSize, Nat.add_assoc, Nat.add_left_comm,
            Nat.add_comm] using hFit

theorem entries_headerFits_streamSize :
    ∀ (attrs : List WireAttr) (base off : Nat) (attr : WireAttr),
      (off, attr) ∈ entries base attrs →
        headerFits (base + streamSize attrs) off := by
  intro attrs base off attr hMem
  exact payloadFits_implies_headerFits
    (entries_payloadFits_streamSize attrs base off attr hMem)

theorem findOffsetSomeEntry :
    ∀ (attrs : List WireAttr) (target base found : Nat),
      findOffset target base attrs = some found →
        ∃ attr, (found, attr) ∈ entries base attrs ∧ attr.ty = target := by
  intro attrs
  induction attrs with
  | nil =>
      intro target base found hFind
      simp [findOffset] at hFind
  | cons head rest ih =>
      intro target base found hFind
      by_cases hTy : head.ty = target
      · simp [findOffset, hTy] at hFind
        cases hFind
        exact ⟨head, by simp [entries], hTy⟩
      · simp [findOffset, hTy] at hFind
        rcases ih target (nextOff base head) found hFind with ⟨attr, hMem, hAttrTy⟩
        exact ⟨attr, by simp [entries, hMem], hAttrTy⟩

theorem findOffsetSomeFits :
    ∀ (attrs : List WireAttr) (target base found : Nat),
      findOffset target base attrs = some found →
        ∃ attr,
          (found, attr) ∈ entries base attrs ∧
          attr.ty = target ∧
          headerFits (base + streamSize attrs) found ∧
          payloadFits (base + streamSize attrs) found attr := by
  intro attrs target base found hFind
  rcases findOffsetSomeEntry attrs target base found hFind with ⟨attr, hMem, hTy⟩
  exact ⟨attr, hMem, hTy,
    entries_headerFits_streamSize attrs base found attr hMem,
    entries_payloadFits_streamSize attrs base found attr hMem⟩

theorem findLoop_eq_findOffset (target off : Nat) :
    ∀ (attrs : List WireAttr) (fuel : Nat),
      attrs.length ≤ fuel →
        findLoop target fuel off attrs = findOffset target off attrs := by
  intro attrs
  induction attrs generalizing off with
  | nil =>
      intro fuel hFuel
      cases fuel <;> simp [findLoop, findOffset]
  | cons head rest ih =>
      intro fuel hFuel
      cases fuel with
      | zero =>
          simp at hFuel
      | succ fuel' =>
          by_cases hTy : head.ty = target
          · simp [findLoop, findOffset, hTy]
          · have hRest : rest.length ≤ fuel' := by
              simp at hFuel
              omega
            simp [findLoop, findOffset, hTy, ih (nextOff off head) fuel' hRest]

theorem find?_eq_findOffset (attrs : List WireAttr) (target : Nat) :
    find? attrs target = findOffset target 0 attrs := by
  unfold find?
  exact findLoop_eq_findOffset target 0 attrs (attrs.length + 1) (by omega)

theorem find?_some_fits (attrs : List WireAttr) (target found : Nat) :
    find? attrs target = some found →
      ∃ attr,
        (found, attr) ∈ entries 0 attrs ∧
        attr.ty = target ∧
        headerFits (streamSize attrs) found ∧
        payloadFits (streamSize attrs) found attr := by
  intro hFind
  rw [find?_eq_findOffset] at hFind
  rcases findOffsetSomeFits attrs target 0 found hFind with
    ⟨attr, hMem, hTy, hHeader, hPayload⟩
  exact ⟨attr, hMem, hTy, by simpa using hHeader, by simpa using hPayload⟩

end Layout

end Memory
end LeanNlAttr
