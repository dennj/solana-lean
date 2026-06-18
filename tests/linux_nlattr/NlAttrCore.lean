import NlAttrMemory

namespace LeanNlAttr

def ok : UInt64 := 0
def unsupported : UInt64 := 1
def einval : UInt64 := 22
def erange : UInt64 := 34
def emsgsize : UInt64 := 90
def e2big : UInt64 := 7
def eopnotsupp : UInt64 := 95
def intMax : UInt64 := 2147483647
def intMinReturn : UInt64 := 0xffffffff80000000
def errnoFlag : UInt64 := 0x0000000100000000
def cmpUnsupported : UInt64 := 0x8000000000000000
def cmpNegative : UInt64 := 0x0000000100000000
def u16Max : UInt64 := 65535
def u32Max : UInt64 := 0xffffffff
def u64Max : UInt64 := 0xffffffffffffffff
def s8Min : UInt64 := 0xffffffffffffff80
def s8Max : UInt64 := 0x7f
def s16Min : UInt64 := 0xffffffffffff8000
def s16Max : UInt64 := 0x7fff
def s32Min : UInt64 := 0xffffffff80000000
def s32Max : UInt64 := 0x7fffffff
def s64Min : UInt64 := 0x8000000000000000
def s64Max : UInt64 := 0x7fffffffffffffff

def kindUnsupported : UInt64 := 0
def kindAccept : UInt64 := 1
def kindFlag : UInt64 := 2
def kindExact : UInt64 := 3
def kindMin : UInt64 := 4
def kindRange : UInt64 := 5
def kindReject : UInt64 := 6
def kindString : UInt64 := 7
def kindNulString : UInt64 := 8
def kindBitfield32 : UInt64 := 9
def kindInt32Or64 : UInt64 := 10
def kindNested : UInt64 := 11
def kindNestedPolicy : UInt64 := 12
def kindNestedArrayPolicy : UInt64 := 13

def policyValidateNone : UInt64 := 0
def policyValidateRange : UInt64 := 1
def policyValidateRangeWarnTooLong : UInt64 := 2
def policyValidateMin : UInt64 := 3
def policyValidateMax : UInt64 := 4
def policyValidateMask : UInt64 := 5
def policyValidateRangePtr : UInt64 := 6
def policyValidateFunction : UInt64 := 7

def valueNone : UInt64 := 0
def valueUnsigned8 : UInt64 := 1
def valueUnsigned16 : UInt64 := 2
def valueUnsigned32 : UInt64 := 3
def valueUnsigned64 : UInt64 := 4
def valueUnsigned32Or64 : UInt64 := 5
def valueMsecs : UInt64 := 6
def valueBigUnsigned16 : UInt64 := 7
def valueBigUnsigned32 : UInt64 := 8
def valueSigned8 : UInt64 := 9
def valueSigned16 : UInt64 := 10
def valueSigned32 : UInt64 := 11
def valueSigned64 : UInt64 := 12
def valueSigned32Or64 : UInt64 := 13
def valueBinaryLen : UInt64 := 14

def nlaUnspec : UInt64 := 0
def nlaU8 : UInt64 := 1
def nlaU16 : UInt64 := 2
def nlaU32 : UInt64 := 3
def nlaU64 : UInt64 := 4
def nlaString : UInt64 := 5
def nlaFlag : UInt64 := 6
def nlaMsecs : UInt64 := 7
def nlaNested : UInt64 := 8
def nlaNestedArray : UInt64 := 9
def nlaNulString : UInt64 := 10
def nlaBinary : UInt64 := 11
def nlaS8 : UInt64 := 12
def nlaS16 : UInt64 := 13
def nlaS32 : UInt64 := 14
def nlaS64 : UInt64 := 15
def nlaBitfield32 : UInt64 := 16
def nlaReject : UInt64 := 17
def nlaBE16 : UInt64 := 18
def nlaBE32 : UInt64 := 19
def nlaSInt : UInt64 := 20
def nlaUInt : UInt64 := 21

def validateTrailing : UInt64 := 1
def validateMaxType : UInt64 := 2
def validateUnspec : UInt64 := 4
def validateStrictAttrs : UInt64 := 8
def validateNested : UInt64 := 16
def validateStrict : UInt64 := 31

def diagRecursionDepth : UInt64 := 1
def diagUnknownAttr : UInt64 := 2
def diagTrailingBytes : UInt64 := 3
def diagInvalidAttrLen : UInt64 := 4
def diagNestedMissing : UInt64 := 5
def diagNestedUnexpected : UInt64 := 6
def diagReject : UInt64 := 7
def diagUnsupportedAttr : UInt64 := 8
def diagFailedPolicy : UInt64 := 9
def diagReservedBit : UInt64 := 10
def diagBinaryRange : UInt64 := 11
def diagIntegerRange : UInt64 := 12
def diagBinaryWarnTooLong : UInt64 := 13
def diagBinaryWarnTooLongAccepted : UInt64 := 14

def nlaHeaderLen : UInt64 := 4
def nlaFlagNested : UInt64 := 0x8000
def nlaTypeMask : UInt64 := 0x3fff
def maxPolicyRecursionDepth : UInt64 := 10

@[always_inline]
def attrHeaderLen (header : UInt64) : UInt64 :=
  header &&& 0xffffffff

@[always_inline]
def attrHeaderType (header : UInt64) : UInt64 :=
  ((header >>> 32) &&& 0xffff) &&& nlaTypeMask

@[always_inline]
def attrHeaderIsNested (header : UInt64) : UInt64 :=
  if (((header >>> 32) &&& 0xffff) &&& nlaFlagNested) != 0 then 1 else 0

def policyMetaAccept : UInt64 := kindAccept

@[always_inline]
def policyMetaKind (row : UInt64) : UInt64 :=
  row &&& 0xff

@[always_inline]
def policyMetaValidation (row : UInt64) : UInt64 :=
  (row >>> 8) &&& 0xff

@[always_inline]
def policyMetaValueKind (row : UInt64) : UInt64 :=
  (row >>> 16) &&& 0xff

@[always_inline]
def policyMetaIsUnspec (row : UInt64) : UInt64 :=
  (row >>> 24) &&& 1

@[always_inline]
def policyMetaStrictLen (row : UInt64) : UInt64 :=
  (row >>> 25) &&& 0xf

@[always_inline]
def policyMetaMinLen (row : UInt64) : UInt64 :=
  (row >>> 32) &&& 0xffff

@[always_inline]
def policyMetaMaxLen (row : UInt64) : UInt64 :=
  (row >>> 48) &&& 0xffff

@[extern "lean_nlattr_raw_ptr_byte", never_extract]
opaque ptrByte (ptr ix : UInt64) : UInt64

@[extern "lean_nlattr_raw_ptr_set_byte", never_extract]
opaque ptrSetByte (ptr ix value : UInt64) : UInt64

@[extern "lean_nlattr_raw_byte_array", never_extract]
opaque rawByteArray (ptr len : UInt64) : ByteArray

def rawRegion (ptr len : UInt64) : Memory.Region :=
  Memory.Region.ofBytes (rawByteArray ptr len)

@[always_inline]
def regionByte (region : Memory.Region) (ix : UInt64) : UInt64 :=
  let ixNat := ix.toNat
  if h : ixNat < region.totalLen then
    region.byteAt ixNat (by
      have hs := region.totalLen_le_size
      omega)
  else
    0

@[always_inline]
def regionLE16 (region : Memory.Region) (off : UInt64) : UInt64 :=
  regionByte region off ||| (regionByte region (off + 1) <<< 8)

@[always_inline]
def regionLE32 (region : Memory.Region) (off : UInt64) : UInt64 :=
  regionLE16 region off ||| (regionLE16 region (off + 2) <<< 16)

@[always_inline]
def regionLE64 (region : Memory.Region) (off : UInt64) : UInt64 :=
  regionLE32 region off ||| (regionLE32 region (off + 4) <<< 32)

structure AttrView where
  base : UInt64
  region : Memory.Region
  start : Nat
  totalLen : Nat
  fits : start + totalLen ≤ region.totalLen

def AttrView.ofRegion (base : UInt64) (region : Memory.Region) : AttrView :=
  { base := base, region := region, start := 0, totalLen := region.totalLen,
    fits := by omega }

def AttrView.ofRaw (base len : UInt64) : AttrView :=
  AttrView.ofRegion base (rawRegion base len)

@[always_inline]
def AttrView.ptr (view : AttrView) (off : UInt64) : UInt64 :=
  view.base + off

@[always_inline]
def AttrView.header (view : AttrView) (off : UInt64) : UInt64 :=
  let offNat := off.toNat
  if h : offNat + Memory.nlaHeaderBytes ≤ view.totalLen then
    view.region.header (view.start + offNat) (by
      have hf := view.fits
      omega)
  else
    0

@[always_inline]
def AttrView.byte (view : AttrView) (off ix : UInt64) : UInt64 :=
  let offNat := off.toNat
  let ixNat := ix.toNat
  if h : offNat + Memory.nlaHeaderBytes + ixNat < view.totalLen then
    view.region.payloadByte (view.start + offNat) ixNat (by
      have hf := view.fits
      omega)
  else
    0

theorem AttrView.header_eq_region_header
    (view : AttrView) (off : UInt64)
    (hHeader : off.toNat + Memory.nlaHeaderBytes ≤ view.totalLen)
    (hRegion :
      view.start + off.toNat + Memory.nlaHeaderBytes ≤ view.region.totalLen) :
    view.header off =
      view.region.header (view.start + off.toNat) hRegion := by
  unfold AttrView.header
  simp [hHeader]

def AttrView.payloadView (view : AttrView) (off payloadLen : UInt64) : AttrView :=
  let offNat := off.toNat
  let payloadNat := payloadLen.toNat
  if h : offNat + Memory.nlaHeaderBytes + payloadNat ≤ view.totalLen then
    { base := view.base + off + nlaHeaderLen,
      region := view.region,
      start := view.start + offNat + Memory.nlaHeaderBytes,
      totalLen := payloadNat,
      fits := by
        have hf := view.fits
        omega }
  else
    { base := view.base + off + nlaHeaderLen,
      region := view.region,
      start := view.start,
      totalLen := 0,
      fits := by
        have hf := view.fits
        omega }

def nlaPolicyStride : UInt64 := 16
def nlaPolicyTypeOff : UInt64 := 0
def nlaPolicyValidationOff : UInt64 := 1
def nlaPolicyLenOff : UInt64 := 2
def nlaPolicyUnionOff : UInt64 := 8

@[always_inline]
def rawPolicyFieldOff (ty fieldOff : UInt64) : UInt64 :=
  ty * nlaPolicyStride + fieldOff

@[always_inline]
def rawPolicyRowRegion (policy ty : UInt64) : Memory.Region :=
  rawRegion (policy + rawPolicyFieldOff ty 0) nlaPolicyStride

def nlaPolicyStrideNat : Nat := 16

structure PolicyRowView where
  region : Memory.Region
  start : Nat
  totalLen : Nat
  fits : start + totalLen ≤ region.totalLen

def PolicyRowView.ofRaw (policy ty : UInt64) : PolicyRowView :=
  let region := rawPolicyRowRegion policy ty
  { region := region, start := 0, totalLen := region.totalLen, fits := by omega }

@[always_inline]
def PolicyRowView.byte (row : PolicyRowView) (off : UInt64) : UInt64 :=
  let offNat := off.toNat
  if h : offNat < row.totalLen then
    row.region.byteAt (row.start + offNat) (by
      have hf := row.fits
      have hs := row.region.totalLen_le_size
      omega)
  else
    0

@[always_inline]
def PolicyRowView.le16 (row : PolicyRowView) (off : UInt64) : UInt64 :=
  row.byte off ||| (row.byte (off + 1) <<< 8)

@[always_inline]
def PolicyRowView.le32 (row : PolicyRowView) (off : UInt64) : UInt64 :=
  row.le16 off ||| (row.le16 (off + 2) <<< 16)

@[always_inline]
def PolicyRowView.le64 (row : PolicyRowView) (off : UInt64) : UInt64 :=
  row.le32 off ||| (row.le32 (off + 4) <<< 32)

@[always_inline]
def PolicyRowView.policyType (row : PolicyRowView) : UInt64 :=
  row.byte nlaPolicyTypeOff

@[always_inline]
def PolicyRowView.validation (row : PolicyRowView) : UInt64 :=
  row.byte nlaPolicyValidationOff

@[always_inline]
def PolicyRowView.len (row : PolicyRowView) : UInt64 :=
  row.le16 nlaPolicyLenOff

@[always_inline]
def PolicyRowView.unionPtr (row : PolicyRowView) : UInt64 :=
  row.le64 nlaPolicyUnionOff

@[always_inline]
def PolicyRowView.unionLo16 (row : PolicyRowView) : UInt64 :=
  row.le16 nlaPolicyUnionOff

@[always_inline]
def PolicyRowView.unionHi16 (row : PolicyRowView) : UInt64 :=
  row.le16 (nlaPolicyUnionOff + 2)

@[always_inline]
def PolicyRowView.mask (row : PolicyRowView) : UInt64 :=
  row.le32 nlaPolicyUnionOff

def policyTableLen (maxtype : UInt64) : UInt64 :=
  (maxtype + 1) * nlaPolicyStride

structure PolicyTableView where
  base : UInt64
  region : Memory.Region

def PolicyTableView.empty : PolicyTableView :=
  { base := 0, region := Memory.Region.ofBytes ByteArray.empty }

def PolicyTableView.ofRaw (policy maxtype : UInt64) : PolicyTableView :=
  if policy == 0 then
    PolicyTableView.empty
  else
    { base := policy, region := rawRegion policy (policyTableLen maxtype) }

def PolicyTableView.row (table : PolicyTableView) (ty : UInt64) : PolicyRowView :=
  let start := ty.toNat * nlaPolicyStrideNat
  if h : start + nlaPolicyStrideNat ≤ table.region.totalLen then
    { region := table.region, start := start, totalLen := nlaPolicyStrideNat,
      fits := h }
  else
    { region := table.region, start := 0, totalLen := 0, fits := by omega }

@[always_inline]
def rawPolicyFieldByte (policy ty fieldOff : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).byte fieldOff

@[always_inline]
def rawPolicyFieldLE16 (policy ty fieldOff : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).le16 fieldOff

@[always_inline]
def rawPolicyFieldLE32 (policy ty fieldOff : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).le32 fieldOff

@[always_inline]
def rawPolicyFieldLE64 (policy ty fieldOff : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).le64 fieldOff

@[always_inline]
def rawPolicyType (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).policyType

@[always_inline]
def rawPolicyValidation (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).validation

@[always_inline]
def rawPolicyLen (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).len

@[always_inline]
def rawPolicyUnionPtr (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).unionPtr

@[always_inline]
def rawPolicyValidatePtr (policy ty : UInt64) : UInt64 :=
  rawPolicyUnionPtr policy ty

@[always_inline]
def rawPolicyUnionLo16 (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).unionLo16

@[always_inline]
def rawPolicyUnionHi16 (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).unionHi16

@[always_inline]
def rawPolicyMask (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).mask

@[always_inline]
def policyRangeValue (policy ty ix : UInt64) : UInt64 :=
  regionLE64 (rawRegion (rawPolicyUnionPtr policy ty) 16) (ix * 8)

@[always_inline]
def policyValueMin (policy ty : UInt64) : UInt64 :=
  let rangePtr := (PolicyRowView.ofRaw policy ty).unionPtr
  if rangePtr == 0 then 0 else regionLE64 (rawRegion rangePtr 16) 0

@[always_inline]
def policyValueMax (policy ty : UInt64) : UInt64 :=
  let rangePtr := (PolicyRowView.ofRaw policy ty).unionPtr
  if rangePtr == 0 then 0 else regionLE64 (rawRegion rangePtr 16) 8

@[extern "lean_nlattr_policy_validate_fn_raw", never_extract]
opaque policyValidateFnRaw (policy ty attr extack : UInt64) : UInt64

@[extern "lean_nlattr_raw_set_tb", never_extract]
opaque setTb (tb ty attr : UInt64) : UInt64

@[extern "lean_nlattr_array_index_nospec", never_extract]
opaque arrayIndexNospecRaw (index size : UInt64) : UInt64

@[always_inline]
def arrayIndexNospec (index size : UInt64) : UInt64 :=
  let raw := arrayIndexNospecRaw index size
  if index < size then
    if raw == index then raw else index
  else if raw == 0 then
    raw
  else
    0

@[extern "lean_nlattr_report_recursion_depth", never_extract]
opaque reportRecursionDepth (extack : UInt64) : UInt64

@[extern "lean_nlattr_report_unknown_attr", never_extract]
opaque reportUnknownAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_warn_trailing_bytes", never_extract]
opaque warnTrailingBytes (unit : UInt64) : UInt64

@[extern "lean_nlattr_report_trailing_bytes", never_extract]
opaque reportTrailingBytes (extack : UInt64) : UInt64

@[extern "lean_nlattr_warn_invalid_attr_len", never_extract]
opaque warnInvalidAttrLen (ty : UInt64) : UInt64

@[extern "lean_nlattr_report_invalid_attr_len_attr", never_extract]
opaque reportInvalidAttrLenAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_invalid_attr_len_policy", never_extract]
opaque reportInvalidAttrLenPolicy
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_nested_missing_attr", never_extract]
opaque reportNestedMissingAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_nested_missing_policy", never_extract]
opaque reportNestedMissingPolicy
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_nested_unexpected_attr", never_extract]
opaque reportNestedUnexpectedAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_nested_unexpected_policy", never_extract]
opaque reportNestedUnexpectedPolicy
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_reject_message", never_extract]
opaque reportRejectMessage
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_failed_policy_attr", never_extract]
opaque reportFailedPolicyAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_failed_policy_policy", never_extract]
opaque reportFailedPolicyPolicy
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_unsupported_attr", never_extract]
opaque reportUnsupportedAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_reserved_bit", never_extract]
opaque reportReservedBit (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_binary_range_attr", never_extract]
opaque reportBinaryRangeAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_binary_range_policy", never_extract]
opaque reportBinaryRangePolicy
  (attr policy ty extack : UInt64) : UInt64

@[extern "lean_nlattr_report_integer_range_attr", never_extract]
opaque reportIntegerRangeAttr (attr extack : UInt64) : UInt64

@[extern "lean_nlattr_report_integer_range_policy", never_extract]
opaque reportIntegerRangePolicy
  (attr policy ty extack : UInt64) : UInt64

@[always_inline]
def reportInvalidAttrLen (attr policy ty extack : UInt64) : UInt64 :=
  let _ := warnInvalidAttrLen ty
  if policy == 0 then
    reportInvalidAttrLenAttr attr extack
  else
    reportInvalidAttrLenPolicy attr policy ty extack

@[always_inline]
def reportNestedMissing (attr policy ty extack : UInt64) : UInt64 :=
  if policy == 0 then
    reportNestedMissingAttr attr extack
  else
    reportNestedMissingPolicy attr policy ty extack

@[always_inline]
def reportNestedUnexpected (attr policy ty extack : UInt64) : UInt64 :=
  if policy == 0 then
    reportNestedUnexpectedAttr attr extack
  else
    reportNestedUnexpectedPolicy attr policy ty extack

@[always_inline]
def reportFailedPolicy (attr policy ty extack : UInt64) : UInt64 :=
  if policy == 0 then
    reportFailedPolicyAttr attr extack
  else
    reportFailedPolicyPolicy attr policy ty extack

@[always_inline]
def reportReject (attr policy ty extack : UInt64) : UInt64 :=
  if extack != 0 && attr != 0 && policy != 0 &&
      rawPolicyUnionPtr policy ty != 0 then
    reportRejectMessage attr policy ty extack
  else
    reportFailedPolicy attr policy ty extack

@[always_inline]
def reportBinaryRange (attr policy ty extack : UInt64) : UInt64 :=
  if policy == 0 then
    reportBinaryRangeAttr attr extack
  else
    reportBinaryRangePolicy attr policy ty extack

@[always_inline]
def reportIntegerRange (attr policy ty extack : UInt64) : UInt64 :=
  if policy == 0 then
    reportIntegerRangeAttr attr extack
  else
    reportIntegerRangePolicy attr policy ty extack

@[always_inline]
def reportValidateError
    (reason attr policy ty extack : UInt64) : UInt64 :=
  if reason == diagRecursionDepth then
    reportRecursionDepth extack
  else if reason == diagUnknownAttr then
    reportUnknownAttr attr extack
  else if reason == diagTrailingBytes then
    let _ := warnTrailingBytes 0
    reportTrailingBytes extack
  else if reason == diagInvalidAttrLen then
    reportInvalidAttrLen attr policy ty extack
  else if reason == diagNestedMissing then
    reportNestedMissing attr policy ty extack
  else if reason == diagNestedUnexpected then
    reportNestedUnexpected attr policy ty extack
  else if reason == diagReject then
    reportReject attr policy ty extack
  else if reason == diagUnsupportedAttr then
    reportUnsupportedAttr attr extack
  else if reason == diagReservedBit then
    reportReservedBit attr extack
  else if reason == diagBinaryRange then
    reportBinaryRange attr policy ty extack
  else if reason == diagIntegerRange then
    reportIntegerRange attr policy ty extack
  else if reason == diagBinaryWarnTooLong then
    reportInvalidAttrLen attr policy ty extack
  else if reason == diagBinaryWarnTooLongAccepted then
    warnInvalidAttrLen ty
  else
    reportFailedPolicy attr policy ty extack

@[always_inline]
def keepReported (reported status : UInt64) : UInt64 :=
  if reported == u64Max then reported else status

@[extern "lean_nlattr_strdup_alloc", never_extract]
opaque strdupAlloc (len flags : UInt64) : UInt64

@[extern "lean_nlattr_skb_tailroom", never_extract]
opaque skbTailroom (skb : UInt64) : UInt64

@[extern "lean_nlattr_skb_needs_64bit_padding", never_extract]
opaque skbNeeds64BitPadding (skb : UInt64) : UInt64

@[extern "lean_nlattr_skb_align_64bit", never_extract]
opaque skbAlign64Bit (skb padattr : UInt64) : UInt64

@[extern "lean_nlattr_skb_put_raw", never_extract]
opaque skbPutRaw (skb len : UInt64) : UInt64

@[always_inline]
def align4 (n : UInt64) : UInt64 :=
  (n + 3) &&& 0xfffffffffffffffc

@[always_inline]
def nlaAttrSize (payloadLen : UInt64) : UInt64 :=
  nlaHeaderLen + payloadLen

@[always_inline]
def nlaTotalSize (payloadLen : UInt64) : UInt64 :=
  align4 (nlaAttrSize payloadLen)

@[always_inline]
def nlaPadLen (payloadLen : UInt64) : UInt64 :=
  nlaTotalSize payloadLen - nlaAttrSize payloadLen

@[always_inline]
def builderHasNoHeader (flags : UInt64) : Bool :=
  (flags &&& 1) != 0

@[always_inline]
def builderHas64BitPad (flags : UInt64) : Bool :=
  (flags &&& 2) != 0

@[always_inline]
def builderRequiredSize (attrLen flags : UInt64) : UInt64 :=
  let base :=
    if builderHasNoHeader flags then
      align4 attrLen
    else
      nlaTotalSize attrLen
  if builderHas64BitPad flags then
    base + 4
  else
    base

@[always_inline]
def builderStatus (tailroom attrLen flags : UInt64) : UInt64 :=
  let required := builderRequiredSize attrLen flags
  if tailroom < required then emsgsize else ok

@[always_inline]
def skbPutAttrArgsValid
    (totalSize attrSize padLen : UInt64) : Bool :=
  totalSize <= intMax && attrSize <= u16Max && padLen <= intMax

@[always_inline]
def skbPutZeroLenValid (len : UInt64) : Bool :=
  len <= intMax

@[always_inline]
def min64 (a b : UInt64) : UInt64 :=
  if a <= b then a else b

@[always_inline]
def hasFlag (flags bit : UInt64) : Bool :=
  (flags &&& bit) != 0

@[always_inline]
def unsupportedValidateFlags (validate : UInt64) : Bool :=
  (validate &&& validateStrict) != validate

@[always_inline]
def withStrictStart (strictStart ty validate : UInt64) : UInt64 :=
  if strictStart != 0 && ty >= strictStart then validate ||| validateStrict else validate

@[always_inline]
def isNestedKind (kind : UInt64) : Bool :=
  kind == kindNested || kind == kindNestedPolicy || kind == kindNestedArrayPolicy

@[always_inline]
def lenBound16 (len : UInt64) : UInt64 :=
  if len > u16Max then u16Max else len

def packPolicyMeta
    (kind validation valueKind isUnspec strictLen minLen maxLen : UInt64) :
    UInt64 :=
  kind ||| (validation <<< 8) ||| (valueKind <<< 16) |||
    (isUnspec <<< 24) ||| ((strictLen &&& 0xf) <<< 25) |||
    (lenBound16 minLen <<< 32) ||| (lenBound16 maxLen <<< 48)

def policyInfoType (info : UInt64) : UInt64 :=
  info &&& 0xff

def policyInfoValidation (info : UInt64) : UInt64 :=
  (info >>> 8) &&& 0xff

def policyInfoLen (info : UInt64) : UInt64 :=
  (info >>> 16) &&& 0xffff

def policyInfoUnionPtrPresent (info : UInt64) : Bool :=
  ((info >>> 32) &&& 1) != 0

def policyInfoHasRequiredRangePtr (info : UInt64) : Bool :=
  policyInfoValidation info != policyValidateRangePtr ||
    policyInfoUnionPtrPresent info

def policyInfoHasNestedPolicy (info : UInt64) : Bool :=
  ((info >>> 33) &&& 1) != 0

def unpackS16 (v : UInt64) : UInt64 :=
  let lo := v &&& u16Max
  if (lo &&& 0x8000) == 0 then lo else lo ||| 0xffffffffffff0000

def packS16AsS32Bits (v : UInt64) : UInt64 :=
  unpackS16 v &&& u32Max

def policyInfoFromRow (row : PolicyRowView) : UInt64 :=
  let ptrPresent : UInt64 := if row.unionPtr == 0 then 0 else 1
  row.policyType |||
    (row.validation <<< 8) |||
    (row.len <<< 16) |||
    (ptrPresent <<< 32) |||
    (ptrPresent <<< 33)

def policyInfo (policy ty : UInt64) : UInt64 :=
  policyInfoFromRow (PolicyRowView.ofRaw policy ty)

def unpackS32 (v : UInt64) : UInt64 :=
  let lo := v &&& u32Max
  if (lo &&& 0x80000000) == 0 then lo else lo ||| 0xffffffff00000000

def policyBounds (policy ty : UInt64) : UInt64 :=
  let row := PolicyRowView.ofRaw policy ty
  packS16AsS32Bits row.unionLo16 |||
    (packS16AsS32Bits row.unionHi16 <<< 32)

def policyBoundsMin (bounds : UInt64) : UInt64 :=
  unpackS32 bounds

def policyBoundsMax (bounds : UInt64) : UInt64 :=
  unpackS32 (bounds >>> 32)

@[always_inline]
def PolicyRowView.bounds (row : PolicyRowView) : UInt64 :=
  packS16AsS32Bits row.unionLo16 |||
    (packS16AsS32Bits row.unionHi16 <<< 32)

@[always_inline]
def PolicyRowView.valueMin (row : PolicyRowView) : UInt64 :=
  let rangePtr := row.unionPtr
  if rangePtr == 0 then 0 else regionLE64 (rawRegion rangePtr 16) 0

@[always_inline]
def PolicyRowView.valueMax (row : PolicyRowView) : UInt64 :=
  let rangePtr := row.unionPtr
  if rangePtr == 0 then 0 else regionLE64 (rawRegion rangePtr 16) 8

@[always_inline]
def PolicyRowView.normalMin (row : PolicyRowView) (validation : UInt64) : UInt64 :=
  if validation == policyValidateRangePtr then
    row.valueMin
  else
    policyBoundsMin row.bounds

@[always_inline]
def PolicyRowView.normalMax (row : PolicyRowView) (validation : UInt64) : UInt64 :=
  if validation == policyValidateRangePtr then
    row.valueMax
  else
    policyBoundsMax row.bounds

def policyMask (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).mask

def policyStrictStart (policy : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy 0).unionLo16

def policyNestedPolicy (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).unionPtr

def policyNestedMaxtype (policy ty : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).len

@[always_inline]
def typeMinLen (ty : UInt64) : UInt64 :=
  if ty == nlaU8 || ty == nlaS8 then
    1
  else if ty == nlaU16 || ty == nlaS16 || ty == nlaBE16 then
    2
  else if ty == nlaU32 || ty == nlaS32 || ty == nlaBE32 then
    4
  else if ty == nlaU64 || ty == nlaS64 || ty == nlaMsecs then
    8
  else if ty == nlaNested || ty == nlaNestedArray then
    nlaHeaderLen
  else
    0

@[always_inline]
def typeAttrLen (ty : UInt64) : UInt64 :=
  if ty == nlaU8 || ty == nlaS8 then
    1
  else if ty == nlaU16 || ty == nlaS16 || ty == nlaBE16 then
    2
  else if ty == nlaU32 || ty == nlaS32 || ty == nlaBE32 then
    4
  else if ty == nlaU64 || ty == nlaS64 then
    8
  else
    0

@[always_inline]
def policyLenMinLen (ty : UInt64) : UInt64 :=
  if ty == nlaU8 || ty == nlaS8 then
    1
  else if ty == nlaU16 || ty == nlaS16 || ty == nlaBE16 then
    2
  else if ty == nlaU32 || ty == nlaS32 || ty == nlaBE32 then
    4
  else if ty == nlaU64 || ty == nlaS64 || ty == nlaMsecs then
    8
  else if ty == nlaNested then
    nlaHeaderLen
  else
    0

@[always_inline]
def validationIsUnsigned (validation : UInt64) : Bool :=
  validation == policyValidateNone ||
    validation == policyValidateRange ||
    validation == policyValidateRangeWarnTooLong ||
    validation == policyValidateMin ||
    validation == policyValidateMax ||
    validation == policyValidateMask ||
    validation == policyValidateRangePtr ||
    validation == policyValidateFunction

@[always_inline]
def validationIsSigned (validation : UInt64) : Bool :=
  validation == policyValidateNone ||
    validation == policyValidateRange ||
    validation == policyValidateMin ||
    validation == policyValidateMax ||
    validation == policyValidateRangePtr ||
    validation == policyValidateFunction

@[always_inline]
def validationIsBinary (validation : UInt64) : Bool :=
  validation == policyValidateNone ||
    validation == policyValidateRange ||
    validation == policyValidateRangeWarnTooLong ||
    validation == policyValidateMin ||
    validation == policyValidateMax ||
    validation == policyValidateRangePtr ||
    validation == policyValidateFunction

@[always_inline]
def validationIsNoneOrFunction (validation : UInt64) : Bool :=
  validation == policyValidateNone || validation == policyValidateFunction

@[always_inline]
def policyValueKindForType (ty : UInt64) : UInt64 :=
  if ty == nlaU8 then
    valueUnsigned8
  else if ty == nlaU16 then
    valueUnsigned16
  else if ty == nlaU32 then
    valueUnsigned32
  else if ty == nlaU64 then
    valueUnsigned64
  else if ty == nlaUInt then
    valueUnsigned32Or64
  else if ty == nlaMsecs then
    valueMsecs
  else if ty == nlaBE16 then
    valueBigUnsigned16
  else if ty == nlaBE32 then
    valueBigUnsigned32
  else if ty == nlaS8 then
    valueSigned8
  else if ty == nlaS16 then
    valueSigned16
  else if ty == nlaS32 then
    valueSigned32
  else if ty == nlaS64 then
    valueSigned64
  else if ty == nlaSInt then
    valueSigned32Or64
  else if ty == nlaBinary then
    valueBinaryLen
  else
    valueNone

@[always_inline]
def policyKindFor (policy _ty info : UInt64) : UInt64 :=
  if policy == 0 then
    kindAccept
  else
    let pty := policyInfoType info
    let validation := policyInfoValidation info
    let len := policyInfoLen info
    if !policyInfoHasRequiredRangePtr info then
      kindUnsupported
    else if pty == nlaUnspec then
      if validationIsNoneOrFunction validation then
        if len != 0 then kindMin else kindAccept
      else
        kindUnsupported
    else if pty == nlaBinary then
      if !validationIsBinary validation then
        kindUnsupported
      else
        if len != 0 then kindRange else kindAccept
    else if pty == nlaFlag then
      if validationIsNoneOrFunction validation then kindFlag else kindUnsupported
    else if pty == nlaU8 || pty == nlaU16 || pty == nlaU32 ||
        pty == nlaU64 || pty == nlaMsecs || pty == nlaBE16 ||
        pty == nlaBE32 then
      if validationIsUnsigned validation then kindMin else kindUnsupported
    else if pty == nlaS8 || pty == nlaS16 || pty == nlaS32 ||
        pty == nlaS64 then
      if validationIsSigned validation then kindMin else kindUnsupported
    else if pty == nlaUInt then
      if validationIsUnsigned validation then kindInt32Or64 else kindUnsupported
    else if pty == nlaSInt then
      if validationIsSigned validation then kindInt32Or64 else kindUnsupported
    else if pty == nlaString then
      if validationIsNoneOrFunction validation then kindString else kindUnsupported
    else if pty == nlaNulString then
      if validationIsNoneOrFunction validation then kindNulString else kindUnsupported
    else if pty == nlaBitfield32 then
      if validationIsNoneOrFunction validation then kindBitfield32 else kindUnsupported
    else if pty == nlaNested then
      if !validationIsNoneOrFunction validation then
        kindUnsupported
      else if policyInfoHasNestedPolicy info then
        kindNestedPolicy
      else
        kindNested
    else if pty == nlaNestedArray then
      if !validationIsNoneOrFunction validation then
        kindUnsupported
      else if policyInfoHasNestedPolicy info then
        kindNestedArrayPolicy
      else
        kindNested
    else if pty == nlaReject then
      if validation == policyValidateNone then kindReject else kindUnsupported
    else
      kindUnsupported

@[always_inline]
def policyMinLenFor (_policy _ty info : UInt64) : UInt64 :=
  let pty := policyInfoType info
  if pty == nlaBinary then
    0
  else
    let len := policyInfoLen info
    if len != 0 then len else typeMinLen pty

@[always_inline]
def policyMaxLenFor (_policy _ty info : UInt64) : UInt64 :=
  policyInfoLen info

@[always_inline]
def policyNormalMin (policy ty validation : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).normalMin validation

@[always_inline]
def policyNormalMax (policy ty validation : UInt64) : UInt64 :=
  (PolicyRowView.ofRaw policy ty).normalMax validation

@[always_inline]
def policyMetaGeneric
    (policy ty info pty validation : UInt64) : UInt64 :=
  let kind := policyKindFor policy ty info
  let valueKind := policyValueKindForType pty
  let isUnspec : UInt64 := if pty == nlaUnspec then 1 else 0
  let strictLen := typeAttrLen pty
  let minLen :=
    if kind == kindExact then policyInfoLen info else policyMinLenFor policy ty info
  let maxLen :=
    if kind == kindExact then policyInfoLen info else policyMaxLenFor policy ty info
  packPolicyMeta kind validation valueKind isUnspec strictLen minLen maxLen

@[always_inline]
def policyMetaFromRow (policy ty : UInt64) (row : PolicyRowView) : UInt64 :=
  if policy == 0 then
    policyMetaAccept
  else
    let info := policyInfoFromRow row
    let pty := policyInfoType info
    let validation := policyInfoValidation info
    let len := policyInfoLen info
    if validation == policyValidateNone && policyInfoHasRequiredRangePtr info then
      if pty == nlaFlag then
        packPolicyMeta kindFlag policyValidateNone valueNone 0 0 0 0
      else if pty == nlaNulString then
        packPolicyMeta kindNulString policyValidateNone valueNone 0 0 len len
      else if pty == nlaBinary then
        if len == 0 then
          packPolicyMeta kindAccept policyValidateNone valueBinaryLen 0 0 0 0
        else
          packPolicyMeta kindRange policyValidateNone valueBinaryLen 0 0 0 len
      else
        policyMetaGeneric policy ty info pty validation
    else
      policyMetaGeneric policy ty info pty validation

@[always_inline]
def policyMeta (policy ty : UInt64) : UInt64 :=
  if policy == 0 then policyMetaAccept else
    policyMetaFromRow policy ty (PolicyRowView.ofRaw policy ty)

@[always_inline]
def policyPayloadLen (policy ix : UInt64) : UInt64 :=
  let info := policyInfo policy ix
  let len := policyInfoLen info
  if len != 0 then
    len
  else
    let pty := policyInfoType info
    let attrLen := typeAttrLen pty
    if attrLen != 0 then attrLen else policyLenMinLen pty

def packedByte (chunk ix : UInt64) : UInt64 :=
  (chunk >>> (ix * 8)) &&& 0xff

theorem u64_eq_false_of_toNat_ne {a b : UInt64}
    (h : a.toNat ≠ b.toNat) :
    (a == b) = false := by
  by_cases hEq : a = b
  · exact False.elim (h (by simp [hEq]))
  · simp [hEq]

theorem u64_add_toNat_of_lt_size (a b : UInt64)
    (h : a.toNat + b.toNat < UInt64.size) :
    (a + b).toNat = a.toNat + b.toNat := by
  rw [UInt64.toNat_add]
  exact Nat.mod_eq_of_lt h

theorem u64_gt_false_of_toNat_le {a b : UInt64}
    (h : a.toNat ≤ b.toNat) :
    (a > b) = false := by
  by_cases hGt : a > b
  · have hNat := UInt64.lt_iff_toNat_lt.mp hGt
    omega
  · simp [hGt]

theorem u64_lt_false_of_toNat_le {a b : UInt64}
    (h : b.toNat ≤ a.toNat) :
    (a < b) = false := by
  by_cases hLt : a < b
  · have hNat := UInt64.lt_iff_toNat_lt.mp hLt
    omega
  · simp [hLt]

theorem arrayIndexNospec_eq_of_lt {index size : UInt64}
    (h : index < size) :
    arrayIndexNospec index size = index := by
  unfold arrayIndexNospec
  simp [h]

theorem arrayIndexNospec_toNat_lt_of_size_ne_zero
    (index size : UInt64)
    (hSize : size != 0) :
    (arrayIndexNospec index size).toNat < size.toNat := by
  unfold arrayIndexNospec
  by_cases hIndex : index < size
  · by_cases hRaw : arrayIndexNospecRaw index size = index
    · simp [hIndex, hRaw]
      exact UInt64.lt_iff_toNat_lt.mp hIndex
    · simp [hIndex, hRaw]
      exact UInt64.lt_iff_toNat_lt.mp hIndex
  · have hSizeNe : size ≠ 0 := by
      intro hEq
      simp [hEq] at hSize
    have hSizePos : 0 < size.toNat := by
      have hPos : (0 : UInt64) < size :=
        UInt64.pos_iff_ne_zero.mpr hSizeNe
      simpa using UInt64.lt_iff_toNat_lt.mp hPos
    by_cases hRaw : arrayIndexNospecRaw index size = 0
    · simp [hIndex, hRaw]
      exact hSizePos
    · simp [hIndex, hRaw]
      exact hSizePos

theorem arrayIndexNospec_eq_of_toNat_lt
    (index size : UInt64)
    (h : index.toNat < size.toNat) :
    arrayIndexNospec index size = index :=
  arrayIndexNospec_eq_of_lt (UInt64.lt_iff_toNat_lt.mpr h)

theorem arrayIndexNospec_eq_of_le_maxtype_no_overflow
    (ty maxtype : UInt64)
    (hTy : ty.toNat ≤ maxtype.toNat)
    (hNoOverflow : maxtype.toNat + 1 < UInt64.size) :
    arrayIndexNospec ty (maxtype + 1) = ty := by
  have hAdd :
      (maxtype + 1).toNat = maxtype.toNat + 1 := by
    exact u64_add_toNat_of_lt_size maxtype 1 (by simpa using hNoOverflow)
  apply arrayIndexNospec_eq_of_toNat_lt
  rw [hAdd]
  omega

theorem nat_three_testBit_ge_two_false (i : Nat) (h : 2 ≤ i) :
    (3 : Nat).testBit i = false := by
  rcases Nat.exists_eq_add_of_le h with ⟨k, rfl⟩
  simp [Nat.testBit_eq_decide_div_mod_eq]
  have hpow : 3 < 2 ^ (k + 2) := by
    induction k with
    | zero => decide
    | succ k ih =>
        rw [Nat.pow_succ]
        omega
  have hdiv : 3 / 2 ^ (2 + k) = 0 := by
    rw [Nat.add_comm]
    exact Nat.div_eq_of_lt hpow
  rw [hdiv]

theorem nat_align4_mask_eq_div_mul
    (m : Nat) (h : m < 2 ^ 64) :
    m &&& 18446744073709551612 = (m / 4) * 4 := by
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and]
  have hMask :
      (18446744073709551612 : Nat).testBit i =
        (decide (i < 64) && !(3 : Nat).testBit i) := by
    have hMaskNat : (18446744073709551612 : Nat) = 2 ^ 64 - (3 + 1) := by
      decide
    rw [hMaskNat]
    exact Nat.testBit_two_pow_sub_succ (by decide : 3 < 2 ^ 64) i
  rw [hMask]
  rw [show (m / 4) * 4 = 2 ^ 2 * (m / 4) by omega]
  rw [Nat.testBit_two_pow_mul]
  by_cases hi2 : 2 ≤ i
  · have h3 : (3 : Nat).testBit i = false :=
      nat_three_testBit_ge_two_false i hi2
    have hlt64 : i < 64 ↔ i < 64 := Iff.rfl
    by_cases hi64 : i < 64
    · have hmBit :
          m.testBit i = (m / 4).testBit (i - 2) := by
        have hmod : m % 4 < 2 ^ 2 := by
          exact Nat.mod_lt m (by decide : 0 < 4)
        have hdecomp : 2 ^ 2 * (m / 4) + m % 4 = m := by
          have hdiv := Nat.div_add_mod m 4
          omega
        have hbit := congrArg (fun x => x.testBit i) hdecomp
        rw [← hbit]
        rw [Nat.testBit_two_pow_mul_add (m / 4) hmod i]
        have hNotLt : ¬ i < 2 := by omega
        simp [hNotLt]
      simp [h3, hi2, hi64, hmBit]
    · have hmZero : m.testBit i = false := by
        rw [Nat.testBit_eq_decide_div_mod_eq]
        have hPowLe : 2 ^ 64 ≤ 2 ^ i := by
          exact Nat.pow_le_pow_right (by decide : 1 ≤ 2) (by omega)
        have hmLtPow : m < 2 ^ i := Nat.lt_of_lt_of_le h hPowLe
        have hdiv : m / 2 ^ i = 0 := Nat.div_eq_of_lt hmLtPow
        simp [hdiv]
      have hDivZero : (m / 4).testBit (i - 2) = false := by
        rw [Nat.testBit_eq_decide_div_mod_eq]
        have hDivLt : m / 4 < 2 ^ (i - 2) := by
          have hiGe64 : 64 ≤ i := Nat.le_of_not_gt hi64
          by_cases hLe : 2 ^ (i - 2) ≤ m / 4
          · have hMulLe :
                4 * 2 ^ (i - 2) ≤ 4 * (m / 4) :=
              Nat.mul_le_mul_left 4 hLe
            have hLeM : 4 * (m / 4) ≤ m := by
              have hdiv := Nat.div_add_mod m 4
              omega
            have hPow4 : 4 * 2 ^ (i - 2) = 2 ^ i := by
              have hsplit : 2 + (i - 2) = i := by omega
              rw [show 4 = 2 ^ 2 by decide]
              rw [← Nat.pow_add, hsplit]
            have h2iLeM : 2 ^ i ≤ m := by
              rw [← hPow4]
              exact Nat.le_trans hMulLe hLeM
            have h64Le2i : 2 ^ 64 ≤ 2 ^ i :=
              Nat.pow_le_pow_right (by decide : 1 ≤ 2) hiGe64
            have h64LeM : 2 ^ 64 ≤ m := Nat.le_trans h64Le2i h2iLeM
            omega
          · exact Nat.lt_of_not_ge hLe
        have hdiv : (m / 4) / 2 ^ (i - 2) = 0 :=
          Nat.div_eq_of_lt hDivLt
        simp [hdiv]
      simp [h3, hi2, hi64, hmZero, hDivZero]
  · have hiLt2 : i < 2 := Nat.lt_of_not_ge hi2
    have hMaskBit : (3 : Nat).testBit i = true := by
      cases i with
      | zero => decide
      | succ i =>
          cases i with
          | zero => decide
          | succ k => omega
    have hRhsZero :
        (decide (i ≥ 2) && (m / 4).testBit (i - 2)) = false := by
      simp [hi2]
    simp [hMaskBit, hRhsZero]

theorem align4_toNat_eq_layout_align4_of_u32 (n : UInt64)
    (h : n.toNat < 4294967296) :
    (align4 n).toNat = Memory.Layout.align4 n.toNat := by
  unfold align4 Memory.Layout.align4 Memory.align4Nat
  rw [UInt64.toNat_and, UInt64.toNat_add]
  rw [UInt64.toNat_ofNat_of_lt (by decide : 3 < UInt64.size)]
  rw [UInt64.toNat_ofNat_of_lt
    (by decide : 18446744073709551612 < UInt64.size)]
  rw [Nat.mod_eq_of_lt]
  · exact nat_align4_mask_eq_div_mul (n.toNat + 3) (by omega)
  · omega

theorem u64PredToNatLt (fuel : UInt64) (h : fuel != 0) :
    (fuel - 1).toNat < fuel.toNat := by
  have hne : fuel ≠ 0 := by
    intro hz
    simp [hz] at h
  have hpos : (0 : UInt64) < fuel := UInt64.pos_iff_ne_zero.mpr hne
  have hone : (0 : UInt64) < 1 := by decide
  have hle : (1 : UInt64) ≤ fuel := by
    rw [UInt64.le_iff_toNat_le]
    have hposNat : 0 < fuel.toNat := UInt64.lt_iff_toNat_lt.mp hpos
    simp
    exact hposNat
  exact UInt64.lt_iff_toNat_lt.mp (UInt64.sub_lt hone hle)

theorem u64PredToNatLtOfBoolNeZero
    (fuel : UInt64) (h : ¬(fuel == 0) = true) :
    (fuel - 1).toNat < fuel.toNat := by
  have hnz : fuel != 0 := by
    simp at h
    simp [h]
  exact u64PredToNatLt fuel hnz

def nlattrHeaderView (nla : UInt64) : AttrView :=
  AttrView.ofRaw nla nlaHeaderLen

def nlattrDeclaredLen (nla : UInt64) : UInt64 :=
  attrHeaderLen ((nlattrHeaderView nla).header 0)

@[always_inline]
def nlattrPayloadLenFromDeclared (declaredLen : UInt64) : UInt64 :=
  if declaredLen < nlaHeaderLen then cmpUnsupported else declaredLen - nlaHeaderLen

def nlattrPayloadLenChecked (nla : UInt64) : UInt64 :=
  let declaredLen := nlattrDeclaredLen nla
  let payloadLen := nlattrPayloadLenFromDeclared declaredLen
  if payloadLen == cmpUnsupported || payloadLen > intMax then
    cmpUnsupported
  else
    payloadLen

def nlattrFullView (nla : UInt64) (declaredLen : UInt64) : AttrView :=
  AttrView.ofRaw nla declaredLen

def zeroBytesLoop (ptr ix count fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if count == 0 then
    0
  else
    let ret := ptrSetByte ptr ix 0
    if ret != 0 then
      ret
    else
      zeroBytesLoop ptr (ix + 1) (count - 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def zeroBytes (ptr ix count : UInt64) : UInt64 :=
  zeroBytesLoop ptr ix count count

def viewAttrCopyLoop (dest : UInt64) (view : AttrView) (ix count fuel : UInt64) :
    UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if count == 0 then
    0
  else
    let ret := ptrSetByte dest ix (view.byte 0 ix)
    if ret != 0 then
      ret
    else
      viewAttrCopyLoop dest view (ix + 1) (count - 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def viewAttrCopy (dest : UInt64) (view : AttrView) (count : UInt64) : UInt64 :=
  viewAttrCopyLoop dest view 0 count count

def regionCopyToOffsetLoop
    (dest destOff : UInt64) (src : Memory.Region) (ix count fuel : UInt64) :
    UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if count == 0 then
    0
  else
    let ret := ptrSetByte dest (destOff + ix) (regionByte src ix)
    if ret != 0 then
      ret
    else
      regionCopyToOffsetLoop dest destOff src (ix + 1) (count - 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def regionCopyToOffset
    (dest destOff : UInt64) (src : Memory.Region) (count : UInt64) : UInt64 :=
  regionCopyToOffsetLoop dest destOff src 0 count count

def nlaCopyData (nla data count : UInt64) : UInt64 :=
  regionCopyToOffset nla nlaHeaderLen (rawRegion data count) count

def copyData (dest data count : UInt64) : UInt64 :=
  regionCopyToOffset dest 0 (rawRegion data count) count

def ptrSetU16LE (ptr off value : UInt64) : UInt64 :=
  let ret := ptrSetByte ptr off (value &&& 0xff)
  if ret != 0 then
    ret
  else
    ptrSetByte ptr (off + 1) ((value >>> 8) &&& 0xff)

def ptrSetU64LELoop
    (ptr off value ix fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if ix >= 8 then
    0
  else
    let ret := ptrSetByte ptr (off + ix) ((value >>> (ix * 8)) &&& 0xff)
    if ret != 0 then
      ret
    else
      ptrSetU64LELoop ptr off value (ix + 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def ptrSetU64LE (ptr off value : UInt64) : UInt64 :=
  ptrSetU64LELoop ptr off value 0 8

def rangeStore (range minValue maxValue : UInt64) : UInt64 :=
  let ret := ptrSetU64LE range 0 minValue
  if ret != 0 then
    ret
  else
    ptrSetU64LE range 8 maxValue

def rangeUnsignedStore (range minValue maxValue : UInt64) : UInt64 :=
  rangeStore range minValue maxValue

def rangeSignedStore (range minValue maxValue : UInt64) : UInt64 :=
  rangeStore range minValue maxValue

def initNlAttr (nla attrtype attrSize padLen : UInt64) : UInt64 :=
  let ret := ptrSetU16LE nla 0 attrSize
  if ret != 0 then
    ret
  else
    let ret := ptrSetU16LE nla 2 attrtype
    if ret != 0 then
      ret
    else
      zeroBytes nla attrSize padLen

def zeroTableLoop (tb ix count fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if ix >= count then
    0
  else
    let ret := setTb tb ix 0
    if ret != 0 then
      ret
    else
      zeroTableLoop tb (ix + 1) count (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def zeroTable (tb count : UInt64) : UInt64 :=
  zeroTableLoop tb 0 count count

def packedContainsZero (chunk count ix fuel : UInt64) : Bool :=
  if hfuel : fuel == 0 then
    false
  else if ix >= count then
    false
  else if packedByte chunk ix == 0 then
    true
  else
    packedContainsZero chunk count (ix + 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def viewAttrWordLoop
    (view : AttrView) (off ix count shift acc fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    acc
  else if count == 0 then
    acc
  else
    let byte := view.byte off ix
    viewAttrWordLoop view off (ix + 1) (count - 1) (shift + 8)
      (acc ||| (byte <<< shift)) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def viewAttrWord (view : AttrView) (off ix count : UInt64) : UInt64 :=
  let count' := min64 8 count
  viewAttrWordLoop view off ix count' 0 0 count'

def viewContainsZero
    (view : AttrView) (off limit ix fuel : UInt64) : Bool :=
  if hfuel : fuel == 0 then
    false
  else if ix >= limit then
    false
  else
    let count := min64 8 (limit - ix)
    let chunk := viewAttrWord view off ix count
    if packedContainsZero chunk count 0 (count + 1) then
      true
    else
      viewContainsZero view off limit (ix + count) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

@[always_inline]
def viewReadPayloadLE32 (view : AttrView) (off ix : UInt64) : UInt64 :=
  viewAttrWord view off ix 4

@[always_inline]
def viewReadPayloadLE16 (view : AttrView) (off ix : UInt64) : UInt64 :=
  viewAttrWord view off ix 2

@[always_inline]
def viewReadPayloadLE64 (view : AttrView) (off ix : UInt64) : UInt64 :=
  viewAttrWord view off ix 8

@[always_inline]
def viewReadPayloadBE16 (view : AttrView) (off ix : UInt64) : UInt64 :=
  (view.byte off ix <<< 8)
    + view.byte off (ix + 1)

@[always_inline]
def viewReadPayloadBE32 (view : AttrView) (off ix : UInt64) : UInt64 :=
  (view.byte off ix <<< 24)
    + (view.byte off (ix + 1) <<< 16)
    + (view.byte off (ix + 2) <<< 8)
    + view.byte off (ix + 3)

@[always_inline]
def signExtend8 (v : UInt64) : UInt64 :=
  if (v &&& 0x80) == 0 then v else v ||| 0xffffffffffffff00

@[always_inline]
def signExtend16 (v : UInt64) : UInt64 :=
  if (v &&& 0x8000) == 0 then v else v ||| 0xffffffffffff0000

@[always_inline]
def signExtend32 (v : UInt64) : UInt64 :=
  if (v &&& 0x80000000) == 0 then v else v ||| 0xffffffff00000000

@[always_inline]
def isNegative64 (v : UInt64) : Bool :=
  (v &&& 0x8000000000000000) != 0

@[always_inline]
def cmpEncodeByteDiff (a b : UInt64) : UInt64 :=
  if a >= b then
    a - b
  else
    cmpNegative ||| (b - a)

def viewAttrMemcmpLoop
    (view : AttrView) (data : Memory.Region) (ix count fuel : UInt64) :
    UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if count == 0 then
    0
  else
    let a := view.byte 0 ix
    let b := regionByte data ix
    if a == b then
      viewAttrMemcmpLoop view data (ix + 1) (count - 1) (fuel - 1)
    else
      cmpEncodeByteDiff a b
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def viewAttrMemcmp (view : AttrView) (data : UInt64) (count : UInt64) : UInt64 :=
  viewAttrMemcmpLoop view (rawRegion data count) 0 count count

def cstrLenLoop (ptr ix fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    ix
  else if ptrByte ptr ix == 0 then
    ix
  else
    cstrLenLoop ptr (ix + 1) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def cstrLen (ptr : UInt64) : UInt64 :=
  cstrLenLoop ptr 0 (intMax + 1)

@[always_inline]
def encodeRawErrnoResult (ret : UInt64) : UInt64 :=
  if ret == ok then
    ok
  else
    let errno := if isNegative64 ret then 0 - ret else ret
    let errno := if errno == 0 || errno > intMax then einval else errno
    errnoFlag ||| errno

@[always_inline]
def policyValidateFn (policy ty attr extack : UInt64) : UInt64 :=
  if rawPolicyValidatePtr policy ty == 0 then
    ok
  else
    encodeRawErrnoResult (policyValidateFnRaw policy ty attr extack)

@[always_inline]
def policyValidateFnFromRow
    (row : PolicyRowView) (policy ty attr extack : UInt64) : UInt64 :=
  if row.unionPtr == 0 then
    ok
  else
    encodeRawErrnoResult (policyValidateFnRaw policy ty attr extack)

@[always_inline]
def slt64 (a b : UInt64) : Bool :=
  let an := isNegative64 a
  let bn := isNegative64 b
  if an && !bn then
    true
  else if !an && bn then
    false
  else
    a < b

@[always_inline]
def valueReadWidth (kind : UInt64) : UInt64 :=
  if kind == valueUnsigned8 || kind == valueSigned8 then
    1
  else if kind == valueUnsigned16 || kind == valueBigUnsigned16 ||
      kind == valueSigned16 then
    2
  else if kind == valueUnsigned32 || kind == valueBigUnsigned32 ||
      kind == valueSigned32 then
    4
  else if kind == valueUnsigned64 || kind == valueMsecs ||
      kind == valueSigned64 then
    8
  else
    0

@[always_inline]
def isUnsignedValueKind (kind : UInt64) : Bool :=
  kind == valueUnsigned8 || kind == valueUnsigned16 ||
    kind == valueUnsigned32 || kind == valueUnsigned64 ||
    kind == valueUnsigned32Or64 || kind == valueMsecs ||
    kind == valueBigUnsigned16 || kind == valueBigUnsigned32

@[always_inline]
def isSignedValueKind (kind : UInt64) : Bool :=
  kind == valueSigned8 || kind == valueSigned16 ||
    kind == valueSigned32 || kind == valueSigned64 ||
    kind == valueSigned32Or64

@[always_inline]
def isMaskableValueKind (kind : UInt64) : Bool :=
  kind == valueUnsigned8 || kind == valueUnsigned16 ||
    kind == valueUnsigned32 || kind == valueUnsigned64 ||
    kind == valueUnsigned32Or64 ||
    kind == valueBigUnsigned16 || kind == valueBigUnsigned32

@[always_inline]
def viewReadUnsignedValue
    (view : AttrView) (off payloadLen kind : UInt64) : UInt64 :=
  if kind == valueUnsigned8 then
    view.byte off 0
  else if kind == valueUnsigned16 then
    viewReadPayloadLE16 view off 0
  else if kind == valueUnsigned32 then
    viewReadPayloadLE32 view off 0
  else if kind == valueUnsigned64 || kind == valueMsecs then
    viewReadPayloadLE64 view off 0
  else if kind == valueUnsigned32Or64 then
    if payloadLen == 4 then viewReadPayloadLE32 view off 0 else viewReadPayloadLE64 view off 0
  else if kind == valueBigUnsigned16 then
    viewReadPayloadBE16 view off 0
  else if kind == valueBigUnsigned32 then
    viewReadPayloadBE32 view off 0
  else
    0

@[always_inline]
def viewReadSignedValue
    (view : AttrView) (off payloadLen kind : UInt64) : UInt64 :=
  if kind == valueSigned8 then
    signExtend8 (view.byte off 0)
  else if kind == valueSigned16 then
    signExtend16 (viewReadPayloadLE16 view off 0)
  else if kind == valueSigned32 then
    signExtend32 (viewReadPayloadLE32 view off 0)
  else if kind == valueSigned64 then
    viewReadPayloadLE64 view off 0
  else if kind == valueSigned32Or64 then
    if payloadLen == 4 then
      signExtend32 (viewReadPayloadLE32 view off 0)
    else
      viewReadPayloadLE64 view off 0
  else
    0

@[always_inline]
def viewValidateString
    (view : AttrView) (off maxLen payloadLen : UInt64) : UInt64 :=
  if payloadLen < 1 then
    erange
  else
    let last := view.byte off (payloadLen - 1)
    let effectiveLen := if last == 0 then payloadLen - 1 else payloadLen
    if maxLen == 0 || effectiveLen <= maxLen then ok else erange

@[always_inline]
def viewValidateNulString
    (view : AttrView) (off maxLen payloadLen : UInt64) : UInt64 :=
  if payloadLen < 1 then
    erange
  else
    let scanLen := if maxLen == 0 then payloadLen else min64 payloadLen (maxLen + 1)
    if viewContainsZero view off scanLen 0 (scanLen + 1) then
      if maxLen == 0 || payloadLen <= maxLen then
        ok
      else if payloadLen > maxLen + 1 then
        erange
      else if view.byte off (payloadLen - 1) == 0 then
        ok
      else
        erange
    else
      einval

@[always_inline]
def viewValidateBitfield32
    (view : AttrView) (off policy ty payloadLen : UInt64) : UInt64 :=
  if payloadLen != 8 then
    erange
  else
    let mask := policyMask policy ty
    let value := viewReadPayloadLE32 view off 0
    let selector := viewReadPayloadLE32 view off 4
    if mask == 0 then
      einval
    else if (selector &&& mask) != selector then
      einval
    else if (value &&& mask) != value then
      einval
    else if (value &&& selector) != value then
      einval
    else
      ok

@[always_inline]
def validateUnsignedExtra
    (validation value minValue maxValue mask : UInt64) : UInt64 :=
  if validation == policyValidateRange ||
      validation == policyValidateRangeWarnTooLong ||
      validation == policyValidateRangePtr then
    if value < minValue || value > maxValue then erange else ok
  else if validation == policyValidateMin then
    if value < minValue then erange else ok
  else if validation == policyValidateMax then
    if value > maxValue then erange else ok
  else if validation == policyValidateMask then
    if (value &&& mask) != value then einval else ok
  else if validation == policyValidateNone then
    ok
  else
    unsupported

def UnsignedExtraAccepted
    (validation value minValue maxValue mask : UInt64) : Prop :=
  if validation == policyValidateRange ||
      validation == policyValidateRangeWarnTooLong ||
      validation == policyValidateRangePtr then
    minValue <= value && value <= maxValue
  else if validation == policyValidateMin then
    minValue <= value
  else if validation == policyValidateMax then
    value <= maxValue
  else if validation == policyValidateMask then
    (value &&& mask) == value
  else if validation == policyValidateNone then
    True
  else
    False

def UnsignedExtraSpec
    (validation value minValue maxValue mask : UInt64) : Prop :=
  ((validation = policyValidateRange ∨
      validation = policyValidateRangeWarnTooLong ∨
      validation = policyValidateRangePtr) ∧
    minValue ≤ value ∧ value ≤ maxValue) ∨
  (validation = policyValidateMin ∧ minValue ≤ value) ∨
  (validation = policyValidateMax ∧ value ≤ maxValue) ∨
  (validation = policyValidateMask ∧ value &&& mask = value) ∨
  validation = policyValidateNone

theorem unsignedExtraSpec_sound
    (validation value minValue maxValue mask : UInt64) :
    UnsignedExtraSpec validation value minValue maxValue mask →
      UnsignedExtraAccepted validation value minValue maxValue mask := by
  intro hSpec
  unfold UnsignedExtraSpec at hSpec
  rcases hSpec with ⟨hRange, hMin, hMax⟩
    | ⟨hValidationMin, hMin⟩
    | ⟨hValidationMax, hMax⟩
    | ⟨hValidationMask, hMask⟩
    | hValidationNone
  · rcases hRange with hValidationRange | hValidationWarn | hValidationPtr
    · simp [UnsignedExtraAccepted, hValidationRange, hMin, hMax]
    · simp [UnsignedExtraAccepted, hValidationWarn, hMin, hMax,
        policyValidateRange, policyValidateRangeWarnTooLong]
    · simp [UnsignedExtraAccepted, hValidationPtr, hMin, hMax,
        policyValidateRange, policyValidateRangeWarnTooLong,
        policyValidateRangePtr]
  · simp [UnsignedExtraAccepted, hValidationMin, hMin, policyValidateRange,
      policyValidateRangeWarnTooLong, policyValidateRangePtr,
      policyValidateMin]
  · simp [UnsignedExtraAccepted, hValidationMax, hMax, policyValidateRange,
      policyValidateRangeWarnTooLong, policyValidateRangePtr,
      policyValidateMin, policyValidateMax]
  · simp [UnsignedExtraAccepted, hValidationMask, hMask, policyValidateRange,
      policyValidateRangeWarnTooLong, policyValidateRangePtr,
      policyValidateMin, policyValidateMax, policyValidateMask]
  · simp [UnsignedExtraAccepted, hValidationNone, policyValidateRange,
      policyValidateRangeWarnTooLong, policyValidateRangePtr,
      policyValidateMin, policyValidateMax, policyValidateMask,
      policyValidateNone]

theorem unsignedExtraAccepted_complete
    (validation value minValue maxValue mask : UInt64) :
    UnsignedExtraAccepted validation value minValue maxValue mask →
      UnsignedExtraSpec validation value minValue maxValue mask := by
  intro hAccepted
  unfold UnsignedExtraSpec
  by_cases hRange : validation = policyValidateRange
  · left
    have hBounds : minValue ≤ value ∧ value ≤ maxValue := by
      simpa [UnsignedExtraAccepted, hRange] using hAccepted
    exact ⟨Or.inl hRange, hBounds.1, hBounds.2⟩
  · by_cases hWarn : validation = policyValidateRangeWarnTooLong
    · left
      have hBounds : minValue ≤ value ∧ value ≤ maxValue := by
        simpa [UnsignedExtraAccepted, hRange, hWarn, policyValidateRange,
          policyValidateRangeWarnTooLong] using hAccepted
      exact ⟨Or.inr (Or.inl hWarn), hBounds.1, hBounds.2⟩
    · by_cases hPtr : validation = policyValidateRangePtr
      · left
        have hBounds : minValue ≤ value ∧ value ≤ maxValue := by
          simpa [UnsignedExtraAccepted, hRange, hWarn, hPtr,
            policyValidateRange, policyValidateRangeWarnTooLong,
            policyValidateRangePtr] using hAccepted
        exact ⟨Or.inr (Or.inr hPtr), hBounds.1, hBounds.2⟩
      · right
        by_cases hMinVal : validation = policyValidateMin
        · left
          have hMin : minValue ≤ value := by
            simpa [UnsignedExtraAccepted, hRange, hWarn, hPtr, hMinVal,
              policyValidateRange, policyValidateRangeWarnTooLong,
              policyValidateRangePtr, policyValidateMin] using hAccepted
          exact ⟨hMinVal, hMin⟩
        · right
          by_cases hMaxVal : validation = policyValidateMax
          · left
            have hMax : value ≤ maxValue := by
              simpa [UnsignedExtraAccepted, hRange, hWarn, hPtr, hMinVal,
                hMaxVal, policyValidateRange, policyValidateRangeWarnTooLong,
                policyValidateRangePtr, policyValidateMin, policyValidateMax]
                using hAccepted
            exact ⟨hMaxVal, hMax⟩
          · right
            by_cases hMaskVal : validation = policyValidateMask
            · left
              have hMask : value &&& mask = value := by
                simpa [UnsignedExtraAccepted, hRange, hWarn, hPtr, hMinVal,
                  hMaxVal, hMaskVal, policyValidateRange,
                  policyValidateRangeWarnTooLong, policyValidateRangePtr,
                  policyValidateMin, policyValidateMax, policyValidateMask]
                  using hAccepted
              exact ⟨hMaskVal, hMask⟩
            · right
              by_cases hNone : validation = policyValidateNone
              · exact hNone
              · have hFalse : False := by
                  simp [UnsignedExtraAccepted, hRange, hWarn, hPtr, hMinVal,
                    hMaxVal, hMaskVal, hNone] at hAccepted
                exact False.elim hFalse

theorem unsignedExtraSpec_iff_accepted
    (validation value minValue maxValue mask : UInt64) :
    UnsignedExtraSpec validation value minValue maxValue mask ↔
      UnsignedExtraAccepted validation value minValue maxValue mask :=
  ⟨unsignedExtraSpec_sound validation value minValue maxValue mask,
    unsignedExtraAccepted_complete validation value minValue maxValue mask⟩

@[always_inline]
def validateBinaryExtra
    (payloadLen validation minValue maxValue validate : UInt64) : UInt64 :=
  if validation == policyValidateRangeWarnTooLong && payloadLen > maxValue then
    if hasFlag validate validateStrictAttrs then einval else ok
  else
    validateUnsignedExtra validation payloadLen minValue maxValue 0

def BinaryExtraAccepted
    (payloadLen validation minValue maxValue validate : UInt64) : Prop :=
  if validation == policyValidateRangeWarnTooLong && payloadLen > maxValue then
    (hasFlag validate validateStrictAttrs) = false
  else
    UnsignedExtraAccepted validation payloadLen minValue maxValue 0

def BinaryExtraSpec
    (payloadLen validation minValue maxValue validate : UInt64) : Prop :=
  (validation = policyValidateRangeWarnTooLong ∧ payloadLen > maxValue ∧
    hasFlag validate validateStrictAttrs = false) ∨
  ((validation ≠ policyValidateRangeWarnTooLong ∨ payloadLen ≤ maxValue) ∧
    UnsignedExtraSpec validation payloadLen minValue maxValue 0)

theorem binaryExtraSpec_iff_accepted
    (payloadLen validation minValue maxValue validate : UInt64) :
    BinaryExtraSpec payloadLen validation minValue maxValue validate ↔
      BinaryExtraAccepted payloadLen validation minValue maxValue validate := by
  unfold BinaryExtraSpec BinaryExtraAccepted
  by_cases hWarn : validation = policyValidateRangeWarnTooLong
  · by_cases hTooLong : payloadLen > maxValue
    · constructor
      · intro hSpec
        rcases hSpec with ⟨_hWarn, _hToo, hStrict⟩ | ⟨hNot, _hUnsigned⟩
        · simpa [hWarn, hTooLong] using hStrict
        · rcases hNot with hWarnNe | hLe
          · exact False.elim (hWarnNe hWarn)
          · have hFalse : False := by
              have hGtNat : maxValue.toNat < payloadLen.toNat :=
                UInt64.lt_iff_toNat_lt.mp hTooLong
              have hLeNat : payloadLen.toNat ≤ maxValue.toNat :=
                UInt64.le_iff_toNat_le.mp hLe
              omega
            exact False.elim hFalse
      · intro hAccepted
        have hStrict : hasFlag validate validateStrictAttrs = false := by
          simpa [hWarn, hTooLong] using hAccepted
        exact Or.inl ⟨hWarn, hTooLong, hStrict⟩
    · have hLe : payloadLen ≤ maxValue := by
        rw [UInt64.le_iff_toNat_le]
        by_cases hNat : payloadLen.toNat ≤ maxValue.toNat
        · exact hNat
        · have hGt : payloadLen > maxValue := by
            show maxValue < payloadLen
            rw [UInt64.lt_iff_toNat_lt]
            omega
          exact False.elim (hTooLong hGt)
      constructor
      · intro hSpec
        rcases hSpec with ⟨_hWarn, hToo, _hStrict⟩ | ⟨_hNot, hUnsigned⟩
        · exact False.elim (hTooLong hToo)
        · simpa [hWarn, hTooLong] using
            (unsignedExtraSpec_iff_accepted validation payloadLen minValue
              maxValue 0).mp hUnsigned
      · intro hAccepted
        have hUnsigned :
            UnsignedExtraAccepted validation payloadLen minValue maxValue 0 := by
          simpa [hWarn, hTooLong] using hAccepted
        exact Or.inr ⟨Or.inr hLe,
          (unsignedExtraSpec_iff_accepted validation payloadLen minValue
            maxValue 0).mpr hUnsigned⟩
  · constructor
    · intro hSpec
      rcases hSpec with ⟨hWarnEq, _hToo, _hStrict⟩ | ⟨_hNot, hUnsigned⟩
      · exact False.elim (hWarn hWarnEq)
      · simpa [hWarn] using
          (unsignedExtraSpec_iff_accepted validation payloadLen minValue
            maxValue 0).mp hUnsigned
    · intro hAccepted
      have hUnsigned :
          UnsignedExtraAccepted validation payloadLen minValue maxValue 0 := by
        simpa [hWarn] using hAccepted
      exact Or.inr ⟨Or.inl hWarn,
        (unsignedExtraSpec_iff_accepted validation payloadLen minValue
          maxValue 0).mpr hUnsigned⟩

@[always_inline]
def validateBinaryExtraReported
    (payloadLen validation minValue maxValue validate attr policy ty extack : UInt64) :
    UInt64 :=
  let ret := validateBinaryExtra payloadLen validation minValue maxValue validate
  if validation == policyValidateRangeWarnTooLong && payloadLen > maxValue then
    let reason :=
      if hasFlag validate validateStrictAttrs then
        diagBinaryWarnTooLong
      else
        diagBinaryWarnTooLongAccepted
    keepReported (reportValidateError reason attr policy ty extack) ret
  else
    ret

def BinaryExtraReportedAccepted
    (payloadLen validation minValue maxValue validate attr policy ty extack : UInt64) :
    Prop :=
  BinaryExtraAccepted payloadLen validation minValue maxValue validate ∧
    (validation == policyValidateRangeWarnTooLong && payloadLen > maxValue →
      reportValidateError
        (if hasFlag validate validateStrictAttrs then
          diagBinaryWarnTooLong
        else
          diagBinaryWarnTooLongAccepted)
        attr policy ty extack != u64Max)

def BinaryExtraReportedSpec
    (payloadLen validation minValue maxValue validate attr policy ty extack :
      UInt64) :
    Prop :=
  BinaryExtraSpec payloadLen validation minValue maxValue validate ∧
    (validation = policyValidateRangeWarnTooLong ∧ payloadLen > maxValue →
      reportValidateError
        (if hasFlag validate validateStrictAttrs then
          diagBinaryWarnTooLong
        else
          diagBinaryWarnTooLongAccepted)
        attr policy ty extack != u64Max)

theorem binaryExtraReportedSpec_iff_accepted
    (payloadLen validation minValue maxValue validate attr policy ty extack :
      UInt64) :
    BinaryExtraReportedSpec payloadLen validation minValue maxValue validate
        attr policy ty extack ↔
      BinaryExtraReportedAccepted payloadLen validation minValue maxValue
        validate attr policy ty extack := by
  unfold BinaryExtraReportedSpec BinaryExtraReportedAccepted
  constructor
  · intro hSpec
    rcases hSpec with ⟨hBinary, hReport⟩
    constructor
    · exact
        (binaryExtraSpec_iff_accepted payloadLen validation minValue maxValue
          validate).mp hBinary
    · intro hPrem
      by_cases hWarn : validation = policyValidateRangeWarnTooLong
      · by_cases hToo : payloadLen > maxValue
        · exact hReport ⟨hWarn, hToo⟩
        · simp [hToo] at hPrem
      · simp [hWarn] at hPrem
  · intro hAccepted
    rcases hAccepted with ⟨hBinary, hReport⟩
    constructor
    · exact
        (binaryExtraSpec_iff_accepted payloadLen validation minValue maxValue
          validate).mpr hBinary
    · intro hPrem
      rcases hPrem with ⟨hWarn, hToo⟩
      have hBoolPrem :
          validation == policyValidateRangeWarnTooLong &&
            payloadLen > maxValue := by
        simp [hWarn, hToo]
      exact hReport hBoolPrem

@[always_inline]
def reportExtraResult
    (ret validation valueKind attr policy ty extack : UInt64) : UInt64 :=
  if ret == ok then
    ok
  else if ret == erange then
    let reason := if valueKind == valueBinaryLen then diagBinaryRange else diagIntegerRange
    keepReported (reportValidateError reason attr policy ty extack) ret
  else if ret == einval && validation == policyValidateMask then
    keepReported (reportValidateError diagReservedBit attr policy ty extack) ret
  else if ret == einval && validation == policyValidateRangeWarnTooLong &&
      valueKind == valueBinaryLen then
    ret
  else
    keepReported (reportValidateError diagFailedPolicy attr policy ty extack) ret

@[always_inline]
def validateSignedExtra
    (validation value minValue maxValue : UInt64) : UInt64 :=
  if validation == policyValidateRange || validation == policyValidateRangePtr then
    if slt64 value minValue || slt64 maxValue value then erange else ok
  else if validation == policyValidateMin then
    if slt64 value minValue then erange else ok
  else if validation == policyValidateMax then
    if slt64 maxValue value then erange else ok
  else if validation == policyValidateNone then
    ok
  else
    unsupported

def SignedExtraAccepted
    (validation value minValue maxValue : UInt64) : Prop :=
  if validation == policyValidateRange || validation == policyValidateRangePtr then
    (slt64 value minValue) = false ∧ (slt64 maxValue value) = false
  else if validation == policyValidateMin then
    (slt64 value minValue) = false
  else if validation == policyValidateMax then
    (slt64 maxValue value) = false
  else if validation == policyValidateNone then
    True
  else
    False

def SignedExtraSpec
    (validation value minValue maxValue : UInt64) : Prop :=
  ((validation = policyValidateRange ∨ validation = policyValidateRangePtr) ∧
    slt64 value minValue = false ∧ slt64 maxValue value = false) ∨
  (validation = policyValidateMin ∧ slt64 value minValue = false) ∨
  (validation = policyValidateMax ∧ slt64 maxValue value = false) ∨
  validation = policyValidateNone

theorem signedExtraSpec_sound
    (validation value minValue maxValue : UInt64) :
    SignedExtraSpec validation value minValue maxValue →
      SignedExtraAccepted validation value minValue maxValue := by
  intro hSpec
  unfold SignedExtraSpec at hSpec
  rcases hSpec with ⟨hRange, hMin, hMax⟩
    | ⟨hValidationMin, hMin⟩
    | ⟨hValidationMax, hMax⟩
    | hValidationNone
  · rcases hRange with hValidationRange | hValidationPtr
    · simp [SignedExtraAccepted, hValidationRange, hMin, hMax]
    · simp [SignedExtraAccepted, hValidationPtr, hMin, hMax,
        policyValidateRange, policyValidateRangePtr]
  · simp [SignedExtraAccepted, hValidationMin, hMin, policyValidateRange,
      policyValidateRangePtr, policyValidateMin]
  · simp [SignedExtraAccepted, hValidationMax, hMax, policyValidateRange,
      policyValidateRangePtr, policyValidateMin, policyValidateMax]
  · simp [SignedExtraAccepted, hValidationNone, policyValidateRange,
      policyValidateRangePtr, policyValidateMin, policyValidateMax,
      policyValidateNone]

theorem signedExtraAccepted_complete
    (validation value minValue maxValue : UInt64) :
    SignedExtraAccepted validation value minValue maxValue →
      SignedExtraSpec validation value minValue maxValue := by
  intro hAccepted
  unfold SignedExtraSpec
  by_cases hRange : validation = policyValidateRange
  · left
    have hBounds :
        slt64 value minValue = false ∧
          slt64 maxValue value = false := by
      simpa [SignedExtraAccepted, hRange] using hAccepted
    exact ⟨Or.inl hRange, hBounds.1, hBounds.2⟩
  · by_cases hPtr : validation = policyValidateRangePtr
    · left
      have hBounds :
          slt64 value minValue = false ∧
            slt64 maxValue value = false := by
        simpa [SignedExtraAccepted, hRange, hPtr, policyValidateRange,
          policyValidateRangePtr] using hAccepted
      exact ⟨Or.inr hPtr, hBounds.1, hBounds.2⟩
    · right
      by_cases hMinVal : validation = policyValidateMin
      · left
        have hMin : slt64 value minValue = false := by
          simpa [SignedExtraAccepted, hRange, hPtr, hMinVal,
            policyValidateRange, policyValidateRangePtr, policyValidateMin]
            using hAccepted
        exact ⟨hMinVal, hMin⟩
      · right
        by_cases hMaxVal : validation = policyValidateMax
        · left
          have hMax : slt64 maxValue value = false := by
            simpa [SignedExtraAccepted, hRange, hPtr, hMinVal, hMaxVal,
              policyValidateRange, policyValidateRangePtr, policyValidateMin,
              policyValidateMax] using hAccepted
          exact ⟨hMaxVal, hMax⟩
        · right
          by_cases hNone : validation = policyValidateNone
          · exact hNone
          · have hFalse : False := by
              simp [SignedExtraAccepted, hRange, hPtr, hMinVal, hMaxVal,
                hNone] at hAccepted
            exact False.elim hFalse

theorem signedExtraSpec_iff_accepted
    (validation value minValue maxValue : UInt64) :
    SignedExtraSpec validation value minValue maxValue ↔
      SignedExtraAccepted validation value minValue maxValue :=
  ⟨signedExtraSpec_sound validation value minValue maxValue,
    signedExtraAccepted_complete validation value minValue maxValue⟩

@[always_inline]
def reportPayloadShapeResult
    (ret kind attr policy ty extack : UInt64) : UInt64 :=
  if ret == ok then
    ok
  else
    let reason :=
      if kind == kindReject then
        diagReject
      else if kind == kindUnsupported then
        diagFailedPolicy
      else if kind == kindInt32Or64 then
        diagInvalidAttrLen
      else
        diagFailedPolicy
    keepReported (reportValidateError reason attr policy ty extack) ret

@[always_inline]
def reportTrailingResult (validate extack : UInt64) : UInt64 :=
  keepReported (reportValidateError diagTrailingBytes 0 0 0 extack)
    (if hasFlag validate validateTrailing then einval else ok)

@[always_inline]
def viewValidatePolicyExtra
    (view : AttrView) (off policy ty row payloadLen validate attr extack : UInt64) :
    UInt64 :=
  if policy == 0 then
    ok
  else
    let validation := policyMetaValidation row
    if validation == policyValidateNone then
      ok
    else
      let policyRow := PolicyRowView.ofRaw policy ty
      if validation == policyValidateFunction then
        policyValidateFnFromRow policyRow policy ty attr extack
      else
      let valueKind := policyMetaValueKind row
      let width := valueReadWidth valueKind
      if width != 0 && payloadLen < width then
        keepReported (reportValidateError diagFailedPolicy attr policy ty extack)
          unsupported
      else if valueKind == valueBinaryLen then
        let minValue := policyRow.normalMin validation
        let maxValue := policyRow.normalMax validation
        reportExtraResult
          (validateBinaryExtraReported payloadLen validation
            minValue maxValue
            validate attr policy ty extack)
          validation valueKind attr policy ty extack
      else if validation == policyValidateMask then
        if isMaskableValueKind valueKind then
          let mask := policyRow.mask
          reportExtraResult
            (validateUnsignedExtra validation
              (viewReadUnsignedValue view off payloadLen valueKind)
              0 0 mask)
            validation valueKind attr policy ty extack
        else
          keepReported (reportValidateError diagFailedPolicy attr policy ty extack)
            unsupported
      else if isUnsignedValueKind valueKind then
        let minValue := policyRow.normalMin validation
        let maxValue := policyRow.normalMax validation
        let mask := policyRow.mask
        reportExtraResult
          (validateUnsignedExtra validation
            (viewReadUnsignedValue view off payloadLen valueKind)
            minValue maxValue mask)
          validation valueKind attr policy ty extack
      else if isSignedValueKind valueKind then
        let minValue := policyRow.normalMin validation
        let maxValue := policyRow.normalMax validation
        reportExtraResult
          (validateSignedExtra validation
            (viewReadSignedValue view off payloadLen valueKind)
            minValue maxValue)
          validation valueKind attr policy ty extack
      else
        keepReported (reportValidateError diagFailedPolicy attr policy ty extack)
          unsupported

def PolicyExtraAccepted
    (view : AttrView) (off policy ty row payloadLen validate attr extack :
      UInt64) : Prop :=
  if policy == 0 then
    True
  else
    let validation := policyMetaValidation row
    if validation == policyValidateNone then
      True
    else
      let policyRow := PolicyRowView.ofRaw policy ty
      if validation == policyValidateFunction then
        policyValidateFnFromRow policyRow policy ty attr extack = ok
      else
        let valueKind := policyMetaValueKind row
        let width := valueReadWidth valueKind
        if width != 0 && payloadLen < width then
          False
        else if valueKind == valueBinaryLen then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          BinaryExtraReportedAccepted payloadLen validation minValue maxValue
            validate attr policy ty extack
        else if validation == policyValidateMask then
          if isMaskableValueKind valueKind then
            UnsignedExtraAccepted validation
              (viewReadUnsignedValue view off payloadLen valueKind)
              0 0 policyRow.mask
          else
            False
        else if isUnsignedValueKind valueKind then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          UnsignedExtraAccepted validation
            (viewReadUnsignedValue view off payloadLen valueKind)
            minValue maxValue policyRow.mask
        else if isSignedValueKind valueKind then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          SignedExtraAccepted validation
            (viewReadSignedValue view off payloadLen valueKind)
            minValue maxValue
        else
          False

def PolicyExtraSpec
    (view : AttrView) (off policy ty row payloadLen validate attr extack :
      UInt64) : Prop :=
  if policy == 0 then
    True
  else
    let validation := policyMetaValidation row
    if validation == policyValidateNone then
      True
    else
      let policyRow := PolicyRowView.ofRaw policy ty
      if validation == policyValidateFunction then
        policyValidateFnFromRow policyRow policy ty attr extack = ok
      else
        let valueKind := policyMetaValueKind row
        let width := valueReadWidth valueKind
        if width != 0 && payloadLen < width then
          False
        else if valueKind == valueBinaryLen then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          BinaryExtraReportedSpec payloadLen validation minValue maxValue
            validate attr policy ty extack
        else if validation == policyValidateMask then
          if isMaskableValueKind valueKind then
            UnsignedExtraSpec validation
              (viewReadUnsignedValue view off payloadLen valueKind)
              0 0 policyRow.mask
          else
            False
        else if isUnsignedValueKind valueKind then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          UnsignedExtraSpec validation
            (viewReadUnsignedValue view off payloadLen valueKind)
            minValue maxValue policyRow.mask
        else if isSignedValueKind valueKind then
          let minValue := policyRow.normalMin validation
          let maxValue := policyRow.normalMax validation
          SignedExtraSpec validation
            (viewReadSignedValue view off payloadLen valueKind)
            minValue maxValue
        else
          False

theorem policyExtraSpec_iff_accepted
    (view : AttrView) (off policy ty row payloadLen validate attr extack :
      UInt64) :
    PolicyExtraSpec view off policy ty row payloadLen validate attr extack ↔
      PolicyExtraAccepted view off policy ty row payloadLen validate attr
        extack := by
  unfold PolicyExtraSpec PolicyExtraAccepted
  by_cases hPolicy : policy == 0
  · simp [hPolicy]
  · by_cases hValidationNone : policyMetaValidation row == policyValidateNone
    · simp [hPolicy, hValidationNone]
    · by_cases hValidationFunction :
        policyMetaValidation row == policyValidateFunction
      · simp [hPolicy, hValidationNone, hValidationFunction]
      · by_cases hWidth :
          valueReadWidth (policyMetaValueKind row) != 0 &&
            payloadLen < valueReadWidth (policyMetaValueKind row)
        · simp [hPolicy, hValidationNone, hValidationFunction, hWidth]
        · by_cases hBinary : policyMetaValueKind row == valueBinaryLen
          · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
              hBinary, binaryExtraReportedSpec_iff_accepted]
          · by_cases hMask : policyMetaValidation row == policyValidateMask
            · by_cases hMaskable :
                isMaskableValueKind (policyMetaValueKind row)
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hMaskable, unsignedExtraSpec_iff_accepted]
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hMaskable]
            · by_cases hUnsigned :
                isUnsignedValueKind (policyMetaValueKind row)
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hUnsigned, unsignedExtraSpec_iff_accepted]
              · by_cases hSigned :
                  isSignedValueKind (policyMetaValueKind row)
                · simp [hPolicy, hValidationNone, hValidationFunction,
                    hWidth, hBinary, hMask, hUnsigned, hSigned,
                    signedExtraSpec_iff_accepted]
                · simp [hPolicy, hValidationNone, hValidationFunction,
                    hWidth, hBinary, hMask, hUnsigned, hSigned]

@[always_inline]
def viewValidatePayloadShape
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) : UInt64 :=
  if kind == kindAccept then
    ok
  else if kind == kindFlag then
    if payloadLen == 0 then ok else erange
  else if kind == kindExact then
    if payloadLen == policyMetaMinLen row then ok else erange
  else if kind == kindMin then
    if payloadLen >= policyMetaMinLen row then ok else erange
  else if kind == kindRange then
    if payloadLen >= policyMetaMinLen row && payloadLen <= policyMetaMaxLen row then ok else erange
  else if kind == kindReject then
    einval
  else if kind == kindString then
    viewValidateString view off (policyMetaMaxLen row) payloadLen
  else if kind == kindNulString then
    viewValidateNulString view off (policyMetaMaxLen row) payloadLen
  else if kind == kindBitfield32 then
    viewValidateBitfield32 view off policy ty payloadLen
  else if kind == kindInt32Or64 then
    if payloadLen == 4 || payloadLen == 8 then ok else einval
  else if kind == kindNested then
    if payloadLen == 0 || payloadLen >= nlaHeaderLen then ok else erange
  else
    unsupported

def PayloadShapeAccepted
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) : Prop :=
  if kind == kindAccept then
    True
  else if kind == kindFlag then
    payloadLen == 0
  else if kind == kindExact then
    payloadLen == policyMetaMinLen row
  else if kind == kindMin then
    payloadLen >= policyMetaMinLen row
  else if kind == kindRange then
    payloadLen >= policyMetaMinLen row && payloadLen <= policyMetaMaxLen row
  else if kind == kindReject then
    False
  else if kind == kindString then
    viewValidateString view off (policyMetaMaxLen row) payloadLen = ok
  else if kind == kindNulString then
    viewValidateNulString view off (policyMetaMaxLen row) payloadLen = ok
  else if kind == kindBitfield32 then
    viewValidateBitfield32 view off policy ty payloadLen = ok
  else if kind == kindInt32Or64 then
    payloadLen == 4 || payloadLen == 8
  else if kind == kindNested then
    payloadLen == 0 || payloadLen >= nlaHeaderLen
  else
    False

def PayloadShapeSpec
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) : Prop :=
  kind = kindAccept ∨
  (kind = kindFlag ∧ payloadLen = 0) ∨
  (kind = kindExact ∧ payloadLen = policyMetaMinLen row) ∨
  (kind = kindMin ∧ policyMetaMinLen row ≤ payloadLen) ∨
  (kind = kindRange ∧ policyMetaMinLen row ≤ payloadLen ∧
    payloadLen ≤ policyMetaMaxLen row) ∨
  (kind = kindString ∧
    viewValidateString view off (policyMetaMaxLen row) payloadLen = ok) ∨
  (kind = kindNulString ∧
    viewValidateNulString view off (policyMetaMaxLen row) payloadLen = ok) ∨
  (kind = kindBitfield32 ∧
    viewValidateBitfield32 view off policy ty payloadLen = ok) ∨
  (kind = kindInt32Or64 ∧ (payloadLen = 4 ∨ payloadLen = 8)) ∨
  (kind = kindNested ∧ (payloadLen = 0 ∨ nlaHeaderLen ≤ payloadLen))

theorem payloadShapeSpec_sound
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) :
    PayloadShapeSpec view off policy ty kind row payloadLen →
      PayloadShapeAccepted view off policy ty kind row payloadLen := by
  intro hSpec
  unfold PayloadShapeSpec at hSpec
  rcases hSpec with hAccept
    | ⟨hFlag, hLen⟩
    | ⟨hExact, hLen⟩
    | ⟨hMin, hLen⟩
    | ⟨hRange, hMinLen, hMaxLen⟩
    | ⟨hString, hOk⟩
    | ⟨hNul, hOk⟩
    | ⟨hBitfield, hOk⟩
    | ⟨hInt, hLen⟩
    | ⟨hNested, hLen⟩
  · simp [PayloadShapeAccepted, hAccept]
  · simp [PayloadShapeAccepted, hFlag, hLen, kindAccept, kindFlag]
  · simp [PayloadShapeAccepted, hExact, hLen, kindAccept, kindFlag,
      kindExact]
  · simp [PayloadShapeAccepted, hMin, hLen, kindAccept, kindFlag,
      kindExact, kindMin]
  · simp [PayloadShapeAccepted, hRange, hMinLen, hMaxLen, kindAccept,
      kindFlag, kindExact, kindMin, kindRange]
  · simp [PayloadShapeAccepted, hString, hOk, kindAccept, kindFlag,
      kindExact, kindMin, kindRange, kindReject, kindString]
  · simp [PayloadShapeAccepted, hNul, hOk, kindAccept, kindFlag,
      kindExact, kindMin, kindRange, kindReject, kindString,
      kindNulString]
  · simp [PayloadShapeAccepted, hBitfield, hOk, kindAccept, kindFlag,
      kindExact, kindMin, kindRange, kindReject, kindString,
      kindNulString, kindBitfield32]
  · rcases hLen with hLen | hLen <;>
      simp [PayloadShapeAccepted, hInt, hLen, kindAccept, kindFlag,
        kindExact, kindMin, kindRange, kindReject, kindString,
        kindNulString, kindBitfield32, kindInt32Or64]
  · rcases hLen with hLen | hLen <;>
      simp [PayloadShapeAccepted, hNested, hLen, kindAccept, kindFlag,
        kindExact, kindMin, kindRange, kindReject, kindString,
        kindNulString, kindBitfield32, kindInt32Or64, kindNested]

theorem payloadShapeAccepted_complete
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) :
    PayloadShapeAccepted view off policy ty kind row payloadLen →
      PayloadShapeSpec view off policy ty kind row payloadLen := by
  intro hAccepted
  unfold PayloadShapeSpec
  by_cases hAccept : kind = kindAccept
  · left
    exact hAccept
  · right
    by_cases hFlag : kind = kindFlag
    · left
      have hLen : payloadLen = 0 := by
        simpa [PayloadShapeAccepted, hAccept, hFlag, kindAccept, kindFlag]
          using hAccepted
      exact ⟨hFlag, hLen⟩
    · right
      by_cases hExact : kind = kindExact
      · left
        have hLen : payloadLen = policyMetaMinLen row := by
          simpa [PayloadShapeAccepted, hAccept, hFlag, hExact, kindAccept,
            kindFlag, kindExact] using hAccepted
        exact ⟨hExact, hLen⟩
      · right
        by_cases hMin : kind = kindMin
        · left
          have hLen : policyMetaMinLen row ≤ payloadLen := by
            simpa [PayloadShapeAccepted, hAccept, hFlag, hExact, hMin,
              kindAccept, kindFlag, kindExact, kindMin] using hAccepted
          exact ⟨hMin, hLen⟩
        · right
          by_cases hRange : kind = kindRange
          · left
            have hRangeLen :
                policyMetaMinLen row ≤ payloadLen ∧
                  payloadLen ≤ policyMetaMaxLen row := by
              simpa [PayloadShapeAccepted, hAccept, hFlag, hExact, hMin,
                hRange, kindAccept, kindFlag, kindExact, kindMin,
                kindRange] using hAccepted
            exact ⟨hRange, hRangeLen.1, hRangeLen.2⟩
          · right
            by_cases hReject : kind = kindReject
            · have hFalse : False := by
                simp [PayloadShapeAccepted, hReject, kindAccept, kindFlag,
                  kindExact, kindMin, kindRange, kindReject] at hAccepted
              exact False.elim hFalse
            · by_cases hString : kind = kindString
              · left
                have hOk :
                    viewValidateString view off (policyMetaMaxLen row)
                      payloadLen = ok := by
                  simpa [PayloadShapeAccepted, hAccept, hFlag, hExact, hMin,
                    hRange, hReject, hString, kindAccept, kindFlag,
                    kindExact, kindMin, kindRange, kindReject, kindString]
                    using hAccepted
                exact ⟨hString, hOk⟩
              · right
                by_cases hNul : kind = kindNulString
                · left
                  have hOk :
                      viewValidateNulString view off (policyMetaMaxLen row)
                        payloadLen = ok := by
                    simpa [PayloadShapeAccepted, hAccept, hFlag, hExact,
                      hMin, hRange, hReject, hString, hNul, kindAccept,
                      kindFlag, kindExact, kindMin, kindRange, kindReject,
                      kindString, kindNulString] using hAccepted
                  exact ⟨hNul, hOk⟩
                · right
                  by_cases hBitfield : kind = kindBitfield32
                  · left
                    have hOk :
                        viewValidateBitfield32 view off policy ty payloadLen =
                          ok := by
                      simpa [PayloadShapeAccepted, hAccept, hFlag, hExact,
                        hMin, hRange, hReject, hString, hNul, hBitfield,
                        kindAccept, kindFlag, kindExact, kindMin, kindRange,
                        kindReject, kindString, kindNulString, kindBitfield32]
                        using hAccepted
                    exact ⟨hBitfield, hOk⟩
                  · right
                    by_cases hInt : kind = kindInt32Or64
                    · left
                      have hLen : payloadLen = 4 ∨ payloadLen = 8 := by
                        simpa [PayloadShapeAccepted, hAccept, hFlag, hExact,
                          hMin, hRange, hReject, hString, hNul, hBitfield,
                          hInt, kindAccept, kindFlag, kindExact, kindMin,
                          kindRange, kindReject, kindString, kindNulString,
                          kindBitfield32, kindInt32Or64] using hAccepted
                      exact ⟨hInt, hLen⟩
                    · right
                      by_cases hNested : kind = kindNested
                      · have hLen :
                            payloadLen = 0 ∨ nlaHeaderLen ≤ payloadLen := by
                          simpa [PayloadShapeAccepted, hAccept, hFlag,
                            hExact, hMin, hRange, hReject, hString, hNul,
                            hBitfield, hInt, hNested, kindAccept, kindFlag,
                            kindExact, kindMin, kindRange, kindReject,
                            kindString, kindNulString, kindBitfield32,
                            kindInt32Or64, kindNested] using hAccepted
                        exact ⟨hNested, hLen⟩
                      · have hTail :
                            ¬ kind = kindAccept →
                              (if kind = kindFlag then payloadLen = 0
                              else if kind = kindExact then
                                payloadLen = policyMetaMinLen row
                              else if kind = kindMin then
                                policyMetaMinLen row ≤ payloadLen
                              else if kind = kindRange then
                                policyMetaMinLen row ≤ payloadLen ∧
                                  payloadLen ≤ policyMetaMaxLen row
                              else
                                ¬ kind = kindReject ∧
                                  if kind = kindString then
                                    viewValidateString view off
                                      (policyMetaMaxLen row) payloadLen = ok
                                  else if kind = kindNulString then
                                    viewValidateNulString view off
                                      (policyMetaMaxLen row) payloadLen = ok
                                  else if kind = kindBitfield32 then
                                    viewValidateBitfield32 view off policy ty
                                      payloadLen = ok
                                  else if kind = kindInt32Or64 then
                                    payloadLen = 4 ∨ payloadLen = 8
                                  else
                                    kind = kindNested ∧
                                      (payloadLen = 0 ∨
                                        nlaHeaderLen ≤ payloadLen)) := by
                          simpa [PayloadShapeAccepted, kindAccept, kindFlag,
                            kindExact, kindMin, kindRange, kindReject,
                            kindString, kindNulString, kindBitfield32,
                            kindInt32Or64, kindNested] using hAccepted
                        have hAfterAccept := hTail hAccept
                        have hFalse : False := by
                          simp [hFlag, hExact, hMin, hRange, hReject,
                            hString, hNul, hBitfield, hInt, hNested] at hAfterAccept
                        exact False.elim hFalse

theorem payloadShapeSpec_iff_accepted
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) :
    PayloadShapeSpec view off policy ty kind row payloadLen ↔
      PayloadShapeAccepted view off policy ty kind row payloadLen :=
  ⟨payloadShapeSpec_sound view off policy ty kind row payloadLen,
    payloadShapeAccepted_complete view off policy ty kind row payloadLen⟩

@[always_inline]
def viewValidatePayload
    (view : AttrView) (off policy ty kind row payloadLen validate extack : UInt64) :
    UInt64 :=
  let attr := view.ptr off
  let ret :=
    reportPayloadShapeResult
      (viewValidatePayloadShape view off policy ty kind row payloadLen)
      kind attr policy ty extack
  if ret != ok then
    ret
  else if policy == 0 || policyMetaValidation row == policyValidateNone then
    ok
  else
    viewValidatePolicyExtra view off policy ty row payloadLen validate attr extack

def PayloadAccepted
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    Prop :=
  PayloadShapeAccepted view off policy ty kind row payloadLen ∧
    if policy == 0 || policyMetaValidation row == policyValidateNone then
      True
    else
      PolicyExtraAccepted view off policy ty row payloadLen validate
        (view.ptr off) extack

def PayloadSpec
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    Prop :=
  PayloadShapeSpec view off policy ty kind row payloadLen ∧
    (policy = 0 ∨ policyMetaValidation row = policyValidateNone ∨
      PolicyExtraAccepted view off policy ty row payloadLen validate
        (view.ptr off) extack)

def PayloadPolicySpec
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    Prop :=
  PayloadShapeSpec view off policy ty kind row payloadLen ∧
    PolicyExtraSpec view off policy ty row payloadLen validate
      (view.ptr off) extack

theorem payloadSpec_iff_accepted
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    PayloadSpec view off policy ty kind row payloadLen validate extack ↔
      PayloadAccepted view off policy ty kind row payloadLen validate extack := by
  unfold PayloadSpec PayloadAccepted
  constructor
  · intro hSpec
    rcases hSpec with ⟨hShape, hExtraSpec⟩
    constructor
    · exact
        (payloadShapeSpec_iff_accepted view off policy ty kind row
          payloadLen).mp hShape
    · by_cases hPolicy : policy = 0
      · simp [hPolicy]
      · by_cases hValidation : policyMetaValidation row = policyValidateNone
        · simp [hValidation]
        · rcases hExtraSpec with hPolicySpec | hValidationSpec | hExtra
          · exact False.elim (hPolicy hPolicySpec)
          · exact False.elim (hValidation hValidationSpec)
          · simpa [hPolicy, hValidation] using hExtra
  · intro hAccepted
    rcases hAccepted with ⟨hShape, hExtraAccepted⟩
    constructor
    · exact
        (payloadShapeSpec_iff_accepted view off policy ty kind row
          payloadLen).mpr hShape
    · by_cases hPolicy : policy = 0
      · exact Or.inl hPolicy
      · by_cases hValidation : policyMetaValidation row = policyValidateNone
        · exact Or.inr (Or.inl hValidation)
        · exact Or.inr (Or.inr (by
            simpa [hPolicy, hValidation] using hExtraAccepted))

theorem payloadPolicySpec_iff_payloadSpec
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    PayloadPolicySpec view off policy ty kind row payloadLen validate extack ↔
      PayloadSpec view off policy ty kind row payloadLen validate extack := by
  unfold PayloadPolicySpec PayloadSpec
  constructor
  · intro hSpec
    rcases hSpec with ⟨hShape, hExtraSpec⟩
    constructor
    · exact hShape
    · by_cases hPolicy : policy = 0
      · exact Or.inl hPolicy
      · by_cases hValidation : policyMetaValidation row = policyValidateNone
        · exact Or.inr (Or.inl hValidation)
        · exact Or.inr (Or.inr
            ((policyExtraSpec_iff_accepted view off policy ty row payloadLen
              validate (view.ptr off) extack).mp hExtraSpec))
  · intro hSpec
    rcases hSpec with ⟨hShape, hExtraSpec⟩
    constructor
    · exact hShape
    · rcases hExtraSpec with hPolicy | hValidation | hAccepted
      · simp [PolicyExtraSpec, hPolicy]
      · simp [PolicyExtraSpec, hValidation]
      · exact
          (policyExtraSpec_iff_accepted view off policy ty row payloadLen
            validate (view.ptr off) extack).mpr hAccepted

theorem payloadPolicySpec_iff_accepted
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    PayloadPolicySpec view off policy ty kind row payloadLen validate extack ↔
      PayloadAccepted view off policy ty kind row payloadLen validate
        extack :=
  (payloadPolicySpec_iff_payloadSpec view off policy ty kind row payloadLen
    validate extack).trans
    (payloadSpec_iff_accepted view off policy ty kind row payloadLen validate
      extack)

def TableWriteAccepted (tb ty attr : UInt64) : Prop :=
  if tb == 0 then True else setTb tb ty attr = ok

def tableWriteStatus (tb ty attr : UInt64) : UInt64 :=
  let write := if tb == 0 then ok else setTb tb ty attr
  if write != ok then unsupported else ok

@[always_inline]
def knownAttrWriteStatus (tb ty maxtype attr : UInt64) : UInt64 :=
  tableWriteStatus tb (arrayIndexNospec ty (maxtype + 1)) attr

def KnownAttrWriteAccepted (tb ty maxtype attr : UInt64) : Prop :=
  TableWriteAccepted tb (arrayIndexNospec ty (maxtype + 1)) attr

mutual

def viewValidateLoop
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    UInt64 :=
  if hfuel : fuel == 0 then
    unsupported
  else
    if depth >= maxPolicyRecursionDepth then
      keepReported (reportValidateError diagRecursionDepth 0 0 0 extack) einval
    else if off == totalLen then
      ok
    else if off + nlaHeaderLen > totalLen then
      reportTrailingResult validate extack
    else
      let header := view.header off
      let len := attrHeaderLen header
      let ty := attrHeaderType header
      let nested := attrHeaderIsNested header
      if len < nlaHeaderLen then
        reportTrailingResult validate extack
      else if off + len > totalLen then
        reportTrailingResult validate extack
      else
        let next := off + align4 len
        if ty == 0 || ty > maxtype then
          if hasFlag validate validateMaxType then
            keepReported
              (reportValidateError diagUnknownAttr (view.ptr off) 0 0 extack)
              einval
          else if next > totalLen then
            ok
          else
            viewValidateLoop view totalLen maxtype policy strictStart validate
              extack depth tb policyTable (fuel - 1) next
        else
          let policyTy := arrayIndexNospec ty (maxtype + 1)
          let policyRow := policyTable.row policyTy
          let row :=
            if policy == 0 then policyMetaAccept
            else policyMetaFromRow policy policyTy policyRow
          let kind := policyMetaKind row
          let effectiveValidate := withStrictStart strictStart ty validate
          let hasPolicy := policy != 0
          let checkUnspec := hasFlag effectiveValidate validateUnspec
          let checkNested := hasFlag effectiveValidate validateNested
          let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
          let kindIsNested := isNestedKind kind
          let attr := view.ptr off
          let rowValidation := policyMetaValidation row
          let payloadLen := len - nlaHeaderLen
          let needUnspec :=
            hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
          let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
          let verdict :=
            if hasPolicy && checkUnspec && isUnspec != 0 then
              keepReported
                (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
                einval
            else if hasPolicy && checkNested && kindIsNested && nested == 0 then
              keepReported
                (reportValidateError diagNestedMissing attr policy policyTy extack)
                einval
            else if hasPolicy && checkNested &&
                !kindIsNested && isUnspec == 0 && nested != 0 then
              keepReported
                (reportValidateError diagNestedUnexpected attr policy policyTy extack)
                einval
            else
              let strictLen := policyMetaStrictLen row
              if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
                keepReported
                  (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
                  einval
              else if kind == kindNestedPolicy then
                let ret :=
                  if payloadLen == 0 then
                    ok
                  else if payloadLen < nlaHeaderLen then
                    erange
                  else
                    let nestedPolicy := policyRow.unionPtr
                    let nestedMaxtype := policyRow.len
                    let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                    let nestedView := view.payloadView off payloadLen
                    viewValidateLoop nestedView payloadLen
                      nestedMaxtype nestedPolicy
                      (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                      effectiveValidate extack (depth + 1) 0 nestedTable (fuel - 1) 0
                if ret == ok then
                  if rowValidation == policyValidateNone then
                    ok
                  else
                    viewValidatePolicyExtra view off policy policyTy row payloadLen
                      effectiveValidate attr extack
                else
                  ret
              else if kind == kindNestedArrayPolicy then
                let ret :=
                  if payloadLen == 0 then
                    ok
                  else if payloadLen < nlaHeaderLen then
                    erange
                  else
                    let nestedPolicy := policyRow.unionPtr
                    let nestedMaxtype := policyRow.len
                    let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                    let nestedView := view.payloadView off payloadLen
                    viewValidateNestedArrayLoop nestedView payloadLen
                      nestedMaxtype nestedPolicy
                      effectiveValidate extack depth nestedTable (fuel - 1) 0
                if ret == ok then
                  if rowValidation == policyValidateNone then
                    ok
                  else
                    viewValidatePolicyExtra view off policy policyTy row payloadLen
                      effectiveValidate attr extack
                else
                  ret
              else
                viewValidatePayload view off policy policyTy kind row payloadLen
                  effectiveValidate extack
          if verdict != ok then
            verdict
          else
            let writeStatus := knownAttrWriteStatus tb ty maxtype attr
            if writeStatus != ok then
              writeStatus
            else if next > totalLen then ok else
              viewValidateLoop view totalLen maxtype policy strictStart validate
                extack depth tb policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    simpa using u64PredToNatLtOfBoolNeZero _ hfuel

def viewValidateNestedArrayLoop
    (view : AttrView)
    (totalLen maxtype policy validate extack depth : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    UInt64 :=
  if hfuel : fuel == 0 then
    unsupported
  else
    if off == totalLen then
      ok
    else
    if off + nlaHeaderLen > totalLen then
      ok
    else
      let len := attrHeaderLen (view.header off)
      if len < nlaHeaderLen then
        ok
      else if off + len > totalLen then
        ok
      else
        let payloadLen := len - nlaHeaderLen
        let verdict :=
          if payloadLen == 0 then
            ok
          else if payloadLen < nlaHeaderLen then
            erange
          else
            let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
            let nestedView := view.payloadView off payloadLen
            viewValidateLoop nestedView payloadLen maxtype policy
              nestedStrictStart validate extack (depth + 1) 0 policyTable (fuel - 1) 0
        if verdict != ok then
          verdict
        else
          let next := off + align4 len
          if next > totalLen then ok else
            viewValidateNestedArrayLoop view totalLen maxtype policy validate
              extack depth policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    simpa using u64PredToNatLtOfBoolNeZero _ hfuel

end

mutual

def ValidateLoopAccepted
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    Prop :=
  if hfuel : fuel == 0 then
    False
  else if depth >= maxPolicyRecursionDepth then
    False
  else if off == totalLen then
    True
  else if off + nlaHeaderLen > totalLen then
    reportTrailingResult validate extack = ok
  else
    let header := view.header off
    let len := attrHeaderLen header
    let ty := attrHeaderType header
    let nested := attrHeaderIsNested header
    if len < nlaHeaderLen then
      reportTrailingResult validate extack = ok
    else if off + len > totalLen then
      reportTrailingResult validate extack = ok
    else
      let next := off + align4 len
      if ty == 0 || ty > maxtype then
        if hasFlag validate validateMaxType then
          False
        else if next > totalLen then
          True
        else
          ValidateLoopAccepted view totalLen maxtype policy strictStart validate
            extack depth tb policyTable (fuel - 1) next
      else
        let policyTy := arrayIndexNospec ty (maxtype + 1)
        let policyRow := policyTable.row policyTy
        let row :=
          if policy == 0 then policyMetaAccept
          else policyMetaFromRow policy policyTy policyRow
        let kind := policyMetaKind row
        let effectiveValidate := withStrictStart strictStart ty validate
        let hasPolicy := policy != 0
        let checkUnspec := hasFlag effectiveValidate validateUnspec
        let checkNested := hasFlag effectiveValidate validateNested
        let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
        let kindIsNested := isNestedKind kind
        let attr := view.ptr off
        let rowValidation := policyMetaValidation row
        let payloadLen := len - nlaHeaderLen
        let needUnspec :=
          hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
        let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
        let verdictAccepted :=
          if hasPolicy && checkUnspec && isUnspec != 0 then
            False
          else if hasPolicy && checkNested && kindIsNested && nested == 0 then
            False
          else if hasPolicy && checkNested &&
              !kindIsNested && isUnspec == 0 && nested != 0 then
            False
          else
            let strictLen := policyMetaStrictLen row
            if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
              False
            else if kind == kindNestedPolicy then
              let nestedAccepted :=
                if payloadLen == 0 then
                  True
                else if payloadLen < nlaHeaderLen then
                  False
                else
                  let nestedPolicy := policyRow.unionPtr
                  let nestedMaxtype := policyRow.len
                  let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                  let nestedView := view.payloadView off payloadLen
                  ValidateLoopAccepted nestedView payloadLen
                    nestedMaxtype nestedPolicy
                    (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                    effectiveValidate extack (depth + 1) 0 nestedTable
                    (fuel - 1) 0
              nestedAccepted ∧
                if rowValidation == policyValidateNone then
                  True
                else
                  PolicyExtraAccepted view off policy policyTy row payloadLen
                    effectiveValidate attr extack
            else if kind == kindNestedArrayPolicy then
              let nestedAccepted :=
                if payloadLen == 0 then
                  True
                else if payloadLen < nlaHeaderLen then
                  False
                else
                  let nestedPolicy := policyRow.unionPtr
                  let nestedMaxtype := policyRow.len
                  let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                  let nestedView := view.payloadView off payloadLen
                  ValidateNestedArrayAccepted nestedView payloadLen
                    nestedMaxtype nestedPolicy effectiveValidate extack depth
                    nestedTable (fuel - 1) 0
              nestedAccepted ∧
                if rowValidation == policyValidateNone then
                  True
                else
                  PolicyExtraAccepted view off policy policyTy row payloadLen
                    effectiveValidate attr extack
            else
              PayloadAccepted view off policy policyTy kind row payloadLen
                effectiveValidate extack
        verdictAccepted ∧
          KnownAttrWriteAccepted tb ty maxtype attr ∧
          if next > totalLen then
            True
          else
            ValidateLoopAccepted view totalLen maxtype policy strictStart validate
              extack depth tb policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    exact u64PredToNatLtOfBoolNeZero _ hfuel

def ValidateNestedArrayAccepted
    (view : AttrView)
    (totalLen maxtype policy validate extack depth : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    Prop :=
  if hfuel : fuel == 0 then
    False
  else if off == totalLen then
    True
  else if off + nlaHeaderLen > totalLen then
    True
  else
    let len := attrHeaderLen (view.header off)
    if len < nlaHeaderLen then
      True
    else if off + len > totalLen then
      True
    else
      let payloadLen := len - nlaHeaderLen
      let verdictAccepted :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0
      verdictAccepted ∧
        let next := off + align4 len
        if next > totalLen then
          True
        else
          ValidateNestedArrayAccepted view totalLen maxtype policy validate
            extack depth policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    exact u64PredToNatLtOfBoolNeZero _ hfuel

end

mutual

def ValidateLoopSpec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    Prop :=
  if hfuel : fuel == 0 then
    False
  else if depth >= maxPolicyRecursionDepth then
    False
  else if off == totalLen then
    True
  else if off + nlaHeaderLen > totalLen then
    reportTrailingResult validate extack = ok
  else
    let header := view.header off
    let len := attrHeaderLen header
    let ty := attrHeaderType header
    let nested := attrHeaderIsNested header
    if len < nlaHeaderLen then
      reportTrailingResult validate extack = ok
    else if off + len > totalLen then
      reportTrailingResult validate extack = ok
    else
      let next := off + align4 len
      if ty == 0 || ty > maxtype then
        if hasFlag validate validateMaxType then
          False
        else if next > totalLen then
          True
        else
          ValidateLoopSpec view totalLen maxtype policy strictStart validate
            extack depth tb policyTable (fuel - 1) next
      else
        let policyTy := arrayIndexNospec ty (maxtype + 1)
        let policyRow := policyTable.row policyTy
        let row :=
          if policy == 0 then policyMetaAccept
          else policyMetaFromRow policy policyTy policyRow
        let kind := policyMetaKind row
        let effectiveValidate := withStrictStart strictStart ty validate
        let hasPolicy := policy != 0
        let checkUnspec := hasFlag effectiveValidate validateUnspec
        let checkNested := hasFlag effectiveValidate validateNested
        let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
        let kindIsNested := isNestedKind kind
        let attr := view.ptr off
        let rowValidation := policyMetaValidation row
        let payloadLen := len - nlaHeaderLen
        let needUnspec :=
          hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
        let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
        let verdictSpec :=
          if hasPolicy && checkUnspec && isUnspec != 0 then
            False
          else if hasPolicy && checkNested && kindIsNested && nested == 0 then
            False
          else if hasPolicy && checkNested &&
              !kindIsNested && isUnspec == 0 && nested != 0 then
            False
          else
            let strictLen := policyMetaStrictLen row
            if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
              False
            else if kind == kindNestedPolicy then
              let nestedSpec :=
                if payloadLen == 0 then
                  True
                else if payloadLen < nlaHeaderLen then
                  False
                else
                  let nestedPolicy := policyRow.unionPtr
                  let nestedMaxtype := policyRow.len
                  let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                  let nestedView := view.payloadView off payloadLen
                  ValidateLoopSpec nestedView payloadLen
                    nestedMaxtype nestedPolicy
                    (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                    effectiveValidate extack (depth + 1) 0 nestedTable
                    (fuel - 1) 0
              nestedSpec ∧
                if rowValidation == policyValidateNone then
                  True
                else
                  PolicyExtraSpec view off policy policyTy row payloadLen
                    effectiveValidate attr extack
            else if kind == kindNestedArrayPolicy then
              let nestedSpec :=
                if payloadLen == 0 then
                  True
                else if payloadLen < nlaHeaderLen then
                  False
                else
                  let nestedPolicy := policyRow.unionPtr
                  let nestedMaxtype := policyRow.len
                  let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                  let nestedView := view.payloadView off payloadLen
                  ValidateNestedArraySpec nestedView payloadLen
                    nestedMaxtype nestedPolicy effectiveValidate extack depth
                    nestedTable (fuel - 1) 0
              nestedSpec ∧
                if rowValidation == policyValidateNone then
                  True
                else
                  PolicyExtraSpec view off policy policyTy row payloadLen
                    effectiveValidate attr extack
            else
              PayloadPolicySpec view off policy policyTy kind row payloadLen
                effectiveValidate extack
        verdictSpec ∧
          KnownAttrWriteAccepted tb ty maxtype attr ∧
          if next > totalLen then
            True
          else
            ValidateLoopSpec view totalLen maxtype policy strictStart validate
              extack depth tb policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    exact u64PredToNatLtOfBoolNeZero fuel hfuel

def ValidateNestedArraySpec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    Prop :=
  if hfuel : fuel == 0 then
    False
  else if off == totalLen then
    True
  else if off + nlaHeaderLen > totalLen then
    True
  else
    let len := attrHeaderLen (view.header off)
    if len < nlaHeaderLen then
      True
    else if off + len > totalLen then
      True
    else
      let payloadLen := len - nlaHeaderLen
      let verdictSpec :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0
      verdictSpec ∧
        let next := off + align4 len
        if next > totalLen then
          True
        else
          ValidateNestedArraySpec view totalLen maxtype policy validate
            extack depth policyTable (fuel - 1) next
termination_by fuel.toNat
decreasing_by
  all_goals
    exact u64PredToNatLtOfBoolNeZero fuel hfuel

end

def cmpEncodeDiff (a b : UInt64) : UInt64 :=
  if a == b then
    0
  else if a > b then
    let diff := a - b
    if diff <= intMax then diff else cmpUnsupported
  else
    let diff := b - a
    if diff <= intMax then cmpNegative ||| diff else cmpUnsupported

def packedTrimLen (chunk len fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    0
  else if len == 0 then
    0
  else if packedByte chunk (len - 1) == 0 then
    packedTrimLen chunk (len - 1) (fuel - 1)
  else
    len
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def viewTrimTrailingZeros (view : AttrView) (len fuel : UInt64) : UInt64 :=
  if _hfuel : fuel == 0 then
    len
  else if len == 0 then
    0
  else
    let count := min64 8 len
    let ix := len - count
    let chunkLen := packedTrimLen (viewAttrWord view 0 ix count) count (count + 1)
    if chunkLen == 0 then
      viewTrimTrailingZeros view ix (fuel - 1)
    else
      ix + chunkLen
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel _hfuel

def viewTrimOneTrailingZero (view : AttrView) (payloadLen : UInt64) : UInt64 :=
  if payloadLen > 0 &&
      packedByte (viewAttrWord view 0 (payloadLen - 1) 1) 0 == 0 then
    payloadLen - 1
  else
    payloadLen

def policyLenLoop (policy count ix acc fuel : UInt64) : UInt64 :=
  if hfuel : fuel == 0 then
    acc
  else if ix >= count then
    acc
  else
    let payloadLen := policyPayloadLen policy ix
    let add := if payloadLen == 0 then 0 else nlaTotalSize payloadLen
    policyLenLoop policy count (ix + 1) (acc + add) (fuel - 1)
termination_by fuel.toNat
decreasing_by
  exact u64PredToNatLtOfBoolNeZero fuel hfuel

def isUnsignedRangeType (ty : UInt64) : Bool :=
  ty == nlaU8 || ty == nlaU16 || ty == nlaU32 || ty == nlaU64 ||
    ty == nlaUInt || ty == nlaMsecs || ty == nlaBE16 ||
    ty == nlaBE32 || ty == nlaBinary

def isSignedRangeType (ty : UInt64) : Bool :=
  ty == nlaS8 || ty == nlaS16 || ty == nlaS32 || ty == nlaS64 ||
    ty == nlaSInt

def unsignedRangeDefaultMax (ty : UInt64) : UInt64 :=
  if ty == nlaU8 then
    0xff
  else if ty == nlaU16 || ty == nlaBE16 || ty == nlaBinary then
    0xffff
  else if ty == nlaU32 || ty == nlaBE32 then
    u32Max
  else if ty == nlaU64 || ty == nlaUInt || ty == nlaMsecs then
    u64Max
  else
    0

def signedRangeDefaultMin (ty : UInt64) : UInt64 :=
  if ty == nlaS8 then
    s8Min
  else if ty == nlaS16 then
    s16Min
  else if ty == nlaS32 then
    s32Min
  else if ty == nlaS64 || ty == nlaSInt then
    s64Min
  else
    0

def signedRangeDefaultMax (ty : UInt64) : UInt64 :=
  if ty == nlaS8 then
    s8Max
  else if ty == nlaS16 then
    s16Max
  else if ty == nlaS32 then
    s32Max
  else if ty == nlaS64 || ty == nlaSInt then
    s64Max
  else
    0

structure ValidateArgs where
  len : UInt64
  maxtype : UInt64
  policy : UInt64
  strictStart : UInt64
  validate : UInt64
  extack : UInt64
  tb : UInt64

def validateArgs
    (len maxtype policy strictStart validate extack tb : UInt64) : ValidateArgs :=
  { len := len, maxtype := maxtype, policy := policy,
    strictStart := strictStart, validate := validate, extack := extack, tb := tb }

def validateViewCore (view : AttrView) (args : ValidateArgs) : UInt64 :=
  if unsupportedValidateFlags args.validate then
    unsupported
  else
    let policyTable := PolicyTableView.ofRaw args.policy args.maxtype
    viewValidateLoop view args.len args.maxtype args.policy args.strictStart
      args.validate args.extack 0 args.tb policyTable (args.len + 1) 0

def validateRegionCore
    (region : Memory.Region) (base : UInt64) (args : ValidateArgs) : UInt64 :=
  validateViewCore (AttrView.ofRegion base region) args

@[export lean_nlattr_validate_parse_core]
def validateParseCore
    (head len maxtype policy strictStart validate extack tb : UInt64) : UInt64 :=
  if unsupportedValidateFlags validate then
    unsupported
  else if head == 0 then
    if len == 0 then ok else einval
  else
    validateRegionCore (rawRegion head len) head
      (validateArgs len maxtype policy strictStart validate extack tb)

@[export lean_nlattr_find_core]
def findCore (head len attrtype : UInt64) : UInt64 :=
  if head == 0 || attrtype == 0 then
    0
  else
    match Memory.find? (rawRegion head len) attrtype with
    | some off => head + off.toUInt64
    | none => 0

namespace Verified

theorem validateParseCore_nonzero_eq_validateViewCore
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0) :
    validateParseCore head len maxtype policy strictStart validate extack tb =
      _root_.LeanNlAttr.validateViewCore (AttrView.ofRaw head len)
        (validateArgs len maxtype policy strictStart validate extack tb) := by
  have hHeadNe : head ≠ 0 := by
    intro hEq
    simp [hEq] at hHead
  unfold validateParseCore validateRegionCore _root_.LeanNlAttr.validateViewCore
    AttrView.ofRaw AttrView.ofRegion validateArgs
  cases hUnsupported : unsupportedValidateFlags validate <;>
    simp [hHeadNe]

structure AttributeSpatialSafety (view : AttrView) : Prop where
  headerRead :
    forall off : UInt64,
      off.toNat + Memory.nlaHeaderBytes <= view.totalLen \/
        AttrView.header view off = 0
  payloadRead :
    forall off ix : UInt64,
      off.toNat + Memory.nlaHeaderBytes + ix.toNat < view.totalLen \/
        AttrView.byte view off ix = 0
  payloadSubregion :
    forall off payloadLen : UInt64,
      (view.payloadView off payloadLen).start +
          (view.payloadView off payloadLen).totalLen <=
        (view.payloadView off payloadLen).region.totalLen

structure PolicyRowSpatialSafety (row : PolicyRowView) : Prop where
  fieldRead :
    forall off : UInt64,
      off.toNat < row.totalLen \/ row.byte off = 0

structure BoundedValidateInput where
  region : Memory.Region
  base : UInt64
  args : ValidateArgs
  len_matches_region : args.len.toNat = region.totalLen

def BoundedValidateInput.view (input : BoundedValidateInput) : AttrView :=
  AttrView.ofRegion input.base input.region

def BoundedValidateInput.policyTable (input : BoundedValidateInput) :
    PolicyTableView :=
  PolicyTableView.ofRaw input.args.policy input.args.maxtype

def BoundedValidateInput.wireAttrs? (input : BoundedValidateInput) :
    Option (List Memory.Layout.WireAttr) :=
  Memory.Layout.regionParseAttrs? input.region

def BoundedValidateInput.wireAttrAt?
    (input : BoundedValidateInput) (off : Nat) :
    Option Memory.Layout.WireAttr :=
  Memory.Layout.regionWireAttrAt? input.region off

def BoundedValidateInput.ofRaw
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hLen : (rawRegion head len).totalLen = len.toNat) :
    BoundedValidateInput :=
  { region := rawRegion head len,
    base := head,
    args := validateArgs len maxtype policy strictStart validate extack tb,
    len_matches_region := hLen.symm }

theorem BoundedValidateInput.view_header_eq_region_header
    (input : BoundedValidateInput) (off : UInt64)
    (hHeader : off.toNat + Memory.nlaHeaderBytes ≤ input.region.totalLen) :
    input.view.header off =
      input.region.header off.toNat hHeader := by
  unfold BoundedValidateInput.view AttrView.ofRegion AttrView.header
  simp [hHeader]

def BoundedValidateInput.StructuralWellFormed
    (input : BoundedValidateInput) : Prop :=
  ∃ attrs, input.wireAttrs? = some attrs

def BoundedValidateInput.WireStreamMatches
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop :=
  Memory.Layout.WireStreamMatchesRegion input.region attrs

structure BoundedValidateInput.WireByteBoundsSpec
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop where
  headerBytes :
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        ∀ (ix : Nat),
          ix < Memory.Layout.headerLen →
            entry.1 + ix < input.region.totalLen
  payloadBytes :
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        ∀ (ix : Nat),
          ix < entry.2.payloadLen →
            entry.1 + Memory.Layout.headerLen + ix <
              input.region.totalLen

structure BoundedValidateInput.WireMessageSpec
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop where
  parsed : input.wireAttrs? = some attrs
  stream : input.WireStreamMatches attrs
  payloadFits :
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        Memory.Layout.payloadFits input.region.totalLen entry.1 entry.2
  headerFields :
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        ∃ hHeader :
          entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
          let header := input.region.header entry.1 hHeader
          entry.2.ty = (Memory.attrHeaderType header).toNat ∧
            entry.2.payloadLen = (Memory.attrHeaderLen header).toNat -
              Memory.Layout.headerLen ∧
            entry.2.nested = (Memory.attrHeaderIsNested header != 0)

def BoundedValidateInput.WireStructuralSpec
    (input : BoundedValidateInput) : Prop :=
  ∃ attrs, input.WireMessageSpec attrs

def BoundedValidateInput.WireAttrsAllowedByMaxType
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop :=
  if hasFlag input.args.validate validateMaxType then
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        entry.2.ty ≠ 0 ∧ entry.2.ty ≤ input.args.maxtype.toNat
  else
    True

def BoundedValidateInput.WireMaxTypeSpec
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop :=
  input.WireMessageSpec attrs ∧ input.WireAttrsAllowedByMaxType attrs

def BoundedValidateInput.WirePolicyIndexSpec
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr) : Prop :=
  hasFlag input.args.validate validateMaxType →
    input.args.maxtype.toNat + 1 < UInt64.size →
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          ∀ hHeader :
            entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
            arrayIndexNospec
                (Memory.attrHeaderType
                  (input.region.header entry.1 hHeader))
                (input.args.maxtype + 1) =
              Memory.attrHeaderType
                (input.region.header entry.1 hHeader)

def validateBoundedRegionCore (input : BoundedValidateInput) : UInt64 :=
  _root_.LeanNlAttr.validateViewCore input.view input.args

set_option linter.unusedSimpArgs false in
theorem viewValidatePayloadShape_conforms
    (view : AttrView) (off policy ty kind row payloadLen : UInt64) :
    viewValidatePayloadShape view off policy ty kind row payloadLen = ok ↔
      PayloadShapeAccepted view off policy ty kind row payloadLen := by
  unfold viewValidatePayloadShape PayloadShapeAccepted
  by_cases hAccept : kind == kindAccept
  · simp [hAccept, ok, erange, einval, unsupported]
  · by_cases hFlag : kind == kindFlag
    · simp [hAccept, hFlag, ok, erange, einval, unsupported]
    · by_cases hExact : kind == kindExact
      · simp [hAccept, hFlag, hExact, ok, erange, einval, unsupported]
      · by_cases hMin : kind == kindMin
        · simp [hAccept, hFlag, hExact, hMin, ok, erange, einval, unsupported]
        · by_cases hRange : kind == kindRange
          · simp [hAccept, hFlag, hExact, hMin, hRange, ok, erange, einval,
              unsupported]
          · by_cases hReject : kind == kindReject
            · simp [hAccept, hFlag, hExact, hMin, hRange, hReject, ok, erange,
                einval, unsupported]
            · by_cases hString : kind == kindString
              · simp [hAccept, hFlag, hExact, hMin, hRange, hReject, hString,
                  ok, erange, einval, unsupported]
              · by_cases hNulString : kind == kindNulString
                · simp [hAccept, hFlag, hExact, hMin, hRange, hReject, hString,
                    hNulString, ok, erange, einval, unsupported]
                · by_cases hBitfield : kind == kindBitfield32
                  · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                      hString, hNulString, hBitfield, ok, erange, einval,
                      unsupported]
                  · by_cases hInt : kind == kindInt32Or64
                    · by_cases hPayload4 : payloadLen = 4
                      · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                          hString, hNulString, hBitfield, hInt, hPayload4, ok,
                          erange, einval, unsupported]
                      · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                          hString, hNulString, hBitfield, hInt, hPayload4, ok,
                          erange, einval, unsupported]
                    · by_cases hNested : kind == kindNested
                      · by_cases hPayload0 : payloadLen = 0
                        · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                            hString, hNulString, hBitfield, hInt, hNested,
                            hPayload0, ok, erange, einval, unsupported]
                        · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                            hString, hNulString, hBitfield, hInt, hNested,
                            hPayload0, ok, erange, einval, unsupported]
                      · simp [hAccept, hFlag, hExact, hMin, hRange, hReject,
                          hString, hNulString, hBitfield, hInt, hNested, ok,
                          erange, einval, unsupported]

theorem keepReported_ok_iff (reported status : UInt64) :
    keepReported reported status = ok ↔ reported != u64Max ∧ status = ok := by
  unfold keepReported
  by_cases hReported : reported == u64Max
  · have hEq : reported = u64Max := by
      simpa using hReported
    subst reported
    simp [ok, u64Max]
  · have hNe : reported ≠ u64Max := by
      intro hEq
      simp [hEq] at hReported
    simp [hReported, hNe]

theorem keepReported_ne_ok_of_status_ne_ok
    (reported status : UInt64) (hStatus : status ≠ ok) :
    keepReported reported status ≠ ok := by
  intro h
  exact hStatus ((keepReported_ok_iff reported status).mp h).2

theorem reportTrailingResult_ok_iff (validate extack : UInt64) :
    reportTrailingResult validate extack = ok ↔
      reportValidateError diagTrailingBytes 0 0 0 extack != u64Max ∧
        (hasFlag validate validateTrailing) = false := by
  unfold reportTrailingResult
  rw [keepReported_ok_iff]
  by_cases hTrailing : hasFlag validate validateTrailing
  · simp [hTrailing, ok, einval]
  · simp [hTrailing]

theorem reportPayloadShapeResult_ok_iff
    (ret kind attr policy ty extack : UInt64) :
    reportPayloadShapeResult ret kind attr policy ty extack = ok ↔ ret = ok := by
  unfold reportPayloadShapeResult
  by_cases hRet : ret == ok
  · have hEq : ret = ok := by
      simpa using hRet
    subst ret
    simp [ok]
  · have hNe : ret ≠ ok := by
      intro hEq
      simp [hEq] at hRet
    simp [hRet, keepReported_ok_iff, hNe]

set_option linter.unusedSimpArgs false in
theorem validateUnsignedExtra_conforms
    (validation value minValue maxValue mask : UInt64) :
    validateUnsignedExtra validation value minValue maxValue mask = ok ↔
      UnsignedExtraAccepted validation value minValue maxValue mask := by
  unfold validateUnsignedExtra UnsignedExtraAccepted
  by_cases hRange :
      validation == policyValidateRange ||
        validation == policyValidateRangeWarnTooLong ||
        validation == policyValidateRangePtr
  · simp [hRange, ok, erange, einval, unsupported]
  · by_cases hMin : validation == policyValidateMin
    · simp [hRange, hMin, ok, erange, einval, unsupported]
    · by_cases hMax : validation == policyValidateMax
      · simp [hRange, hMin, hMax, ok, erange, einval, unsupported]
      · by_cases hMask : validation == policyValidateMask
        · simp [hRange, hMin, hMax, hMask, ok, erange, einval, unsupported]
        · by_cases hNone : validation == policyValidateNone
          · simp [hRange, hMin, hMax, hMask, hNone, ok, erange, einval,
              unsupported]
          · simp [hRange, hMin, hMax, hMask, hNone, ok, erange, einval,
              unsupported]

set_option linter.unusedSimpArgs false in
theorem validateBinaryExtra_conforms
    (payloadLen validation minValue maxValue validate : UInt64) :
    validateBinaryExtra payloadLen validation minValue maxValue validate = ok ↔
      BinaryExtraAccepted payloadLen validation minValue maxValue validate := by
  unfold validateBinaryExtra BinaryExtraAccepted
  by_cases hWarn :
      validation == policyValidateRangeWarnTooLong && payloadLen > maxValue
  · by_cases hStrict : hasFlag validate validateStrictAttrs
    · simp [hWarn, hStrict, ok, einval]
    · simp [hWarn, hStrict, ok, einval]
  · simp [hWarn, validateUnsignedExtra_conforms]

set_option linter.unusedSimpArgs false in
theorem validateBinaryExtraReported_conforms
    (payloadLen validation minValue maxValue validate attr policy ty extack :
      UInt64) :
    validateBinaryExtraReported payloadLen validation minValue maxValue validate
        attr policy ty extack = ok ↔
      BinaryExtraReportedAccepted payloadLen validation minValue maxValue
        validate attr policy ty extack := by
  unfold validateBinaryExtraReported BinaryExtraReportedAccepted
  by_cases hWarn :
      validation == policyValidateRangeWarnTooLong && payloadLen > maxValue
  · simp [hWarn, keepReported_ok_iff, validateBinaryExtra_conforms]
    constructor
    · intro h
      exact And.symm h
    · intro h
      exact And.symm h
  · simp [hWarn, validateBinaryExtra_conforms]

set_option linter.unusedSimpArgs false in
theorem reportExtraResult_ok_iff
    (ret validation valueKind attr policy ty extack : UInt64) :
    reportExtraResult ret validation valueKind attr policy ty extack = ok ↔
      ret = ok := by
  unfold reportExtraResult
  by_cases hRetOk : ret = ok
  · subst ret
    simp [ok]
  · have hRetOkBool : (ret == ok) = false := by
      simp [hRetOk]
    simp [hRetOkBool]
    constructor
    · intro h
      by_cases hRange : ret = erange
      · subst ret
        simp [erange, einval] at h
        unfold keepReported at h
        by_cases hReport :
            reportValidateError
              (if valueKind = valueBinaryLen then
                diagBinaryRange
              else
                diagIntegerRange)
              attr policy ty extack = u64Max
        · simp [hReport, ok, u64Max] at h
        · simp [hReport, ok, erange] at h
      · simp [hRange] at h
        by_cases hMask : ret = einval ∧ validation = policyValidateMask
        · rcases hMask with ⟨hRetEinval, hValidation⟩
          subst ret
          simp [einval, hValidation] at h
          unfold keepReported at h
          by_cases hReport :
              reportValidateError diagReservedBit attr policy ty extack =
                u64Max
          · simp [hReport, ok, u64Max] at h
          · simp [hReport, ok, einval] at h
        · simp [hMask] at h
          by_cases hWarn :
              (ret = einval ∧ validation = policyValidateRangeWarnTooLong) ∧
                valueKind = valueBinaryLen
          · rcases hWarn with ⟨⟨hRetEinval, hValidation⟩, hValueKind⟩
            subst ret
            simp [einval, ok, hValidation, hValueKind] at h
          · simp [hWarn] at h
            have hStatus :=
              (keepReported_ok_iff
                (reportValidateError diagFailedPolicy attr policy ty extack)
                ret).mp h
            exact False.elim (hRetOk hStatus.2)
    · intro h
      exact False.elim (hRetOk h)

set_option linter.unusedSimpArgs false in
theorem validateSignedExtra_conforms
    (validation value minValue maxValue : UInt64) :
    validateSignedExtra validation value minValue maxValue = ok ↔
      SignedExtraAccepted validation value minValue maxValue := by
  unfold validateSignedExtra SignedExtraAccepted
  by_cases hRange :
      validation == policyValidateRange || validation == policyValidateRangePtr
  · simp [hRange, ok, erange, unsupported]
  · by_cases hMin : validation == policyValidateMin
    · simp [hRange, hMin, ok, erange, unsupported]
    · by_cases hMax : validation == policyValidateMax
      · simp [hRange, hMin, hMax, ok, erange, unsupported]
      · by_cases hNone : validation == policyValidateNone
        · simp [hRange, hMin, hMax, hNone, ok, erange, unsupported]
        · simp [hRange, hMin, hMax, hNone, ok, erange, unsupported]

set_option linter.unusedSimpArgs false in
theorem viewValidatePolicyExtra_conforms
    (view : AttrView) (off policy ty row payloadLen validate attr extack :
      UInt64) :
    viewValidatePolicyExtra view off policy ty row payloadLen validate attr
        extack = ok ↔
      PolicyExtraAccepted view off policy ty row payloadLen validate attr
        extack := by
  unfold viewValidatePolicyExtra PolicyExtraAccepted
  by_cases hPolicy : policy == 0
  · simp [hPolicy, ok]
  · by_cases hValidationNone : policyMetaValidation row == policyValidateNone
    · simp [hPolicy, hValidationNone, ok]
    · by_cases hValidationFunction :
        policyMetaValidation row == policyValidateFunction
      · simp [hPolicy, hValidationNone, hValidationFunction, ok]
      · by_cases hWidth :
          valueReadWidth (policyMetaValueKind row) != 0 &&
            payloadLen < valueReadWidth (policyMetaValueKind row)
        · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
            keepReported_ok_iff, ok, unsupported]
          exact keepReported_ne_ok_of_status_ne_ok
            (reportValidateError diagFailedPolicy attr policy ty extack)
            unsupported
            (by simp [unsupported, ok])
        · by_cases hBinary : policyMetaValueKind row == valueBinaryLen
          · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
              hBinary, reportExtraResult_ok_iff,
              validateBinaryExtraReported_conforms]
          · by_cases hMask : policyMetaValidation row == policyValidateMask
            · by_cases hMaskable :
                isMaskableValueKind (policyMetaValueKind row)
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hMaskable, reportExtraResult_ok_iff,
                  validateUnsignedExtra_conforms]
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hMaskable, keepReported_ok_iff, ok,
                  unsupported]
                exact keepReported_ne_ok_of_status_ne_ok
                  (reportValidateError diagFailedPolicy attr policy ty extack)
                  unsupported
                  (by simp [unsupported, ok])
            · by_cases hUnsigned :
                isUnsignedValueKind (policyMetaValueKind row)
              · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                  hBinary, hMask, hUnsigned, reportExtraResult_ok_iff,
                  validateUnsignedExtra_conforms]
              · by_cases hSigned :
                  isSignedValueKind (policyMetaValueKind row)
                · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                    hBinary, hMask, hUnsigned, hSigned,
                    reportExtraResult_ok_iff, validateSignedExtra_conforms]
                · simp [hPolicy, hValidationNone, hValidationFunction, hWidth,
                    hBinary, hMask, hUnsigned, hSigned, keepReported_ok_iff,
                    ok, unsupported]
                  exact keepReported_ne_ok_of_status_ne_ok
                    (reportValidateError diagFailedPolicy attr policy ty extack)
                    unsupported
                    (by simp [unsupported, ok])

theorem viewValidatePolicyExtra_conforms_spec
    (view : AttrView) (off policy ty row payloadLen validate attr extack :
      UInt64) :
    viewValidatePolicyExtra view off policy ty row payloadLen validate attr
        extack = ok ↔
      PolicyExtraSpec view off policy ty row payloadLen validate attr
        extack :=
  (viewValidatePolicyExtra_conforms view off policy ty row payloadLen validate
    attr extack).trans
    (policyExtraSpec_iff_accepted view off policy ty row payloadLen validate
      attr extack).symm

set_option linter.unusedSimpArgs false in
theorem viewValidatePayload_conforms
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    viewValidatePayload view off policy ty kind row payloadLen validate extack =
        ok ↔
      PayloadAccepted view off policy ty kind row payloadLen validate extack := by
  unfold viewValidatePayload PayloadAccepted
  let attr := view.ptr off
  let shapeRet :=
    viewValidatePayloadShape view off policy ty kind row payloadLen
  let reported :=
    reportPayloadShapeResult shapeRet kind attr policy ty extack
  by_cases hReported : reported = ok
  · have hShapeRet : shapeRet = ok :=
      (reportPayloadShapeResult_ok_iff shapeRet kind attr policy ty extack).mp
        hReported
    have hShape :
        PayloadShapeAccepted view off policy ty kind row payloadLen :=
      (viewValidatePayloadShape_conforms view off policy ty kind row
        payloadLen).mp hShapeRet
    have hReportedNe : (reported != ok) = false := by
      simp [hReported]
    simp [attr, shapeRet, reported, hReportedNe, hShape]
    by_cases hPolicy : policy == 0
    · have hPolicyEq : policy = 0 := by
        simpa using hPolicy
      simp [hPolicyEq, ok]
    · by_cases hValidationNone :
        policyMetaValidation row == policyValidateNone
      · have hPolicyNe : policy ≠ 0 := by
          intro hEq
          simp [hEq] at hPolicy
        have hValidationEq :
            policyMetaValidation row = policyValidateNone := by
          simpa using hValidationNone
        simp [hPolicyNe, hValidationEq, ok]
      · have hPolicyNe : policy ≠ 0 := by
          intro hEq
          simp [hEq] at hPolicy
        have hValidationNe :
            policyMetaValidation row ≠ policyValidateNone := by
          intro hEq
          simp [hEq] at hValidationNone
        simp [hPolicyNe, hValidationNe, viewValidatePolicyExtra_conforms]
  · have hReportedNe : (reported != ok) = true := by
      simp [hReported]
    have hShapeNot :
        ¬ PayloadShapeAccepted view off policy ty kind row payloadLen := by
      intro hShape
      have hShapeRet : shapeRet = ok :=
        (viewValidatePayloadShape_conforms view off policy ty kind row
          payloadLen).mpr hShape
      exact hReported
        ((reportPayloadShapeResult_ok_iff shapeRet kind attr policy ty extack).mpr
          hShapeRet)
    simp [attr, shapeRet, reported, hReportedNe, hReported, hShapeNot]

theorem viewValidatePayload_conforms_spec
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    viewValidatePayload view off policy ty kind row payloadLen validate extack =
        ok ↔
      PayloadSpec view off policy ty kind row payloadLen validate extack :=
  (viewValidatePayload_conforms view off policy ty kind row payloadLen validate
    extack).trans
    (payloadSpec_iff_accepted view off policy ty kind row payloadLen validate
      extack).symm

theorem viewValidatePayload_conforms_policy_spec
    (view : AttrView) (off policy ty kind row payloadLen validate extack :
      UInt64) :
    viewValidatePayload view off policy ty kind row payloadLen validate extack =
        ok ↔
      PayloadPolicySpec view off policy ty kind row payloadLen validate
        extack :=
  (viewValidatePayload_conforms_spec view off policy ty kind row payloadLen
    validate extack).trans
    (payloadPolicySpec_iff_payloadSpec view off policy ty kind row payloadLen
      validate extack).symm

structure ValidateInputSpatialSafety (input : BoundedValidateInput) : Prop where
  message : AttributeSpatialSafety input.view
  policyRows :
    forall ty : UInt64,
      PolicyRowSpatialSafety (input.policyTable.row ty)

structure ValidateForeignEffectsOk : Prop where
  reports :
    forall reason attr policy ty extack : UInt64,
      reportValidateError reason attr policy ty extack != u64Max
  tableWrites :
    forall tb ty attr : UInt64,
      tb != 0 → setTb tb ty attr = ok

theorem tableWriteStatus_ok_iff (tb ty attr : UInt64) :
    tableWriteStatus tb ty attr = ok ↔ TableWriteAccepted tb ty attr := by
  unfold tableWriteStatus TableWriteAccepted
  by_cases hTb : tb == 0
  · simp [hTb, ok]
  · by_cases hWrite : setTb tb ty attr = ok
    · have hWriteBool : (setTb tb ty attr != ok) = false := by
        simp [hWrite]
      simp [hTb, hWrite]
    · have hWriteBool : (setTb tb ty attr != ok) = true := by
        simp [hWrite]
      simp [hTb, ok, unsupported]

theorem knownAttrWriteStatus_ok_iff (tb ty maxtype attr : UInt64) :
    knownAttrWriteStatus tb ty maxtype attr = ok ↔
      KnownAttrWriteAccepted tb ty maxtype attr := by
  unfold knownAttrWriteStatus KnownAttrWriteAccepted
  exact tableWriteStatus_ok_iff tb (arrayIndexNospec ty (maxtype + 1)) attr

theorem statusThen_ok_iff
    (status next : UInt64) (accepted nextAccepted : Prop)
    (hStatus : status = ok ↔ accepted)
    (hNext : next = ok ↔ nextAccepted) :
    (if status != ok then status else next) = ok ↔
      accepted ∧ nextAccepted := by
  by_cases hStatusOk : status = ok
  · have hStatusNe : (status != ok) = false := by
      simp [hStatusOk]
    have hAccepted : accepted := hStatus.mp hStatusOk
    simp [hStatusNe, hAccepted, hNext]
  · have hStatusNe : (status != ok) = true := by
      simp [hStatusOk]
    have hNotAccepted : ¬ accepted := by
      intro hAccepted
      exact hStatusOk (hStatus.mpr hAccepted)
    simp [hStatusNe, hStatusOk, hNotAccepted]

theorem boolDite_eq_ite {α : Sort u} (b : Bool) (thenBranch elseBranch : α) :
    (if _h : b = true then thenBranch else elseBranch) =
      if b then thenBranch else elseBranch := by
  cases b <;> simp

theorem statusThenIf_ok_iff
    (status next : UInt64) (accepted nextAccepted done : Prop)
    [Decidable done]
    (hStatus : status = ok ↔ accepted)
    (hNext : next = ok ↔ nextAccepted) :
    (if status != ok then status else if done then ok else next) = ok ↔
      accepted ∧ if done then True else nextAccepted := by
  have hTail : (if done then ok else next) = ok ↔
      if done then True else nextAccepted := by
    by_cases hDone : done
    · simp [hDone, ok]
    · simpa [hDone] using hNext
  exact statusThen_ok_iff status (if done then ok else next)
    accepted (if done then True else nextAccepted) hStatus hTail

theorem statusThenIf_status_reject_ok_iff
    (status next : UInt64) (accepted nextAccepted done : Prop)
    [Decidable done]
    (hStatus : status = ok ↔ accepted)
    (hReject : (status != ok) = true) :
    (if status != ok then status else if done then ok else next) = ok ↔
      accepted ∧ if done then True else nextAccepted := by
  have hStatusNe : status ≠ ok := by
    simpa using hReject
  have hNotAccepted : ¬ accepted := by
    intro hAccepted
    exact hStatusNe (hStatus.mpr hAccepted)
  simp [hReject, hStatusNe, hNotAccepted]

theorem statusThenIf_done_ok_iff
    (status next : UInt64) (accepted nextAccepted done : Prop)
    [Decidable done]
    (hStatus : status = ok ↔ accepted)
    (hStatusOk : (status != ok) = false)
    (hDone : done) :
    (if status != ok then status else if done then ok else next) = ok ↔
      accepted ∧ if done then True else nextAccepted := by
  have hStatusEq : status = ok := by
    simpa using hStatusOk
  have hAccepted : accepted := hStatus.mp hStatusEq
  simp [hStatusEq, hDone, hAccepted, ok]

theorem knownAttrTail_ok_iff
    (verdict nextStatus tb ty maxtype attr : UInt64)
    (verdictAccepted nextAccepted done : Prop)
    [Decidable done]
    (hVerdict : verdict = ok ↔ verdictAccepted)
    (hNext : nextStatus = ok ↔ nextAccepted) :
    (if verdict != ok then
        verdict
      else
        let writeStatus := knownAttrWriteStatus tb ty maxtype attr
        if writeStatus != ok then
          writeStatus
        else if done then ok else nextStatus) = ok ↔
      verdictAccepted ∧
        KnownAttrWriteAccepted tb ty maxtype attr ∧
        if done then True else nextAccepted := by
  let writeStatus := knownAttrWriteStatus tb ty maxtype attr
  have hWrite :
      writeStatus = ok ↔ KnownAttrWriteAccepted tb ty maxtype attr := by
    unfold writeStatus
    exact knownAttrWriteStatus_ok_iff tb ty maxtype attr
  have hWriteTail :
      (if writeStatus != ok then
          writeStatus
        else if done then ok else nextStatus) = ok ↔
        KnownAttrWriteAccepted tb ty maxtype attr ∧
          if done then True else nextAccepted :=
    statusThenIf_ok_iff writeStatus nextStatus
      (KnownAttrWriteAccepted tb ty maxtype attr) nextAccepted done hWrite hNext
  exact statusThen_ok_iff verdict
    (if writeStatus != ok then
      writeStatus
    else if done then ok else nextStatus)
    verdictAccepted
    (KnownAttrWriteAccepted tb ty maxtype attr ∧
      if done then True else nextAccepted)
    hVerdict hWriteTail

theorem knownAttrTail_verdict_reject_ok_iff
    (verdict nextStatus tb ty maxtype attr : UInt64)
    (verdictAccepted nextAccepted done : Prop)
    [Decidable done]
    (hVerdict : verdict = ok ↔ verdictAccepted)
    (hVerdictReject : (verdict != ok) = true) :
    (if verdict != ok then
        verdict
      else
        let writeStatus := knownAttrWriteStatus tb ty maxtype attr
        if writeStatus != ok then
          writeStatus
        else if done then ok else nextStatus) = ok ↔
      verdictAccepted ∧
        KnownAttrWriteAccepted tb ty maxtype attr ∧
        if done then True else nextAccepted := by
  have hVerdictNe : verdict ≠ ok := by
    simpa using hVerdictReject
  have hNotAccepted : ¬ verdictAccepted := by
    intro hAccepted
    exact hVerdictNe (hVerdict.mpr hAccepted)
  simp [hVerdictReject, hVerdictNe, hNotAccepted]

theorem knownAttrTail_write_reject_ok_iff
    (verdict nextStatus tb ty maxtype attr : UInt64)
    (verdictAccepted nextAccepted done : Prop)
    [Decidable done]
    (hVerdict : verdict = ok ↔ verdictAccepted)
    (hVerdictOk : (verdict != ok) = false)
    (hWriteReject :
      (knownAttrWriteStatus tb ty maxtype attr != ok) = true) :
    (if verdict != ok then
        verdict
      else
        let writeStatus := knownAttrWriteStatus tb ty maxtype attr
        if writeStatus != ok then
          writeStatus
        else if done then ok else nextStatus) = ok ↔
      verdictAccepted ∧
        KnownAttrWriteAccepted tb ty maxtype attr ∧
        if done then True else nextAccepted := by
  let writeStatus := knownAttrWriteStatus tb ty maxtype attr
  have hVerdictEq : verdict = ok := by
    simpa using hVerdictOk
  have hAccepted : verdictAccepted := hVerdict.mp hVerdictEq
  have hWriteReject' : (writeStatus != ok) = true := by
    simpa only [writeStatus] using hWriteReject
  have hWriteNe : writeStatus ≠ ok := by
    simpa using hWriteReject'
  have hNotWriteAccepted : ¬ KnownAttrWriteAccepted tb ty maxtype attr := by
    intro hAcceptedWrite
    exact hWriteNe
      ((knownAttrWriteStatus_ok_iff tb ty maxtype attr).mpr hAcceptedWrite)
  simp [writeStatus, hVerdictOk, hWriteReject', hWriteNe, hAccepted,
    hNotWriteAccepted]

theorem knownAttrTail_done_ok_iff
    (verdict nextStatus tb ty maxtype attr : UInt64)
    (verdictAccepted nextAccepted done : Prop)
    [Decidable done]
    (hVerdict : verdict = ok ↔ verdictAccepted)
    (hVerdictOk : (verdict != ok) = false)
    (hWriteOk :
      (knownAttrWriteStatus tb ty maxtype attr != ok) = false)
    (hDone : done) :
    (if verdict != ok then
        verdict
      else
        let writeStatus := knownAttrWriteStatus tb ty maxtype attr
        if writeStatus != ok then
          writeStatus
        else if done then ok else nextStatus) = ok ↔
      verdictAccepted ∧
        KnownAttrWriteAccepted tb ty maxtype attr ∧
        if done then True else nextAccepted := by
  let writeStatus := knownAttrWriteStatus tb ty maxtype attr
  have hVerdictEq : verdict = ok := by
    simpa using hVerdictOk
  have hAccepted : verdictAccepted := hVerdict.mp hVerdictEq
  have hWriteOk' : (writeStatus != ok) = false := by
    simpa only [writeStatus] using hWriteOk
  have hWriteEq : writeStatus = ok := by
    simpa using hWriteOk'
  have hWriteEqRaw : knownAttrWriteStatus tb ty maxtype attr = ok := by
    simpa only [writeStatus] using hWriteEq
  have hWriteAccepted : KnownAttrWriteAccepted tb ty maxtype attr :=
    (knownAttrWriteStatus_ok_iff tb ty maxtype attr).mp hWriteEq
  simp [hVerdictEq, hWriteEqRaw, hDone, hAccepted,
    hWriteAccepted, ok]

theorem statusEqThenIf_ok_iff
    (status extra : UInt64) (accepted extraAccepted skipExtra : Prop)
    [Decidable skipExtra]
    (hStatus : status = ok ↔ accepted)
    (hExtra : extra = ok ↔ extraAccepted) :
    (if status == ok then if skipExtra then ok else extra else status) = ok ↔
      accepted ∧ if skipExtra then True else extraAccepted := by
  by_cases hStatusOk : status = ok
  · have hStatusEq : (status == ok) = true := by
      simp [hStatusOk]
    have hAccepted : accepted := hStatus.mp hStatusOk
    by_cases hSkip : skipExtra
    · simp [hStatusOk, hSkip, hAccepted, ok]
    · simp [hStatusOk, hSkip, hAccepted, hExtra]
  · have hStatusEq : (status == ok) = false := by
      simp [hStatusOk]
    have hNotAccepted : ¬ accepted := by
      intro hAccepted
      exact hStatusOk (hStatus.mpr hAccepted)
    simp [hStatusEq, hStatusOk, hNotAccepted]

theorem statusEqThenBoolIf_ok_iff
    (status extra : UInt64) (accepted extraAccepted : Prop)
    (skipExtra : Bool)
    (hStatus : status = ok ↔ accepted)
    (hExtra : extra = ok ↔ extraAccepted) :
    (if status == ok then if skipExtra then ok else extra else status) = ok ↔
      accepted ∧ if skipExtra then True else extraAccepted := by
  by_cases hStatusOk : status = ok
  · have hAccepted : accepted := hStatus.mp hStatusOk
    cases skipExtra
    · simp [hStatusOk, hAccepted, hExtra]
    · simp [hStatusOk, hAccepted, ok]
  · have hStatusEq : (status == ok) = false := by
      simp [hStatusOk]
    have hNotAccepted : ¬ accepted := by
      intro hAccepted
      exact hStatusOk (hStatus.mpr hAccepted)
    simp [hStatusEq, hStatusOk, hNotAccepted]

theorem nestedRet_ok_iff
    (payloadLen status : UInt64) (accepted : Prop)
    (hStatus : status = ok ↔ accepted) :
    (if payloadLen == 0 then ok
     else if payloadLen < nlaHeaderLen then erange
     else status) = ok ↔
      if payloadLen == 0 then True
      else if payloadLen < nlaHeaderLen then False
      else accepted := by
  by_cases hZero : payloadLen = 0
  · have hZeroBool : (payloadLen == 0) = true := by
      simp [hZero]
    simp [hZeroBool, ok]
  · have hZeroBool : (payloadLen == 0) = false := by
      simp [hZero]
    by_cases hShort : payloadLen < nlaHeaderLen
    · simp [hZeroBool, hShort, erange, ok]
    · simp [hZeroBool, hShort, hStatus]

theorem nestedThenPolicyExtra_ok_iff
    (payloadLen nestedStatus extraStatus rowValidation : UInt64)
    (nestedAccepted extraAccepted : Prop)
    (hNested : nestedStatus = ok ↔ nestedAccepted)
    (hExtra : extraStatus = ok ↔ extraAccepted) :
    (let ret :=
       if payloadLen == 0 then ok
       else if payloadLen < nlaHeaderLen then erange
       else nestedStatus
     if ret == ok then
       if rowValidation == policyValidateNone then ok else extraStatus
     else
       ret) = ok ↔
      (if payloadLen == 0 then True
       else if payloadLen < nlaHeaderLen then False
       else nestedAccepted) ∧
        if rowValidation == policyValidateNone then True else extraAccepted := by
  let ret :=
    if payloadLen == 0 then ok
    else if payloadLen < nlaHeaderLen then erange
    else nestedStatus
  have hRet :
      ret = ok ↔
        if payloadLen == 0 then True
        else if payloadLen < nlaHeaderLen then False
        else nestedAccepted := by
    unfold ret
    exact nestedRet_ok_iff payloadLen nestedStatus nestedAccepted hNested
  exact statusEqThenBoolIf_ok_iff ret extraStatus
    (if payloadLen == 0 then True
     else if payloadLen < nlaHeaderLen then False
     else nestedAccepted)
    extraAccepted (rowValidation == policyValidateNone) hRet hExtra

theorem knownAttrPostRejectStatus_ok_iff
    (view : AttrView)
    (off policy policyTy kind row payloadLen effectiveValidate attr extack :
      UInt64)
    (nestedStatus nestedArrayStatus : UInt64)
    (nestedAccepted nestedArrayAccepted : Prop)
    (hNested : nestedStatus = ok ↔ nestedAccepted)
    (hNestedArray : nestedArrayStatus = ok ↔ nestedArrayAccepted) :
    (if kind == kindNestedPolicy then
        let ret :=
          if payloadLen == 0 then ok
          else if payloadLen < nlaHeaderLen then erange
          else nestedStatus
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else if kind == kindNestedArrayPolicy then
        let ret :=
          if payloadLen == 0 then ok
          else if payloadLen < nlaHeaderLen then erange
          else nestedArrayStatus
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else
        viewValidatePayload view off policy policyTy kind row payloadLen
          effectiveValidate extack) = ok ↔
      if kind == kindNestedPolicy then
        (if payloadLen == 0 then True
         else if payloadLen < nlaHeaderLen then False
         else nestedAccepted) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraAccepted view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else if kind == kindNestedArrayPolicy then
        (if payloadLen == 0 then True
         else if payloadLen < nlaHeaderLen then False
         else nestedArrayAccepted) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraAccepted view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else
        PayloadAccepted view off policy policyTy kind row payloadLen
          effectiveValidate extack := by
  have hExtra :
      viewValidatePolicyExtra view off policy policyTy row payloadLen
          effectiveValidate attr extack = ok ↔
        PolicyExtraAccepted view off policy policyTy row payloadLen
          effectiveValidate attr extack :=
    viewValidatePolicyExtra_conforms view off policy policyTy row payloadLen
      effectiveValidate attr extack
  by_cases hKindNested : kind == kindNestedPolicy
  · have hBranch :
      (let ret :=
          if payloadLen == 0 then ok
          else if payloadLen < nlaHeaderLen then erange
          else nestedStatus
       if ret == ok then
         if policyMetaValidation row == policyValidateNone then
           ok
         else
           viewValidatePolicyExtra view off policy policyTy row payloadLen
             effectiveValidate attr extack
       else
         ret) = ok ↔
        (if payloadLen == 0 then True
         else if payloadLen < nlaHeaderLen then False
         else nestedAccepted) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraAccepted view off policy policyTy row payloadLen
              effectiveValidate attr extack :=
      nestedThenPolicyExtra_ok_iff payloadLen nestedStatus
        (viewValidatePolicyExtra view off policy policyTy row payloadLen
          effectiveValidate attr extack)
        (policyMetaValidation row) nestedAccepted
        (PolicyExtraAccepted view off policy policyTy row payloadLen
          effectiveValidate attr extack)
        hNested hExtra
    simpa only [hKindNested, if_true] using hBranch
  · by_cases hKindNestedArray : kind == kindNestedArrayPolicy
    · have hBranch :
        (let ret :=
            if payloadLen == 0 then ok
            else if payloadLen < nlaHeaderLen then erange
            else nestedArrayStatus
         if ret == ok then
           if policyMetaValidation row == policyValidateNone then
             ok
           else
             viewValidatePolicyExtra view off policy policyTy row payloadLen
               effectiveValidate attr extack
         else
           ret) = ok ↔
          (if payloadLen == 0 then True
           else if payloadLen < nlaHeaderLen then False
           else nestedArrayAccepted) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraAccepted view off policy policyTy row payloadLen
                effectiveValidate attr extack :=
        nestedThenPolicyExtra_ok_iff payloadLen nestedArrayStatus
          (viewValidatePolicyExtra view off policy policyTy row payloadLen
            effectiveValidate attr extack)
          (policyMetaValidation row) nestedArrayAccepted
          (PolicyExtraAccepted view off policy policyTy row payloadLen
            effectiveValidate attr extack)
          hNestedArray hExtra
      simpa only [hKindNested, hKindNestedArray, Bool.false_eq_true,
        if_false, if_true] using hBranch
    · simpa only [hKindNested, hKindNestedArray, Bool.false_eq_true,
        if_false] using
        viewValidatePayload_conforms view off policy policyTy kind row
          payloadLen effectiveValidate extack

theorem knownAttrPostRejectStatus_ok_iff_policy_spec
    (view : AttrView)
    (off policy policyTy kind row payloadLen effectiveValidate attr extack :
      UInt64)
    (nestedStatus nestedArrayStatus : UInt64)
    (nestedAccepted nestedArrayAccepted : Prop)
    (hNested : nestedStatus = ok ↔ nestedAccepted)
    (hNestedArray : nestedArrayStatus = ok ↔ nestedArrayAccepted) :
    (if kind == kindNestedPolicy then
        let ret :=
          if payloadLen == 0 then ok
          else if payloadLen < nlaHeaderLen then erange
          else nestedStatus
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else if kind == kindNestedArrayPolicy then
        let ret :=
          if payloadLen == 0 then ok
          else if payloadLen < nlaHeaderLen then erange
          else nestedArrayStatus
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else
        viewValidatePayload view off policy policyTy kind row payloadLen
          effectiveValidate extack) = ok ↔
      if kind == kindNestedPolicy then
        (if payloadLen == 0 then True
         else if payloadLen < nlaHeaderLen then False
         else nestedAccepted) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraSpec view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else if kind == kindNestedArrayPolicy then
        (if payloadLen == 0 then True
         else if payloadLen < nlaHeaderLen then False
         else nestedArrayAccepted) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraSpec view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else
        PayloadPolicySpec view off policy policyTy kind row payloadLen
          effectiveValidate extack := by
  have hAccepted :=
    knownAttrPostRejectStatus_ok_iff view off policy policyTy kind row
      payloadLen effectiveValidate attr extack nestedStatus nestedArrayStatus
      nestedAccepted nestedArrayAccepted hNested hNestedArray
  have hExtra :
      (if policyMetaValidation row == policyValidateNone then
        True
       else
        PolicyExtraAccepted view off policy policyTy row payloadLen
          effectiveValidate attr extack) ↔
      (if policyMetaValidation row == policyValidateNone then
        True
       else
        PolicyExtraSpec view off policy policyTy row payloadLen
          effectiveValidate attr extack) := by
    by_cases hValidation : policyMetaValidation row == policyValidateNone
    · simp [hValidation]
    · simp [hValidation, policyExtraSpec_iff_accepted]
  have hPayload :
      PayloadAccepted view off policy policyTy kind row payloadLen
          effectiveValidate extack ↔
        PayloadPolicySpec view off policy policyTy kind row payloadLen
          effectiveValidate extack :=
    (payloadPolicySpec_iff_accepted view off policy policyTy kind row
      payloadLen effectiveValidate extack).symm
  refine hAccepted.trans ?_
  by_cases hKindNested : kind == kindNestedPolicy
  · simp only [hKindNested, if_true]
    exact and_congr_right (fun _ => hExtra)
  · by_cases hKindNestedArray : kind == kindNestedArrayPolicy
    · simp only [hKindNested, hKindNestedArray, if_true]
      exact and_congr_right (fun _ => hExtra)
    · simpa [hKindNested, hKindNestedArray] using hPayload

theorem knownAttrPostRejectCore_conforms
    (view : AttrView)
    (off policy policyTy row payloadLen effectiveValidate attr extack depth fuel :
      UInt64)
    (policyRow : PolicyRowView)
    (hNested :
      (let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    (if policyMetaKind row == kindNestedPolicy then
        let ret :=
          if payloadLen == 0 then
            ok
          else if payloadLen < nlaHeaderLen then
            erange
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else if policyMetaKind row == kindNestedArrayPolicy then
        let ret :=
          if payloadLen == 0 then
            ok
          else if payloadLen < nlaHeaderLen then
            erange
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else
        viewValidatePayload view off policy policyTy (policyMetaKind row) row
          payloadLen effectiveValidate extack) = ok ↔
      if policyMetaKind row == kindNestedPolicy then
        (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen nestedMaxtype
            nestedPolicy
            (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
            effectiveValidate extack (depth + 1) 0 nestedTable
            (fuel - 1) 0) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraAccepted view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else if policyMetaKind row == kindNestedArrayPolicy then
        (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
            nestedPolicy effectiveValidate extack depth nestedTable
            (fuel - 1) 0) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraAccepted view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else
        PayloadAccepted view off policy policyTy (policyMetaKind row) row
          payloadLen effectiveValidate extack := by
  exact knownAttrPostRejectStatus_ok_iff view off policy policyTy
    (policyMetaKind row) row payloadLen effectiveValidate attr extack
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
       (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
       effectiveValidate extack (depth + 1) 0 nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
       nestedPolicy effectiveValidate extack depth nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     ValidateLoopAccepted nestedView payloadLen nestedMaxtype nestedPolicy
       (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
       effectiveValidate extack (depth + 1) 0 nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
       nestedPolicy effectiveValidate extack depth nestedTable
       (fuel - 1) 0)
    hNested hNestedArray

theorem knownAttrPostRejectCore_conforms_policy_spec
    (view : AttrView)
    (off policy policyTy row payloadLen effectiveValidate attr extack depth fuel :
      UInt64)
    (policyRow : PolicyRowView)
    (hNested :
      (let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    (if policyMetaKind row == kindNestedPolicy then
        let ret :=
          if payloadLen == 0 then
            ok
          else if payloadLen < nlaHeaderLen then
            erange
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else if policyMetaKind row == kindNestedArrayPolicy then
        let ret :=
          if payloadLen == 0 then
            ok
          else if payloadLen < nlaHeaderLen then
            erange
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0
        if ret == ok then
          if policyMetaValidation row == policyValidateNone then
            ok
          else
            viewValidatePolicyExtra view off policy policyTy row payloadLen
              effectiveValidate attr extack
        else
          ret
      else
        viewValidatePayload view off policy policyTy (policyMetaKind row) row
          payloadLen effectiveValidate extack) = ok ↔
      if policyMetaKind row == kindNestedPolicy then
        (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen nestedMaxtype
            nestedPolicy
            (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
            effectiveValidate extack (depth + 1) 0 nestedTable
            (fuel - 1) 0) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraSpec view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else if policyMetaKind row == kindNestedArrayPolicy then
        (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
            nestedPolicy effectiveValidate extack depth nestedTable
            (fuel - 1) 0) ∧
          if policyMetaValidation row == policyValidateNone then
            True
          else
            PolicyExtraSpec view off policy policyTy row payloadLen
              effectiveValidate attr extack
      else
        PayloadPolicySpec view off policy policyTy (policyMetaKind row) row
          payloadLen effectiveValidate extack := by
  exact knownAttrPostRejectStatus_ok_iff_policy_spec view off policy policyTy
    (policyMetaKind row) row payloadLen effectiveValidate attr extack
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
       (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
       effectiveValidate extack (depth + 1) 0 nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
       nestedPolicy effectiveValidate extack depth nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     ValidateLoopSpec nestedView payloadLen nestedMaxtype nestedPolicy
       (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
       effectiveValidate extack (depth + 1) 0 nestedTable
       (fuel - 1) 0)
    (let nestedPolicy := policyRow.unionPtr
     let nestedMaxtype := policyRow.len
     let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
     let nestedView := view.payloadView off payloadLen
     ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
       nestedPolicy effectiveValidate extack depth nestedTable
       (fuel - 1) 0)
    hNested hNestedArray

theorem reject4ThenCore_ok_iff
    (g1 g2 g3 g4 : Bool)
    (r1 r2 r3 r4 next : UInt64)
    (accepted : Prop)
    (hR1 : r1 ≠ ok)
    (hR2 : r2 ≠ ok)
    (hR3 : r3 ≠ ok)
    (hR4 : r4 ≠ ok)
    (hNext : next = ok ↔ accepted) :
    (if g1 then r1 else if g2 then r2 else if g3 then r3 else if g4 then r4 else next) =
        ok ↔
      if g1 then False else if g2 then False else if g3 then False else
        if g4 then False else accepted := by
  cases g1 <;> cases g2 <;> cases g3 <;> cases g4 <;>
    simp [hR1, hR2, hR3, hR4, hNext]

theorem knownAttrRejectPrefixCore_ok_iff
    (unsupportedAttr nestedMissing nestedUnexpected invalidLen : Bool)
    (attr policy policyTy extack next : UInt64)
    (accepted : Prop)
    (hNext : next = ok ↔ accepted) :
    (if unsupportedAttr then
        keepReported
          (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
          einval
      else if nestedMissing then
        keepReported
          (reportValidateError diagNestedMissing attr policy policyTy extack)
          einval
      else if nestedUnexpected then
        keepReported
          (reportValidateError diagNestedUnexpected attr policy policyTy extack)
          einval
      else if invalidLen then
        keepReported
          (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
          einval
      else
        next) = ok ↔
      if unsupportedAttr then False
      else if nestedMissing then False
      else if nestedUnexpected then False
      else if invalidLen then False
      else accepted :=
  reject4ThenCore_ok_iff
    unsupportedAttr nestedMissing nestedUnexpected invalidLen
    (keepReported
      (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
      einval)
    (keepReported
      (reportValidateError diagNestedMissing attr policy policyTy extack)
      einval)
    (keepReported
      (reportValidateError diagNestedUnexpected attr policy policyTy extack)
      einval)
    (keepReported
      (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
      einval)
    next accepted
    (keepReported_ne_ok_of_status_ne_ok
      (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
      einval (by simp [einval, ok]))
    (keepReported_ne_ok_of_status_ne_ok
      (reportValidateError diagNestedMissing attr policy policyTy extack)
      einval (by simp [einval, ok]))
    (keepReported_ne_ok_of_status_ne_ok
      (reportValidateError diagNestedUnexpected attr policy policyTy extack)
      einval (by simp [einval, ok]))
    (keepReported_ne_ok_of_status_ne_ok
      (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
      einval (by simp [einval, ok]))
    hNext

theorem knownAttrVerdictCore_conforms
    (view : AttrView)
    (off policy policyTy row len nested effectiveValidate attr extack depth fuel :
      UInt64)
    (policyRow : PolicyRowView)
    (hNested :
      (let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    (let kind := policyMetaKind row
     let hasPolicy := policy != 0
     let checkUnspec := hasFlag effectiveValidate validateUnspec
     let checkNested := hasFlag effectiveValidate validateNested
     let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
     let kindIsNested := isNestedKind kind
     let rowValidation := policyMetaValidation row
     let payloadLen := len - nlaHeaderLen
     let needUnspec :=
       hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
     let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
     if hasPolicy && checkUnspec && isUnspec != 0 then
       keepReported
         (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
         einval
     else if hasPolicy && checkNested && kindIsNested && nested == 0 then
       keepReported
         (reportValidateError diagNestedMissing attr policy policyTy extack)
         einval
     else if hasPolicy && checkNested &&
         !kindIsNested && isUnspec == 0 && nested != 0 then
       keepReported
         (reportValidateError diagNestedUnexpected attr policy policyTy extack)
         einval
     else
       let strictLen := policyMetaStrictLen row
       if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
         keepReported
           (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
           einval
       else if kind == kindNestedPolicy then
         let ret :=
           if payloadLen == 0 then
             ok
           else if payloadLen < nlaHeaderLen then
             erange
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
               (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
               effectiveValidate extack (depth + 1) 0 nestedTable
               (fuel - 1) 0
         if ret == ok then
           if rowValidation == policyValidateNone then
             ok
           else
             viewValidatePolicyExtra view off policy policyTy row payloadLen
               effectiveValidate attr extack
         else
           ret
       else if kind == kindNestedArrayPolicy then
         let ret :=
           if payloadLen == 0 then
             ok
           else if payloadLen < nlaHeaderLen then
             erange
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
               nestedPolicy effectiveValidate extack depth nestedTable
               (fuel - 1) 0
         if ret == ok then
           if rowValidation == policyValidateNone then
             ok
           else
             viewValidatePolicyExtra view off policy policyTy row payloadLen
               effectiveValidate attr extack
         else
           ret
       else
         viewValidatePayload view off policy policyTy kind row payloadLen
           effectiveValidate extack) = ok ↔
      (let kind := policyMetaKind row
       let hasPolicy := policy != 0
       let checkUnspec := hasFlag effectiveValidate validateUnspec
       let checkNested := hasFlag effectiveValidate validateNested
       let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
       let kindIsNested := isNestedKind kind
       let payloadLen := len - nlaHeaderLen
       let needUnspec :=
         hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
       let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
       if hasPolicy && checkUnspec && isUnspec != 0 then
         False
       else if hasPolicy && checkNested && kindIsNested && nested == 0 then
         False
       else if hasPolicy && checkNested &&
           !kindIsNested && isUnspec == 0 && nested != 0 then
         False
       else
         let strictLen := policyMetaStrictLen row
         if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
           False
         else if kind == kindNestedPolicy then
           (if payloadLen == 0 then
             True
           else if payloadLen < nlaHeaderLen then
             False
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             ValidateLoopAccepted nestedView payloadLen nestedMaxtype
               nestedPolicy
               (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
               effectiveValidate extack (depth + 1) 0 nestedTable
               (fuel - 1) 0) ∧
             if policyMetaValidation row == policyValidateNone then
               True
             else
               PolicyExtraAccepted view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else if kind == kindNestedArrayPolicy then
           (if payloadLen == 0 then
             True
           else if payloadLen < nlaHeaderLen then
             False
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
               nestedPolicy effectiveValidate extack depth nestedTable
               (fuel - 1) 0) ∧
             if policyMetaValidation row == policyValidateNone then
               True
             else
               PolicyExtraAccepted view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else
           PayloadAccepted view off policy policyTy kind row payloadLen
             effectiveValidate extack) := by
  let kind := policyMetaKind row
  let hasPolicy := policy != 0
  let checkUnspec := hasFlag effectiveValidate validateUnspec
  let checkNested := hasFlag effectiveValidate validateNested
  let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
  let kindIsNested := isNestedKind kind
  let payloadLen := len - nlaHeaderLen
  let needUnspec :=
    hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
  let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
  let strictLen := policyMetaStrictLen row
  have hPost :
      (if kind == kindNestedPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                effectiveValidate extack (depth + 1) 0 nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else if kind == kindNestedArrayPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                nestedPolicy effectiveValidate extack depth nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else
          viewValidatePayload view off policy policyTy kind row payloadLen
            effectiveValidate extack) = ok ↔
        if kind == kindNestedPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateLoopAccepted nestedView payloadLen nestedMaxtype
              nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraAccepted view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else if kind == kindNestedArrayPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraAccepted view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else
          PayloadAccepted view off policy policyTy kind row payloadLen
            effectiveValidate extack := by
    exact knownAttrPostRejectCore_conforms view off policy policyTy row
      payloadLen effectiveValidate attr extack depth fuel policyRow
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNestedArray)
  have hPrefix :=
    knownAttrRejectPrefixCore_ok_iff
      (hasPolicy && checkUnspec && isUnspec != 0)
      (hasPolicy && checkNested && kindIsNested && nested == 0)
      (hasPolicy && checkNested && !kindIsNested && isUnspec == 0 &&
        nested != 0)
      (checkStrictAttrs && strictLen != 0 && payloadLen != strictLen)
      attr policy policyTy extack
      (if kind == kindNestedPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                effectiveValidate extack (depth + 1) 0 nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else if kind == kindNestedArrayPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                nestedPolicy effectiveValidate extack depth nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else
          viewValidatePayload view off policy policyTy kind row payloadLen
            effectiveValidate extack)
      (if kind == kindNestedPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateLoopAccepted nestedView payloadLen nestedMaxtype
              nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraAccepted view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else if kind == kindNestedArrayPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraAccepted view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else
          PayloadAccepted view off policy policyTy kind row payloadLen
            effectiveValidate extack)
      hPost
  simpa only [kind, hasPolicy, checkUnspec, checkNested, checkStrictAttrs,
    kindIsNested, payloadLen, needUnspec, isUnspec, strictLen] using hPrefix

theorem knownAttrVerdictCore_conforms_policy_spec
    (view : AttrView)
    (off policy policyTy row len nested effectiveValidate attr extack depth fuel :
      UInt64)
    (policyRow : PolicyRowView)
    (hNested :
      (let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    (let kind := policyMetaKind row
     let hasPolicy := policy != 0
     let checkUnspec := hasFlag effectiveValidate validateUnspec
     let checkNested := hasFlag effectiveValidate validateNested
     let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
     let kindIsNested := isNestedKind kind
     let rowValidation := policyMetaValidation row
     let payloadLen := len - nlaHeaderLen
     let needUnspec :=
       hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
     let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
     if hasPolicy && checkUnspec && isUnspec != 0 then
       keepReported
         (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
         einval
     else if hasPolicy && checkNested && kindIsNested && nested == 0 then
       keepReported
         (reportValidateError diagNestedMissing attr policy policyTy extack)
         einval
     else if hasPolicy && checkNested &&
         !kindIsNested && isUnspec == 0 && nested != 0 then
       keepReported
         (reportValidateError diagNestedUnexpected attr policy policyTy extack)
         einval
     else
       let strictLen := policyMetaStrictLen row
       if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
         keepReported
           (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
           einval
       else if kind == kindNestedPolicy then
         let ret :=
           if payloadLen == 0 then
             ok
           else if payloadLen < nlaHeaderLen then
             erange
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
               (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
               effectiveValidate extack (depth + 1) 0 nestedTable
               (fuel - 1) 0
         if ret == ok then
           if rowValidation == policyValidateNone then
             ok
           else
             viewValidatePolicyExtra view off policy policyTy row payloadLen
               effectiveValidate attr extack
         else
           ret
       else if kind == kindNestedArrayPolicy then
         let ret :=
           if payloadLen == 0 then
             ok
           else if payloadLen < nlaHeaderLen then
             erange
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
               nestedPolicy effectiveValidate extack depth nestedTable
               (fuel - 1) 0
         if ret == ok then
           if rowValidation == policyValidateNone then
             ok
           else
             viewValidatePolicyExtra view off policy policyTy row payloadLen
               effectiveValidate attr extack
         else
           ret
       else
         viewValidatePayload view off policy policyTy kind row payloadLen
           effectiveValidate extack) = ok ↔
      (let kind := policyMetaKind row
       let hasPolicy := policy != 0
       let checkUnspec := hasFlag effectiveValidate validateUnspec
       let checkNested := hasFlag effectiveValidate validateNested
       let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
       let kindIsNested := isNestedKind kind
       let payloadLen := len - nlaHeaderLen
       let needUnspec :=
         hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
       let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
       if hasPolicy && checkUnspec && isUnspec != 0 then
         False
       else if hasPolicy && checkNested && kindIsNested && nested == 0 then
         False
       else if hasPolicy && checkNested &&
           !kindIsNested && isUnspec == 0 && nested != 0 then
         False
       else
         let strictLen := policyMetaStrictLen row
         if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
           False
         else if kind == kindNestedPolicy then
           (if payloadLen == 0 then
             True
           else if payloadLen < nlaHeaderLen then
             False
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             ValidateLoopSpec nestedView payloadLen nestedMaxtype
               nestedPolicy
               (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
               effectiveValidate extack (depth + 1) 0 nestedTable
               (fuel - 1) 0) ∧
             if policyMetaValidation row == policyValidateNone then
               True
             else
               PolicyExtraSpec view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else if kind == kindNestedArrayPolicy then
           (if payloadLen == 0 then
             True
           else if payloadLen < nlaHeaderLen then
             False
           else
             let nestedPolicy := policyRow.unionPtr
             let nestedMaxtype := policyRow.len
             let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
             let nestedView := view.payloadView off payloadLen
             ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
               nestedPolicy effectiveValidate extack depth nestedTable
               (fuel - 1) 0) ∧
             if policyMetaValidation row == policyValidateNone then
               True
             else
               PolicyExtraSpec view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else
           PayloadPolicySpec view off policy policyTy kind row payloadLen
             effectiveValidate extack) := by
  let kind := policyMetaKind row
  let hasPolicy := policy != 0
  let checkUnspec := hasFlag effectiveValidate validateUnspec
  let checkNested := hasFlag effectiveValidate validateNested
  let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
  let kindIsNested := isNestedKind kind
  let payloadLen := len - nlaHeaderLen
  let needUnspec :=
    hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
  let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
  let strictLen := policyMetaStrictLen row
  have hPost :
      (if kind == kindNestedPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                effectiveValidate extack (depth + 1) 0 nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else if kind == kindNestedArrayPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                nestedPolicy effectiveValidate extack depth nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else
          viewValidatePayload view off policy policyTy kind row payloadLen
            effectiveValidate extack) = ok ↔
        if kind == kindNestedPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateLoopSpec nestedView payloadLen nestedMaxtype
              nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraSpec view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else if kind == kindNestedArrayPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraSpec view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else
          PayloadPolicySpec view off policy policyTy kind row payloadLen
            effectiveValidate extack := by
    exact knownAttrPostRejectCore_conforms_policy_spec view off policy policyTy
      row payloadLen effectiveValidate attr extack depth fuel policyRow
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNestedArray)
  have hPrefix :=
    knownAttrRejectPrefixCore_ok_iff
      (hasPolicy && checkUnspec && isUnspec != 0)
      (hasPolicy && checkNested && kindIsNested && nested == 0)
      (hasPolicy && checkNested && !kindIsNested && isUnspec == 0 &&
        nested != 0)
      (checkStrictAttrs && strictLen != 0 && payloadLen != strictLen)
      attr policy policyTy extack
      (if kind == kindNestedPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                effectiveValidate extack (depth + 1) 0 nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else if kind == kindNestedArrayPolicy then
          let ret :=
            if payloadLen == 0 then
              ok
            else if payloadLen < nlaHeaderLen then
              erange
            else
              let nestedPolicy := policyRow.unionPtr
              let nestedMaxtype := policyRow.len
              let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
              let nestedView := view.payloadView off payloadLen
              viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                nestedPolicy effectiveValidate extack depth nestedTable
                (fuel - 1) 0
          if ret == ok then
            if policyMetaValidation row == policyValidateNone then
              ok
            else
              viewValidatePolicyExtra view off policy policyTy row payloadLen
                effectiveValidate attr extack
          else
            ret
        else
          viewValidatePayload view off policy policyTy kind row payloadLen
            effectiveValidate extack)
      (if kind == kindNestedPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateLoopSpec nestedView payloadLen nestedMaxtype
              nestedPolicy
              (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
              effectiveValidate extack (depth + 1) 0 nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraSpec view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else if kind == kindNestedArrayPolicy then
          (if payloadLen == 0 then
            True
          else if payloadLen < nlaHeaderLen then
            False
          else
            let nestedPolicy := policyRow.unionPtr
            let nestedMaxtype := policyRow.len
            let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
            let nestedView := view.payloadView off payloadLen
            ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
              nestedPolicy effectiveValidate extack depth nestedTable
              (fuel - 1) 0) ∧
            if policyMetaValidation row == policyValidateNone then
              True
            else
              PolicyExtraSpec view off policy policyTy row payloadLen
                effectiveValidate attr extack
        else
          PayloadPolicySpec view off policy policyTy kind row payloadLen
            effectiveValidate extack)
      hPost
  simpa only [kind, hasPolicy, checkUnspec, checkNested, checkStrictAttrs,
    kindIsNested, payloadLen, needUnspec, isUnspec, strictLen] using hPrefix

def loopKnownVerdict
    (view : AttrView)
    (maxtype policy strictStart validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView) : UInt64 :=
  let header := view.header off
  let len := attrHeaderLen header
  let ty := attrHeaderType header
  let nested := attrHeaderIsNested header
  let policyTy := arrayIndexNospec ty (maxtype + 1)
  let policyRow := policyTable.row policyTy
  let row :=
    if policy == 0 then policyMetaAccept
    else policyMetaFromRow policy policyTy policyRow
  let kind := policyMetaKind row
  let effectiveValidate := withStrictStart strictStart ty validate
  let hasPolicy := policy != 0
  let checkUnspec := hasFlag effectiveValidate validateUnspec
  let checkNested := hasFlag effectiveValidate validateNested
  let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
  let kindIsNested := isNestedKind kind
  let attr := view.ptr off
  let rowValidation := policyMetaValidation row
  let payloadLen := len - nlaHeaderLen
  let needUnspec :=
    hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
  let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
  if hasPolicy && checkUnspec && isUnspec != 0 then
    keepReported
      (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
      einval
  else if hasPolicy && checkNested && kindIsNested && nested == 0 then
    keepReported
      (reportValidateError diagNestedMissing attr policy policyTy extack)
      einval
  else if hasPolicy && checkNested &&
      !kindIsNested && isUnspec == 0 && nested != 0 then
    keepReported
      (reportValidateError diagNestedUnexpected attr policy policyTy extack)
      einval
  else
    let strictLen := policyMetaStrictLen row
    if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
      keepReported
        (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
        einval
    else if kind == kindNestedPolicy then
      let ret :=
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
            (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
            effectiveValidate extack (depth + 1) 0 nestedTable
            (fuel - 1) 0
      if ret == ok then
        if rowValidation == policyValidateNone then
          ok
        else
          viewValidatePolicyExtra view off policy policyTy row payloadLen
            effectiveValidate attr extack
      else
        ret
    else if kind == kindNestedArrayPolicy then
      let ret :=
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
            nestedPolicy effectiveValidate extack depth nestedTable
            (fuel - 1) 0
      if ret == ok then
        if rowValidation == policyValidateNone then
          ok
        else
          viewValidatePolicyExtra view off policy policyTy row payloadLen
            effectiveValidate attr extack
      else
        ret
    else
      viewValidatePayload view off policy policyTy kind row payloadLen
        effectiveValidate extack

def LoopKnownVerdictAccepted
    (view : AttrView)
    (maxtype policy strictStart validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView) : Prop :=
  let header := view.header off
  let len := attrHeaderLen header
  let ty := attrHeaderType header
  let nested := attrHeaderIsNested header
  let policyTy := arrayIndexNospec ty (maxtype + 1)
  let policyRow := policyTable.row policyTy
  let row :=
    if policy == 0 then policyMetaAccept
    else policyMetaFromRow policy policyTy policyRow
  let kind := policyMetaKind row
  let effectiveValidate := withStrictStart strictStart ty validate
  let hasPolicy := policy != 0
  let checkUnspec := hasFlag effectiveValidate validateUnspec
  let checkNested := hasFlag effectiveValidate validateNested
  let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
  let kindIsNested := isNestedKind kind
  let attr := view.ptr off
  let rowValidation := policyMetaValidation row
  let payloadLen := len - nlaHeaderLen
  let needUnspec :=
    hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
  let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
  if hasPolicy && checkUnspec && isUnspec != 0 then
    False
  else if hasPolicy && checkNested && kindIsNested && nested == 0 then
    False
  else if hasPolicy && checkNested &&
      !kindIsNested && isUnspec == 0 && nested != 0 then
    False
  else
    let strictLen := policyMetaStrictLen row
    if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
      False
    else if kind == kindNestedPolicy then
      let nestedAccepted :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen nestedMaxtype
            nestedPolicy
            (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
            effectiveValidate extack (depth + 1) 0 nestedTable
            (fuel - 1) 0
      nestedAccepted ∧
        if rowValidation == policyValidateNone then
          True
        else
          PolicyExtraAccepted view off policy policyTy row payloadLen
            effectiveValidate attr extack
    else if kind == kindNestedArrayPolicy then
      let nestedAccepted :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
            nestedPolicy effectiveValidate extack depth nestedTable
            (fuel - 1) 0
      nestedAccepted ∧
        if rowValidation == policyValidateNone then
          True
        else
          PolicyExtraAccepted view off policy policyTy row payloadLen
            effectiveValidate attr extack
    else
      PayloadAccepted view off policy policyTy kind row payloadLen
        effectiveValidate extack

def LoopKnownVerdictSpec
    (view : AttrView)
    (maxtype policy strictStart validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView) : Prop :=
  let header := view.header off
  let len := attrHeaderLen header
  let ty := attrHeaderType header
  let nested := attrHeaderIsNested header
  let policyTy := arrayIndexNospec ty (maxtype + 1)
  let policyRow := policyTable.row policyTy
  let row :=
    if policy == 0 then policyMetaAccept
    else policyMetaFromRow policy policyTy policyRow
  let kind := policyMetaKind row
  let effectiveValidate := withStrictStart strictStart ty validate
  let hasPolicy := policy != 0
  let checkUnspec := hasFlag effectiveValidate validateUnspec
  let checkNested := hasFlag effectiveValidate validateNested
  let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
  let kindIsNested := isNestedKind kind
  let attr := view.ptr off
  let rowValidation := policyMetaValidation row
  let payloadLen := len - nlaHeaderLen
  let needUnspec :=
    hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
  let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
  if hasPolicy && checkUnspec && isUnspec != 0 then
    False
  else if hasPolicy && checkNested && kindIsNested && nested == 0 then
    False
  else if hasPolicy && checkNested &&
      !kindIsNested && isUnspec == 0 && nested != 0 then
    False
  else
    let strictLen := policyMetaStrictLen row
    if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
      False
    else if kind == kindNestedPolicy then
      let nestedSpec :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen nestedMaxtype
            nestedPolicy
            (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
            effectiveValidate extack (depth + 1) 0 nestedTable
            (fuel - 1) 0
      nestedSpec ∧
        if rowValidation == policyValidateNone then
          True
        else
          PolicyExtraSpec view off policy policyTy row payloadLen
            effectiveValidate attr extack
    else if kind == kindNestedArrayPolicy then
      let nestedSpec :=
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedPolicy := policyRow.unionPtr
          let nestedMaxtype := policyRow.len
          let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
          let nestedView := view.payloadView off payloadLen
          ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
            nestedPolicy effectiveValidate extack depth nestedTable
            (fuel - 1) 0
      nestedSpec ∧
        if rowValidation == policyValidateNone then
          True
        else
          PolicyExtraSpec view off policy policyTy row payloadLen
            effectiveValidate attr extack
    else
      PayloadPolicySpec view off policy policyTy kind row payloadLen
        effectiveValidate extack

theorem loopKnownVerdict_conforms_from_nested
    (view : AttrView)
    (maxtype policy strictStart validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hNested :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    loopKnownVerdict view maxtype policy strictStart validate extack depth fuel
        off policyTable = ok ↔
      LoopKnownVerdictAccepted view maxtype policy strictStart validate extack
        depth fuel off policyTable := by
  let header := view.header off
  let len := attrHeaderLen header
  let ty := attrHeaderType header
  let nested := attrHeaderIsNested header
  let policyTy := arrayIndexNospec ty (maxtype + 1)
  let policyRow := policyTable.row policyTy
  let row :=
    if policy == 0 then policyMetaAccept
    else policyMetaFromRow policy policyTy policyRow
  let effectiveValidate := withStrictStart strictStart ty validate
  let attr := view.ptr off
  simpa only [loopKnownVerdict, LoopKnownVerdictAccepted, header, len, ty,
    nested, policyTy, policyRow, row, effectiveValidate, attr,
    boolDite_eq_ite] using
    knownAttrVerdictCore_conforms view off policy policyTy row len nested
      effectiveValidate attr extack depth fuel policyRow
      (by
        simpa only [header, len, ty, policyTy, policyRow, effectiveValidate,
          boolDite_eq_ite] using hNested)
      (by
        simpa only [header, len, ty, policyTy, policyRow, effectiveValidate,
          boolDite_eq_ite] using hNestedArray)

theorem loopKnownVerdict_conforms_spec_from_nested
    (view : AttrView)
    (maxtype policy strictStart validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hNested :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0)) :
    loopKnownVerdict view maxtype policy strictStart validate extack depth fuel
        off policyTable = ok ↔
      LoopKnownVerdictSpec view maxtype policy strictStart validate extack
        depth fuel off policyTable := by
  let header := view.header off
  let len := attrHeaderLen header
  let ty := attrHeaderType header
  let nested := attrHeaderIsNested header
  let policyTy := arrayIndexNospec ty (maxtype + 1)
  let policyRow := policyTable.row policyTy
  let row :=
    if policy == 0 then policyMetaAccept
    else policyMetaFromRow policy policyTy policyRow
  let effectiveValidate := withStrictStart strictStart ty validate
  let attr := view.ptr off
  simpa only [loopKnownVerdict, LoopKnownVerdictSpec, header, len, ty,
    nested, policyTy, policyRow, row, effectiveValidate, attr,
    boolDite_eq_ite] using
    knownAttrVerdictCore_conforms_policy_spec view off policy policyTy row len
      nested effectiveValidate attr extack depth fuel policyRow
      (by
        simpa only [header, len, ty, policyTy, policyRow, effectiveValidate,
          boolDite_eq_ite] using hNested)
      (by
        simpa only [header, len, ty, policyTy, policyRow, effectiveValidate,
          boolDite_eq_ite] using hNestedArray)

theorem reportedEinval_ne_ok
    (reason attr policy ty extack : UInt64) :
    keepReported (reportValidateError reason attr policy ty extack) einval ≠
      ok :=
  keepReported_ne_ok_of_status_ne_ok
    (reportValidateError reason attr policy ty extack)
    einval
    (by simp [einval, ok])

theorem rejectThen_ok_iff
    (guard : Bool) (reject next : UInt64) (accepted : Prop)
    (hReject : reject ≠ ok)
    (hNext : next = ok ↔ accepted) :
    (if guard then reject else next) = ok ↔
      if guard then False else accepted := by
  cases guard
  · simpa using hNext
  · simp [hReject]

theorem reportedRejectThen_ok_iff
    (guard : Bool) (reason attr policy ty extack next : UInt64)
    (accepted : Prop)
    (hNext : next = ok ↔ accepted) :
    (if guard then
        keepReported (reportValidateError reason attr policy ty extack) einval
      else
        next) = ok ↔
      if guard then False else accepted :=
  rejectThen_ok_iff guard
    (keepReported (reportValidateError reason attr policy ty extack) einval)
    next accepted
    (reportedEinval_ne_ok reason attr policy ty extack)
    hNext

theorem reject4Then_ok_iff
    (g1 g2 g3 g4 : Bool)
    (r1 r2 r3 r4 next : UInt64)
    (accepted : Prop)
    (hR1 : r1 ≠ ok)
    (hR2 : r2 ≠ ok)
    (hR3 : r3 ≠ ok)
    (hR4 : r4 ≠ ok)
    (hNext : next = ok ↔ accepted) :
    (if g1 then r1 else if g2 then r2 else if g3 then r3 else if g4 then r4 else next) =
        ok ↔
      if g1 then False else if g2 then False else if g3 then False else
        if g4 then False else accepted := by
  cases g1 <;> cases g2 <;> cases g3 <;> cases g4 <;>
    simp [hR1, hR2, hR3, hR4, hNext]

theorem reportedReject4Then_ok_iff
    (g1 g2 g3 g4 : Bool)
    (reason1 reason2 reason3 reason4 attr policy ty extack next : UInt64)
    (accepted : Prop)
    (hNext : next = ok ↔ accepted) :
    (if g1 then
        keepReported (reportValidateError reason1 attr policy ty extack) einval
      else if g2 then
        keepReported (reportValidateError reason2 attr policy ty extack) einval
      else if g3 then
        keepReported (reportValidateError reason3 attr policy ty extack) einval
      else if g4 then
        keepReported (reportValidateError reason4 attr policy ty extack) einval
      else
        next) = ok ↔
      if g1 then False else if g2 then False else if g3 then False else
        if g4 then False else accepted :=
  reject4Then_ok_iff g1 g2 g3 g4
    (keepReported (reportValidateError reason1 attr policy ty extack) einval)
    (keepReported (reportValidateError reason2 attr policy ty extack) einval)
    (keepReported (reportValidateError reason3 attr policy ty extack) einval)
    (keepReported (reportValidateError reason4 attr policy ty extack) einval)
    next accepted
    (reportedEinval_ne_ok reason1 attr policy ty extack)
    (reportedEinval_ne_ok reason2 attr policy ty extack)
    (reportedEinval_ne_ok reason3 attr policy ty extack)
    (reportedEinval_ne_ok reason4 attr policy ty extack)
    hNext

theorem knownAttrRejectPrefix_ok_iff
    (unsupportedAttr nestedMissing nestedUnexpected invalidLen : Bool)
    (attr policy policyTy extack next : UInt64)
    (accepted : Prop)
    (hNext : next = ok ↔ accepted) :
    (if unsupportedAttr then
        keepReported
          (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
          einval
      else if nestedMissing then
        keepReported
          (reportValidateError diagNestedMissing attr policy policyTy extack)
          einval
      else if nestedUnexpected then
        keepReported
          (reportValidateError diagNestedUnexpected attr policy policyTy extack)
          einval
      else if invalidLen then
        keepReported
          (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
          einval
      else
        next) = ok ↔
      if unsupportedAttr then False
      else if nestedMissing then False
      else if nestedUnexpected then False
      else if invalidLen then False
      else accepted :=
  reportedReject4Then_ok_iff
    unsupportedAttr nestedMissing nestedUnexpected invalidLen
    diagUnsupportedAttr diagNestedMissing diagNestedUnexpected diagInvalidAttrLen
    attr policy policyTy extack next accepted hNext

theorem ValidateForeignEffectsOk.reportTrailing_ok_iff
    (effects : ValidateForeignEffectsOk) (validate extack : UInt64) :
    reportTrailingResult validate extack = ok ↔
      (hasFlag validate validateTrailing) = false := by
  rw [reportTrailingResult_ok_iff]
  simp [effects.reports diagTrailingBytes 0 0 0 extack]

theorem ValidateForeignEffectsOk.keepReport_status
    (effects : ValidateForeignEffectsOk)
    (reason attr policy ty extack status : UInt64) :
    keepReported (reportValidateError reason attr policy ty extack) status =
      status := by
  unfold keepReported
  have hNe := effects.reports reason attr policy ty extack
  have hNeProp :
      reportValidateError reason attr policy ty extack ≠ u64Max := by
    intro hEq
    simp [hEq] at hNe
  simp [hNeProp]

theorem ValidateForeignEffectsOk.keepReport_ok_iff
    (effects : ValidateForeignEffectsOk)
    (reason attr policy ty extack status : UInt64) :
    keepReported (reportValidateError reason attr policy ty extack) status =
        ok ↔
      status = ok := by
  rw [effects.keepReport_status reason attr policy ty extack status]

theorem ValidateForeignEffectsOk.tableWriteAccepted
    (effects : ValidateForeignEffectsOk) (tb ty attr : UInt64) :
    TableWriteAccepted tb ty attr := by
  unfold TableWriteAccepted
  by_cases hTb : tb == 0
  · simp [hTb]
  · have hTbNe : tb != 0 := by
      simpa using hTb
    simp [hTb, effects.tableWrites tb ty attr hTbNe]

theorem ValidateForeignEffectsOk.knownAttrWriteAccepted
    (effects : ValidateForeignEffectsOk) (tb ty maxtype attr : UInt64) :
    KnownAttrWriteAccepted tb ty maxtype attr := by
  unfold KnownAttrWriteAccepted
  exact effects.tableWriteAccepted tb (arrayIndexNospec ty (maxtype + 1)) attr

theorem viewValidateLoop_fuel_zero_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb off : UInt64)
    (policyTable : PolicyTableView) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable 0 off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable 0 off := by
  simp [viewValidateLoop, ValidateLoopAccepted, unsupported, ok]

theorem viewValidateNestedArrayLoop_fuel_zero_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth off : UInt64)
    (policyTable : PolicyTableView) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable 0 off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable 0 off := by
  simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, unsupported,
    ok]

theorem viewValidateNestedArrayLoop_end_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : off = totalLen) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  subst off
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuelNe, ok]

theorem viewValidateNestedArrayLoop_short_header_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuelNe,
    hOff, hHeader, ok]

theorem viewValidateNestedArrayLoop_bad_len_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuelNe,
    hOff, hHeader, hLen, ok]

theorem viewValidateNestedArrayLoop_overrun_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuelNe,
    hOff, hHeader, hLen, hOverrun, ok]

theorem viewValidateNestedArrayLoop_fuel_zero_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth off : UInt64)
    (policyTable : PolicyTableView) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable 0 off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable 0 off := by
  simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, unsupported, ok]

theorem viewValidateNestedArrayLoop_end_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : off = totalLen) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  subst off
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, hFuelNe, ok]

theorem viewValidateNestedArrayLoop_short_header_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, hFuelNe, hOff,
    hHeader, ok]

theorem viewValidateNestedArrayLoop_bad_len_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, hFuelNe, hOff,
    hHeader, hLen, ok]

theorem viewValidateNestedArrayLoop_overrun_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = true) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, hFuelNe, hOff,
    hHeader, hLen, hOverrun, ok]

theorem viewValidateNestedArrayLoop_step_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdict :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       if payloadLen == 0 then
         ok
       else if payloadLen < nlaHeaderLen then
         erange
       else
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         viewValidateLoop nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         if payloadLen == 0 then
           True
         else if payloadLen < nlaHeaderLen then
           False
         else
           let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
           let nestedView := view.payloadView off payloadLen
           ValidateLoopAccepted nestedView payloadLen maxtype policy
             nestedStrictStart validate extack (depth + 1) 0 policyTable
             (fuel - 1) 0))
    (hRecur :
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArrayAccepted]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  exact statusThenIf_ok_iff
    (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
     if payloadLen == 0 then
       ok
     else if payloadLen < nlaHeaderLen then
       erange
     else
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
    (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
      depth policyTable (fuel - 1)
      (off + align4 (attrHeaderLen (view.header off))))
    (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
     if payloadLen == 0 then
       True
     else if payloadLen < nlaHeaderLen then
       False
     else
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopAccepted nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
    (ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
      depth policyTable (fuel - 1)
      (off + align4 (attrHeaderLen (view.header off))))
    (off + align4 (attrHeaderLen (view.header off)) > totalLen)
    hVerdict hRecur

theorem viewValidateNestedArrayLoop_step_conforms_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0))
    (hRecur :
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  exact viewValidateNestedArrayLoop_step_conforms view totalLen maxtype policy
    validate extack depth fuel off policyTable hFuel hOff hHeader hLen hOverrun
    (by
      let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
      exact nestedRet_ok_iff payloadLen
        (let nestedStrictStart :=
          if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         viewValidateLoop nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)
        (let nestedStrictStart :=
          if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)
        (by simpa only [payloadLen, boolDite_eq_ite] using hNested))
    hRecur

theorem viewValidateNestedArrayLoop_step_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdict :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       if payloadLen == 0 then
         ok
       else if payloadLen < nlaHeaderLen then
         erange
       else
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         viewValidateLoop nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         if payloadLen == 0 then
           True
         else if payloadLen < nlaHeaderLen then
           False
         else
           let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
           let nestedView := view.payloadView off payloadLen
           ValidateLoopSpec nestedView payloadLen maxtype policy
             nestedStrictStart validate extack (depth + 1) 0 policyTable
             (fuel - 1) 0))
    (hRecur :
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateNestedArraySpec view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArraySpec]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  exact statusThenIf_ok_iff
    (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
     if payloadLen == 0 then
       ok
     else if payloadLen < nlaHeaderLen then
       erange
     else
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
    (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
      depth policyTable (fuel - 1)
      (off + align4 (attrHeaderLen (view.header off))))
    (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
     if payloadLen == 0 then
       True
     else if payloadLen < nlaHeaderLen then
       False
     else
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopSpec nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
    (ValidateNestedArraySpec view totalLen maxtype policy validate extack
      depth policyTable (fuel - 1)
      (off + align4 (attrHeaderLen (view.header off))))
    (off + align4 (attrHeaderLen (view.header off)) > totalLen)
    hVerdict hRecur

theorem viewValidateNestedArrayLoop_step_conforms_spec_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0))
    (hRecur :
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateNestedArraySpec view totalLen maxtype policy validate extack
          depth policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  exact viewValidateNestedArrayLoop_step_conforms_spec view totalLen maxtype
    policy validate extack depth fuel off policyTable hFuel hOff hHeader hLen
    hOverrun
    (by
      let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
      exact nestedRet_ok_iff payloadLen
        (let nestedStrictStart :=
          if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         viewValidateLoop nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)
        (let nestedStrictStart :=
          if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)
        (by simpa only [payloadLen, boolDite_eq_ite] using hNested))
    hRecur

theorem viewValidateNestedArrayLoop_verdict_reject_conforms_spec_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdictReject :
      ((let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) != ok) = true)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArraySpec]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
  have hVerdict :
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) = ok ↔
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0 :=
    nestedRet_ok_iff payloadLen
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopSpec nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
  simpa only [payloadLen] using
    statusThenIf_status_reject_ok_iff
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict
      (by simpa only [payloadLen] using hVerdictReject)

theorem viewValidateNestedArrayLoop_done_conforms_spec_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdictOk :
      ((let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) != ok) = false)
    (hDone : off + align4 (attrHeaderLen (view.header off)) > totalLen)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArraySpec]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
  have hVerdict :
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) = ok ↔
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0 :=
    nestedRet_ok_iff payloadLen
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopSpec nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
  simpa only [payloadLen] using
    statusThenIf_done_ok_iff
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopSpec nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (ValidateNestedArraySpec view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict
      (by simpa only [payloadLen] using hVerdictOk)
      hDone

theorem viewValidateNestedArrayLoop_verdict_reject_conforms_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdictReject :
      ((let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) != ok) = true)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArrayAccepted]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
  have hVerdict :
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) = ok ↔
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0 :=
    nestedRet_ok_iff payloadLen
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopAccepted nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
  simpa only [payloadLen] using
    statusThenIf_status_reject_ok_iff
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict
      (by simpa only [payloadLen] using hVerdictReject)

theorem viewValidateNestedArrayLoop_done_conforms_from_nested
    (view : AttrView)
    (totalLen maxtype policy validate extack depth fuel off : UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hVerdictOk :
      ((let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
        if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) != ok) = false)
    (hDone : off + align4 (attrHeaderLen (view.header off)) > totalLen)
    (hNested :
      (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
       let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0) = ok ↔
        (let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
         let nestedStrictStart := if policy == 0 then 0 else policyStrictStart policy
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen maxtype policy
           nestedStrictStart validate extack (depth + 1) 0 policyTable
           (fuel - 1) 0)) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateNestedArrayLoop]
  rw (occs := .pos [1]) [ValidateNestedArrayAccepted]
  simp only [hFuelNe, hOff, hHeader, hLen, hOverrun, Bool.false_eq_true,
    if_false, dite_false]
  let payloadLen := attrHeaderLen (view.header off) - nlaHeaderLen
  have hVerdict :
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0) = ok ↔
        if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0 :=
    nestedRet_ok_iff payloadLen
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (let nestedStrictStart :=
        if policy == 0 then 0 else policyStrictStart policy
       let nestedView := view.payloadView off payloadLen
       ValidateLoopAccepted nestedView payloadLen maxtype policy
         nestedStrictStart validate extack (depth + 1) 0 policyTable
         (fuel - 1) 0)
      (by simpa only [payloadLen, boolDite_eq_ite] using hNested)
  simpa only [payloadLen] using
    statusThenIf_done_ok_iff
      (if payloadLen == 0 then
          ok
        else if payloadLen < nlaHeaderLen then
          erange
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          viewValidateLoop nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (if payloadLen == 0 then
          True
        else if payloadLen < nlaHeaderLen then
          False
        else
          let nestedStrictStart :=
            if policy == 0 then 0 else policyStrictStart policy
          let nestedView := view.payloadView off payloadLen
          ValidateLoopAccepted nestedView payloadLen maxtype policy
            nestedStrictStart validate extack (depth + 1) 0 policyTable
            (fuel - 1) 0)
      (ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict
      (by simpa only [payloadLen] using hVerdictOk)
      hDone

theorem viewValidateLoop_depth_limit_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : depth >= maxPolicyRecursionDepth) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth]
  exact keepReported_ne_ok_of_status_ne_ok
    (reportValidateError diagRecursionDepth 0 0 0 extack)
    einval
    (by simp [einval, ok])

theorem viewValidateLoop_end_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : off = totalLen) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  subst off
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, ok]

theorem viewValidateLoop_short_header_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, hOff,
    hHeader]

theorem viewValidateLoop_bad_attr_len_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, hOff,
    hHeader, hLen]

theorem viewValidateLoop_attr_overrun_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, hOff,
    hHeader, hLen, hOverrun]

theorem viewValidateLoop_unknown_strict_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : hasFlag validate validateMaxType) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, hOff,
    hHeader, hLen, hOverrun, hUnknown, hMaxType]
  exact keepReported_ne_ok_of_status_ne_ok
    (reportValidateError diagUnknownAttr (view.ptr off) 0 0 extack)
    einval
    (by simp [einval, ok])

theorem viewValidateLoop_unknown_final_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : (hasFlag validate validateMaxType) = false)
    (hNext :
      (off + align4 (attrHeaderLen (view.header off)) > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopAccepted, hFuelNe, hDepth, hOff,
    hHeader, hLen, hOverrun, hUnknown, hMaxType, hNext, ok]

theorem viewValidateLoop_unknown_continue_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : (hasFlag validate validateMaxType) = false)
    (hNext :
      (off + align4 (attrHeaderLen (view.header off)) > totalLen) = false)
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopAccepted view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopAccepted]
  simp [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hUnknown, hMaxType,
    hNext, hRecur]

theorem viewValidateLoop_depth_limit_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : depth >= maxPolicyRecursionDepth) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth]
  exact keepReported_ne_ok_of_status_ne_ok
    (reportValidateError diagRecursionDepth 0 0 0 extack)
    einval
    (by simp [einval, ok])

theorem viewValidateLoop_end_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : off = totalLen) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  subst off
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, ok]

theorem viewValidateLoop_short_header_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, hOff, hHeader]

theorem viewValidateLoop_bad_attr_len_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, hOff, hHeader,
    hLen]

theorem viewValidateLoop_attr_overrun_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, hOff, hHeader,
    hLen, hOverrun]

theorem viewValidateLoop_unknown_strict_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : hasFlag validate validateMaxType) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, hOff, hHeader,
    hLen, hOverrun, hUnknown, hMaxType]
  exact keepReported_ne_ok_of_status_ne_ok
    (reportValidateError diagUnknownAttr (view.ptr off) 0 0 extack)
    einval
    (by simp [einval, ok])

theorem viewValidateLoop_unknown_final_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : (hasFlag validate validateMaxType) = false)
    (hNext :
      (off + align4 (attrHeaderLen (view.header off)) > totalLen) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  simp [viewValidateLoop, ValidateLoopSpec, hFuelNe, hDepth, hOff, hHeader,
    hLen, hOverrun, hUnknown, hMaxType, hNext, ok]

theorem viewValidateLoop_unknown_continue_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = true)
    (hMaxType : (hasFlag validate validateMaxType) = false)
    (hNext :
      (off + align4 (attrHeaderLen (view.header off)) > totalLen) = false)
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopSpec view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopSpec]
  simp [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hUnknown, hMaxType,
    hNext, hRecur]

theorem viewValidateLoop_known_step_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let nested := attrHeaderIsNested header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let row :=
         if policy == 0 then policyMetaAccept
         else policyMetaFromRow policy policyTy policyRow
       let kind := policyMetaKind row
       let effectiveValidate := withStrictStart strictStart ty validate
       let hasPolicy := policy != 0
       let checkUnspec := hasFlag effectiveValidate validateUnspec
       let checkNested := hasFlag effectiveValidate validateNested
       let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
       let kindIsNested := isNestedKind kind
       let attr := view.ptr off
       let rowValidation := policyMetaValidation row
       let payloadLen := len - nlaHeaderLen
       let needUnspec :=
         hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
       let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
       if hasPolicy && checkUnspec && isUnspec != 0 then
         keepReported
           (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
           einval
       else if hasPolicy && checkNested && kindIsNested && nested == 0 then
         keepReported
           (reportValidateError diagNestedMissing attr policy policyTy extack)
           einval
       else if hasPolicy && checkNested &&
           !kindIsNested && isUnspec == 0 && nested != 0 then
         keepReported
           (reportValidateError diagNestedUnexpected attr policy policyTy extack)
           einval
       else
         let strictLen := policyMetaStrictLen row
         if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
           keepReported
             (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
             einval
         else if kind == kindNestedPolicy then
           let ret :=
             if payloadLen == 0 then
               ok
             else if payloadLen < nlaHeaderLen then
               erange
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                 (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                 effectiveValidate extack (depth + 1) 0 nestedTable
                 (fuel - 1) 0
           if ret == ok then
             if rowValidation == policyValidateNone then
               ok
             else
               viewValidatePolicyExtra view off policy policyTy row payloadLen
                 effectiveValidate attr extack
           else
             ret
         else if kind == kindNestedArrayPolicy then
           let ret :=
             if payloadLen == 0 then
               ok
             else if payloadLen < nlaHeaderLen then
               erange
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                 nestedPolicy effectiveValidate extack depth nestedTable
                 (fuel - 1) 0
           if ret == ok then
             if rowValidation == policyValidateNone then
               ok
             else
               viewValidatePolicyExtra view off policy policyTy row payloadLen
                 effectiveValidate attr extack
           else
             ret
         else
           viewValidatePayload view off policy policyTy kind row payloadLen
             effectiveValidate extack) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let nested := attrHeaderIsNested header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let row :=
           if policy == 0 then policyMetaAccept
           else policyMetaFromRow policy policyTy policyRow
         let kind := policyMetaKind row
         let effectiveValidate := withStrictStart strictStart ty validate
         let hasPolicy := policy != 0
         let checkUnspec := hasFlag effectiveValidate validateUnspec
         let checkNested := hasFlag effectiveValidate validateNested
         let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
         let kindIsNested := isNestedKind kind
         let attr := view.ptr off
         let rowValidation := policyMetaValidation row
         let payloadLen := len - nlaHeaderLen
         let needUnspec :=
           hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
         let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
         if hasPolicy && checkUnspec && isUnspec != 0 then
           False
         else if hasPolicy && checkNested && kindIsNested && nested == 0 then
           False
         else if hasPolicy && checkNested &&
             !kindIsNested && isUnspec == 0 && nested != 0 then
           False
         else
           let strictLen := policyMetaStrictLen row
           if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
             False
           else if kind == kindNestedPolicy then
             let nestedAccepted :=
               if payloadLen == 0 then
                 True
               else if payloadLen < nlaHeaderLen then
                 False
               else
                 let nestedPolicy := policyRow.unionPtr
                 let nestedMaxtype := policyRow.len
                 let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                 let nestedView := view.payloadView off payloadLen
                 ValidateLoopAccepted nestedView payloadLen nestedMaxtype
                   nestedPolicy
                   (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                   effectiveValidate extack (depth + 1) 0 nestedTable
                   (fuel - 1) 0
             nestedAccepted ∧
               if rowValidation == policyValidateNone then
                 True
               else
                 PolicyExtraAccepted view off policy policyTy row payloadLen
                   effectiveValidate attr extack
           else if kind == kindNestedArrayPolicy then
             let nestedAccepted :=
               if payloadLen == 0 then
                 True
               else if payloadLen < nlaHeaderLen then
                 False
               else
                 let nestedPolicy := policyRow.unionPtr
                 let nestedMaxtype := policyRow.len
                 let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
                 let nestedView := view.payloadView off payloadLen
                 ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
                   nestedPolicy effectiveValidate extack depth nestedTable
                   (fuel - 1) 0
             nestedAccepted ∧
               if rowValidation == policyValidateNone then
                 True
               else
                 PolicyExtraAccepted view off policy policyTy row payloadLen
                   effectiveValidate attr extack
           else
             PayloadAccepted view off policy policyTy kind row payloadLen
               effectiveValidate extack))
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopAccepted view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopAccepted]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [] using
    knownAttrTail_ok_iff
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let nested := attrHeaderIsNested header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let row :=
         if policy == 0 then policyMetaAccept
         else policyMetaFromRow policy policyTy policyRow
       let kind := policyMetaKind row
       let effectiveValidate := withStrictStart strictStart ty validate
       let hasPolicy := policy != 0
       let checkUnspec := hasFlag effectiveValidate validateUnspec
       let checkNested := hasFlag effectiveValidate validateNested
       let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
       let kindIsNested := isNestedKind kind
       let attr := view.ptr off
       let rowValidation := policyMetaValidation row
       let payloadLen := len - nlaHeaderLen
       let needUnspec :=
         hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
       let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
       if hasPolicy && checkUnspec && isUnspec != 0 then
         keepReported
           (reportValidateError diagUnsupportedAttr attr policy policyTy extack)
           einval
       else if hasPolicy && checkNested && kindIsNested && nested == 0 then
         keepReported
           (reportValidateError diagNestedMissing attr policy policyTy extack)
           einval
       else if hasPolicy && checkNested &&
           !kindIsNested && isUnspec == 0 && nested != 0 then
         keepReported
           (reportValidateError diagNestedUnexpected attr policy policyTy extack)
           einval
       else
         let strictLen := policyMetaStrictLen row
         if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
           keepReported
             (reportValidateError diagInvalidAttrLen attr policy policyTy extack)
             einval
         else if kind == kindNestedPolicy then
           let ret :=
             if payloadLen == 0 then
               ok
             else if payloadLen < nlaHeaderLen then
               erange
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
                 (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                 effectiveValidate extack (depth + 1) 0 nestedTable
                 (fuel - 1) 0
           if ret == ok then
             if rowValidation == policyValidateNone then
               ok
             else
               viewValidatePolicyExtra view off policy policyTy row payloadLen
                 effectiveValidate attr extack
           else
             ret
         else if kind == kindNestedArrayPolicy then
           let ret :=
             if payloadLen == 0 then
               ok
             else if payloadLen < nlaHeaderLen then
               erange
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
                 nestedPolicy effectiveValidate extack depth nestedTable
                 (fuel - 1) 0
           if ret == ok then
             if rowValidation == policyValidateNone then
               ok
             else
               viewValidatePolicyExtra view off policy policyTy row payloadLen
                 effectiveValidate attr extack
           else
             ret
         else
           viewValidatePayload view off policy policyTy kind row payloadLen
             effectiveValidate extack)
      (viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let nested := attrHeaderIsNested header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let row :=
         if policy == 0 then policyMetaAccept
         else policyMetaFromRow policy policyTy policyRow
       let kind := policyMetaKind row
       let effectiveValidate := withStrictStart strictStart ty validate
       let hasPolicy := policy != 0
       let checkUnspec := hasFlag effectiveValidate validateUnspec
       let checkNested := hasFlag effectiveValidate validateNested
       let checkStrictAttrs := hasFlag effectiveValidate validateStrictAttrs
       let kindIsNested := isNestedKind kind
       let attr := view.ptr off
       let rowValidation := policyMetaValidation row
       let payloadLen := len - nlaHeaderLen
       let needUnspec :=
         hasPolicy && (checkUnspec || (checkNested && !kindIsNested))
       let isUnspec := if needUnspec then policyMetaIsUnspec row else 0
       if hasPolicy && checkUnspec && isUnspec != 0 then
         False
       else if hasPolicy && checkNested && kindIsNested && nested == 0 then
         False
       else if hasPolicy && checkNested &&
           !kindIsNested && isUnspec == 0 && nested != 0 then
         False
       else
         let strictLen := policyMetaStrictLen row
         if checkStrictAttrs && strictLen != 0 && payloadLen != strictLen then
           False
         else if kind == kindNestedPolicy then
           let nestedAccepted :=
             if payloadLen == 0 then
               True
             else if payloadLen < nlaHeaderLen then
               False
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               ValidateLoopAccepted nestedView payloadLen nestedMaxtype
                 nestedPolicy
                 (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
                 effectiveValidate extack (depth + 1) 0 nestedTable
                 (fuel - 1) 0
           nestedAccepted ∧
             if rowValidation == policyValidateNone then
               True
             else
               PolicyExtraAccepted view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else if kind == kindNestedArrayPolicy then
           let nestedAccepted :=
             if payloadLen == 0 then
               True
             else if payloadLen < nlaHeaderLen then
               False
             else
               let nestedPolicy := policyRow.unionPtr
               let nestedMaxtype := policyRow.len
               let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
               let nestedView := view.payloadView off payloadLen
               ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
                 nestedPolicy effectiveValidate extack depth nestedTable
                 (fuel - 1) 0
           nestedAccepted ∧
             if rowValidation == policyValidateNone then
               True
             else
               PolicyExtraAccepted view off policy policyTy row payloadLen
                 effectiveValidate attr extack
         else
           PayloadAccepted view off policy policyTy kind row payloadLen
             effectiveValidate extack)
      (ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hRecur

theorem viewValidateLoop_known_step_conforms_from_nested
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hNested :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopAccepted nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArrayAccepted nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0))
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopAccepted view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  exact viewValidateLoop_known_step_conforms view totalLen maxtype policy
    strictStart validate extack depth tb fuel off policyTable hFuel hDepth hOff
    hHeader hLen hOverrun hKnown
    (by
      let header := view.header off
      let len := attrHeaderLen header
      let ty := attrHeaderType header
      let nested := attrHeaderIsNested header
      let policyTy := arrayIndexNospec ty (maxtype + 1)
      let policyRow := policyTable.row policyTy
      let row :=
        if policy == 0 then policyMetaAccept
        else policyMetaFromRow policy policyTy policyRow
      let effectiveValidate := withStrictStart strictStart ty validate
      let attr := view.ptr off
      exact knownAttrVerdictCore_conforms view off policy policyTy row len
        nested effectiveValidate attr extack depth fuel policyRow
        (by
          simpa only [header, len, ty, policyTy, policyRow,
            effectiveValidate, boolDite_eq_ite] using hNested)
        (by
          simpa only [header, len, ty, policyTy, policyRow,
            effectiveValidate, boolDite_eq_ite] using hNestedArray))
    hRecur

theorem viewValidateLoop_known_verdict_reject_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictAccepted view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictReject :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopAccepted]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictAccepted] using
    knownAttrTail_verdict_reject_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictAccepted view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictReject

theorem viewValidateLoop_known_write_reject_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictAccepted view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictOk :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = false)
    (hWriteReject :
      (knownAttrWriteStatus tb (attrHeaderType (view.header off)) maxtype
        (view.ptr off) != ok) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopAccepted]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictAccepted] using
    knownAttrTail_write_reject_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictAccepted view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictOk hWriteReject

theorem viewValidateLoop_known_done_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictAccepted view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictOk :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = false)
    (hWriteOk :
      (knownAttrWriteStatus tb (attrHeaderType (view.header off)) maxtype
        (view.ptr off) != ok) = false)
    (hDone :
      off + align4 (attrHeaderLen (view.header off)) > totalLen) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopAccepted]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictAccepted] using
    knownAttrTail_done_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictAccepted view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictOk hWriteOk hDone

theorem viewValidateLoop_known_verdict_reject_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictSpec view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictReject :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopSpec]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictSpec] using
    knownAttrTail_verdict_reject_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictSpec view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictReject

theorem viewValidateLoop_known_write_reject_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictSpec view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictOk :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = false)
    (hWriteReject :
      (knownAttrWriteStatus tb (attrHeaderType (view.header off)) maxtype
        (view.ptr off) != ok) = true) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopSpec]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictSpec] using
    knownAttrTail_write_reject_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictSpec view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictOk hWriteReject

theorem viewValidateLoop_known_done_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictSpec view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hVerdictOk :
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable != ok) = false)
    (hWriteOk :
      (knownAttrWriteStatus tb (attrHeaderType (view.header off)) maxtype
        (view.ptr off) != ok) = false)
    (hDone :
      off + align4 (attrHeaderLen (view.header off)) > totalLen) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopSpec]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictSpec] using
    knownAttrTail_done_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictSpec view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hVerdictOk hWriteOk hDone

theorem viewValidateLoop_known_step_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hVerdict :
      loopKnownVerdict view maxtype policy strictStart validate extack depth
          fuel off policyTable = ok ↔
        LoopKnownVerdictSpec view maxtype policy strictStart validate
          extack depth fuel off policyTable)
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopSpec view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw (occs := .pos [1]) [viewValidateLoop]
  rw (occs := .pos [1]) [ValidateLoopSpec]
  simp only [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown,
    Bool.false_eq_true, if_false, dite_false]
  simpa only [loopKnownVerdict, LoopKnownVerdictSpec] using
    knownAttrTail_ok_iff
      (loopKnownVerdict view maxtype policy strictStart validate extack depth
        fuel off policyTable)
      (viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      tb (attrHeaderType (view.header off)) maxtype (view.ptr off)
      (LoopKnownVerdictSpec view maxtype policy strictStart validate
        extack depth fuel off policyTable)
      (ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable (fuel - 1)
        (off + align4 (attrHeaderLen (view.header off))))
      (off + align4 (attrHeaderLen (view.header off)) > totalLen)
      hVerdict hRecur

theorem viewValidateLoop_known_step_conforms_spec_from_nested
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hNested :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateLoop nestedView payloadLen nestedMaxtype nestedPolicy
         (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
         effectiveValidate extack (depth + 1) 0 nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateLoopSpec nestedView payloadLen nestedMaxtype nestedPolicy
           (if nestedPolicy == 0 then 0 else policyStrictStart nestedPolicy)
           effectiveValidate extack (depth + 1) 0 nestedTable
           (fuel - 1) 0))
    (hNestedArray :
      (let header := view.header off
       let len := attrHeaderLen header
       let ty := attrHeaderType header
       let policyTy := arrayIndexNospec ty (maxtype + 1)
       let policyRow := policyTable.row policyTy
       let effectiveValidate := withStrictStart strictStart ty validate
       let payloadLen := len - nlaHeaderLen
       let nestedPolicy := policyRow.unionPtr
       let nestedMaxtype := policyRow.len
       let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
       let nestedView := view.payloadView off payloadLen
       viewValidateNestedArrayLoop nestedView payloadLen nestedMaxtype
         nestedPolicy effectiveValidate extack depth nestedTable
         (fuel - 1) 0) = ok ↔
        (let header := view.header off
         let len := attrHeaderLen header
         let ty := attrHeaderType header
         let policyTy := arrayIndexNospec ty (maxtype + 1)
         let policyRow := policyTable.row policyTy
         let effectiveValidate := withStrictStart strictStart ty validate
         let payloadLen := len - nlaHeaderLen
         let nestedPolicy := policyRow.unionPtr
         let nestedMaxtype := policyRow.len
         let nestedTable := PolicyTableView.ofRaw nestedPolicy nestedMaxtype
         let nestedView := view.payloadView off payloadLen
         ValidateNestedArraySpec nestedView payloadLen nestedMaxtype
           nestedPolicy effectiveValidate extack depth nestedTable
           (fuel - 1) 0))
    (hRecur :
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off))) = ok ↔
        ValidateLoopSpec view totalLen maxtype policy strictStart validate
          extack depth tb policyTable (fuel - 1)
          (off + align4 (attrHeaderLen (view.header off)))) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  exact viewValidateLoop_known_step_conforms_spec view totalLen maxtype
    policy strictStart validate extack depth tb fuel off policyTable hFuel
    hDepth hOff hHeader hLen hOverrun hKnown
    (loopKnownVerdict_conforms_spec_from_nested view maxtype policy
      strictStart validate extack depth fuel off policyTable hNested
      hNestedArray)
    hRecur

theorem viewValidateLoop_conforms
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopAccepted view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  refine viewValidateLoop.induct (extack := extack)
    (motive1 := fun view totalLen maxtype policy strictStart validate depth tb policyTable fuel off =>
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable fuel off = ok ↔
        ValidateLoopAccepted view totalLen maxtype policy strictStart validate
          extack depth tb policyTable fuel off)
    (motive2 := fun view totalLen maxtype policy validate depth policyTable fuel off =>
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable fuel off = ok ↔
        ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
          depth policyTable fuel off)
    ?case1 ?case2 ?case3 ?case4 ?case5 ?case6 ?case7 ?case8 ?case9
    ?case10 ?case11 ?case12 ?case13 ?case14 ?case15 ?case16 ?case17
    ?case18 ?case19 ?case20 ?case21 view totalLen maxtype policy strictStart
    validate depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel
    simp [viewValidateLoop, ValidateLoopAccepted, hFuel, unsupported, ok]
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth
    exact viewValidateLoop_depth_limit_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) hDepth
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff
    exact viewValidateLoop_end_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader
    exact viewValidateLoop_short_header_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len hLen
    exact viewValidateLoop_bad_attr_len_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len hLen hOverrun
    exact viewValidateLoop_attr_overrun_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun hUnknown hMaxType
    exact viewValidateLoop_unknown_strict_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun next hUnknown hMaxType hNext
    exact viewValidateLoop_unknown_final_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
      (by simpa [header, len, next] using hNext)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun next hUnknown hMaxType hNext hRecur
    exact viewValidateLoop_unknown_continue_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
      (by simpa [header, len, next] using hNext)
      (by simpa [header, len, next] using hRecur)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictReject hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_verdict_reject_conforms view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictReject)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteReject hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_write_reject_conforms view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictOk)
      (by simpa [writeStatus, header, ty] using hWriteReject)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun next hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteOk hNext hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_done_conforms view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictOk)
      (by simpa [writeStatus, header, ty] using hWriteOk)
      (by simpa [header, len, next] using hNext)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun next hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteOk hNext hNested hNestedArray hRecur
    exact viewValidateLoop_known_step_conforms_from_nested view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      (by simpa only [header, len, ty, policyTy, policyRow,
        effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
      (by simpa only [header, len, ty, policyTy, policyRow,
        effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
      (by simpa [header, len, next] using hRecur)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel
    simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuel,
      unsupported, ok]
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff
    exact viewValidateNestedArrayLoop_end_conforms view totalLen maxtype policy
      validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader
    exact viewValidateNestedArrayLoop_short_header_conforms view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen
    exact viewValidateNestedArrayLoop_bad_len_conforms view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun
    exact viewValidateNestedArrayLoop_overrun_conforms view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen) (by simpa [len] using hOverrun)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictReject hNested
    exact viewValidateNestedArrayLoop_verdict_reject_conforms_from_nested view
      totalLen maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictReject)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested
    exact viewValidateNestedArrayLoop_done_conforms_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictOk)
      (by simpa [len, next] using hNext)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested hRecur
    exact viewValidateNestedArrayLoop_step_conforms_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
      (by simpa [len, next] using hRecur)

theorem viewValidateLoop_conforms_spec
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    viewValidateLoop view totalLen maxtype policy strictStart validate extack
        depth tb policyTable fuel off = ok ↔
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off := by
  refine viewValidateLoop.induct (extack := extack)
    (motive1 := fun view totalLen maxtype policy strictStart validate depth tb policyTable fuel off =>
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable fuel off = ok ↔
        ValidateLoopSpec view totalLen maxtype policy strictStart validate
          extack depth tb policyTable fuel off)
    (motive2 := fun view totalLen maxtype policy validate depth policyTable fuel off =>
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable fuel off = ok ↔
        ValidateNestedArraySpec view totalLen maxtype policy validate extack
          depth policyTable fuel off)
    ?case1 ?case2 ?case3 ?case4 ?case5 ?case6 ?case7 ?case8 ?case9
    ?case10 ?case11 ?case12 ?case13 ?case14 ?case15 ?case16 ?case17
    ?case18 ?case19 ?case20 ?case21 view totalLen maxtype policy strictStart
    validate depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel
    simp [viewValidateLoop, ValidateLoopSpec, hFuel, unsupported, ok]
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth
    exact viewValidateLoop_depth_limit_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) hDepth
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff
    exact viewValidateLoop_end_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader
    exact viewValidateLoop_short_header_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len hLen
    exact viewValidateLoop_bad_attr_len_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len hLen hOverrun
    exact viewValidateLoop_attr_overrun_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun hUnknown hMaxType
    exact viewValidateLoop_unknown_strict_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun next hUnknown hMaxType hNext
    exact viewValidateLoop_unknown_final_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
      (by simpa [header, len, next] using hNext)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty hLen hOverrun next hUnknown hMaxType hNext hRecur
    exact viewValidateLoop_unknown_continue_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hUnknown) (by simpa using hMaxType)
      (by simpa [header, len, next] using hNext)
      (by simpa [header, len, next] using hRecur)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictReject hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_spec_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_verdict_reject_conforms_spec view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictReject)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteReject hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_spec_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_write_reject_conforms_spec view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictOk)
      (by simpa [writeStatus, header, ty] using hWriteReject)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun next hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteOk hNext hNested hNestedArray
    have hVerdict :=
      loopKnownVerdict_conforms_spec_from_nested view maxtype policy strictStart
        validate extack depth fuel off policyTable
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
        (by simpa only [header, len, ty, policyTy, policyRow,
          effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
    exact viewValidateLoop_known_done_conforms_spec view totalLen maxtype policy
      strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      hVerdict
      (by simpa [loopKnownVerdict, header, len, ty, nested, policyTy,
        policyRow, row, kind, effectiveValidate, hasPolicy, checkUnspec,
        checkNested, checkStrictAttrs, kindIsNested, attr, rowValidation,
        payloadLen, needUnspec, isUnspec, verdict, boolDite_eq_ite,
        dite_eq_ite] using hVerdictOk)
      (by simpa [writeStatus, header, ty] using hWriteOk)
      (by simpa [header, len, next] using hNext)
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off hFuel hDepth hOff hHeader header len ty nested hLen hOverrun next hKnown policyTy policyRow row kind effectiveValidate hasPolicy checkUnspec checkNested checkStrictAttrs kindIsNested attr rowValidation payloadLen needUnspec isUnspec verdict hVerdictOk writeStatus hWriteOk hNext hNested hNestedArray hRecur
    exact viewValidateLoop_known_step_conforms_spec_from_nested view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable
      (by simpa using hFuel) (by simpa using hDepth) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [header, len] using hLen)
      (by simpa [header, len] using hOverrun)
      (by simpa [header, ty] using hKnown)
      (by simpa only [header, len, ty, policyTy, policyRow,
        effectiveValidate, payloadLen, boolDite_eq_ite] using hNested)
      (by simpa only [header, len, ty, policyTy, policyRow,
        effectiveValidate, payloadLen, boolDite_eq_ite] using hNestedArray)
      (by simpa [header, len, next] using hRecur)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel
    simp [viewValidateNestedArrayLoop, ValidateNestedArraySpec, hFuel,
      unsupported, ok]
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff
    exact viewValidateNestedArrayLoop_end_conforms_spec view totalLen maxtype policy
      validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader
    exact viewValidateNestedArrayLoop_short_header_conforms_spec view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen
    exact viewValidateNestedArrayLoop_bad_len_conforms_spec view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun
    exact viewValidateNestedArrayLoop_overrun_conforms_spec view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen) (by simpa [len] using hOverrun)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictReject hNested
    exact viewValidateNestedArrayLoop_verdict_reject_conforms_spec_from_nested view
      totalLen maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictReject)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested
    exact viewValidateNestedArrayLoop_done_conforms_spec_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictOk)
      (by simpa [len, next] using hNext)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested hRecur
    exact viewValidateNestedArrayLoop_step_conforms_spec_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
      (by simpa [len, next] using hRecur)

theorem viewValidateNestedArrayLoop_conforms
    (view : AttrView)
    (totalLen maxtype policy validate extack depth : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
        depth policyTable fuel off = ok ↔
      ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
        depth policyTable fuel off := by
  refine viewValidateNestedArrayLoop.induct (extack := extack)
    (motive1 := fun view totalLen maxtype policy strictStart validate depth tb policyTable fuel off =>
      viewValidateLoop view totalLen maxtype policy strictStart validate extack
          depth tb policyTable fuel off = ok ↔
        ValidateLoopAccepted view totalLen maxtype policy strictStart validate
          extack depth tb policyTable fuel off)
    (motive2 := fun view totalLen maxtype policy validate depth policyTable fuel off =>
      viewValidateNestedArrayLoop view totalLen maxtype policy validate extack
          depth policyTable fuel off = ok ↔
        ValidateNestedArrayAccepted view totalLen maxtype policy validate extack
          depth policyTable fuel off)
    ?case1 ?case2 ?case3 ?case4 ?case5 ?case6 ?case7 ?case8 ?case9
    ?case10 ?case11 ?case12 ?case13 ?case14 ?case15 ?case16 ?case17
    ?case18 ?case19 ?case20 ?case21 view totalLen maxtype policy validate
    depth policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _hLen
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _hLen _hOverrun
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _hLen _hOverrun _hUnknown _hMaxType
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _hLen _hOverrun _next _hUnknown _hMaxType _hNext
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _hLen _hOverrun _next _hUnknown _hMaxType _hNext _hRecur
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _nested _hLen _hOverrun _hKnown _policyTy _policyRow _row _kind _effectiveValidate _hasPolicy _checkUnspec _checkNested _checkStrictAttrs _kindIsNested _attr _rowValidation _payloadLen _needUnspec _isUnspec _verdict _hVerdictReject _hNested _hNestedArray
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _nested _hLen _hOverrun _hKnown _policyTy _policyRow _row _kind _effectiveValidate _hasPolicy _checkUnspec _checkNested _checkStrictAttrs _kindIsNested _attr _rowValidation _payloadLen _needUnspec _isUnspec _verdict _hVerdictOk _writeStatus _hWriteReject _hNested _hNestedArray
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _nested _hLen _hOverrun _next _hKnown _policyTy _policyRow _row _kind _effectiveValidate _hasPolicy _checkUnspec _checkNested _checkStrictAttrs _kindIsNested _attr _rowValidation _payloadLen _needUnspec _isUnspec _verdict _hVerdictOk _writeStatus _hWriteOk _hNext _hNested _hNestedArray
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy strictStart validate depth tb policyTable fuel off _hFuel _hDepth _hOff _hHeader _header _len _ty _nested _hLen _hOverrun _next _hKnown _policyTy _policyRow _row _kind _effectiveValidate _hasPolicy _checkUnspec _checkNested _checkStrictAttrs _kindIsNested _attr _rowValidation _payloadLen _needUnspec _isUnspec _verdict _hVerdictOk _writeStatus _hWriteOk _hNext _hNested _hNestedArray _hRecur
    exact viewValidateLoop_conforms view totalLen maxtype policy strictStart
      validate extack depth tb policyTable fuel off
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel
    simp [viewValidateNestedArrayLoop, ValidateNestedArrayAccepted, hFuel,
      unsupported, ok]
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff
    exact viewValidateNestedArrayLoop_end_conforms view totalLen maxtype policy
      validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader
    exact viewValidateNestedArrayLoop_short_header_conforms view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen
    exact viewValidateNestedArrayLoop_bad_len_conforms view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun
    exact viewValidateNestedArrayLoop_overrun_conforms view totalLen maxtype
      policy validate extack depth fuel off policyTable (by simpa using hFuel)
      (by simpa using hOff) (by simpa using hHeader)
      (by simpa [len] using hLen) (by simpa [len] using hOverrun)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictReject hNested
    exact viewValidateNestedArrayLoop_verdict_reject_conforms_from_nested view
      totalLen maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictReject)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested
    exact viewValidateNestedArrayLoop_done_conforms_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, verdict, boolDite_eq_ite, dite_eq_ite]
        using hVerdictOk)
      (by simpa [len, next] using hNext)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
  · intro view totalLen maxtype policy validate depth policyTable fuel off hFuel hOff hHeader len hLen hOverrun payloadLen verdict hVerdictOk next hNext hNested hRecur
    exact viewValidateNestedArrayLoop_step_conforms_from_nested view totalLen
      maxtype policy validate extack depth fuel off policyTable
      (by simpa using hFuel) (by simpa using hOff)
      (by simpa using hHeader) (by simpa [len] using hLen)
      (by simpa [len] using hOverrun)
      (by simpa [len, payloadLen, boolDite_eq_ite] using hNested)
      (by simpa [len, next] using hRecur)

def ValidateViewAccepted (view : AttrView) (args : ValidateArgs) : Prop :=
  if unsupportedValidateFlags args.validate then
    False
  else
    ValidateLoopAccepted view args.len args.maxtype args.policy args.strictStart
      args.validate args.extack 0 args.tb
      (PolicyTableView.ofRaw args.policy args.maxtype) (args.len + 1) 0

def ValidateViewSpec (view : AttrView) (args : ValidateArgs) : Prop :=
  if unsupportedValidateFlags args.validate then
    False
  else
    ValidateLoopSpec view args.len args.maxtype args.policy args.strictStart
      args.validate args.extack 0 args.tb
      (PolicyTableView.ofRaw args.policy args.maxtype) (args.len + 1) 0

theorem validateViewCore_conforms (view : AttrView) (args : ValidateArgs) :
    validateViewCore view args = ok ↔ ValidateViewAccepted view args := by
  unfold validateViewCore ValidateViewAccepted
  cases hUnsupported : unsupportedValidateFlags args.validate
  · simpa [hUnsupported, ok] using
      viewValidateLoop_conforms view args.len args.maxtype args.policy
        args.strictStart args.validate args.extack 0 args.tb
        (PolicyTableView.ofRaw args.policy args.maxtype) (args.len + 1) 0
  · simp [unsupported, ok]

def ValidateBoundedAccepted (input : BoundedValidateInput) : Prop :=
  ValidateViewAccepted input.view input.args

def ValidateBoundedSpec (input : BoundedValidateInput) : Prop :=
  ValidateViewSpec input.view input.args

theorem validateBoundedRegionCore_conforms (input : BoundedValidateInput) :
    validateBoundedRegionCore input = ok ↔ ValidateBoundedAccepted input := by
  unfold validateBoundedRegionCore ValidateBoundedAccepted
  exact validateViewCore_conforms input.view input.args

def ValidateParseAccepted
    (head len maxtype policy strictStart validate extack tb : UInt64) : Prop :=
  if unsupportedValidateFlags validate then
    False
  else if head == 0 then
    if len == 0 then True else False
  else
    ValidateViewAccepted (AttrView.ofRaw head len)
      (validateArgs len maxtype policy strictStart validate extack tb)

def ValidateParseSpec
    (head len maxtype policy strictStart validate extack tb : UInt64) : Prop :=
  if unsupportedValidateFlags validate then
    False
  else if head == 0 then
    if len == 0 then True else False
  else
    ValidateViewSpec (AttrView.ofRaw head len)
      (validateArgs len maxtype policy strictStart validate extack tb)

theorem validateParseCore_conforms
    (head len maxtype policy strictStart validate extack tb : UInt64) :
    validateParseCore head len maxtype policy strictStart validate extack tb = ok ↔
      ValidateParseAccepted head len maxtype policy strictStart validate extack tb := by
  unfold validateParseCore ValidateParseAccepted
  cases hUnsupported : unsupportedValidateFlags validate
  · cases hHead : head == 0
    · have hView :=
        validateViewCore_conforms (AttrView.ofRaw head len)
          (validateArgs len maxtype policy strictStart validate extack tb)
      simpa [hUnsupported, hHead, validateRegionCore, AttrView.ofRaw,
        AttrView.ofRegion] using hView
    · cases hLen : len == 0 <;>
        simp [ok, einval]
  · simp [unsupported, ok]

theorem validateViewCore_conforms_spec (view : AttrView) (args : ValidateArgs) :
    validateViewCore view args = ok ↔ ValidateViewSpec view args := by
  unfold validateViewCore ValidateViewSpec
  cases hUnsupported : unsupportedValidateFlags args.validate
  · simpa [hUnsupported, ok] using
      viewValidateLoop_conforms_spec view args.len args.maxtype args.policy
        args.strictStart args.validate args.extack 0 args.tb
        (PolicyTableView.ofRaw args.policy args.maxtype) (args.len + 1) 0
  · simp [unsupported, ok]

theorem validateBoundedRegionCore_conforms_spec
    (input : BoundedValidateInput) :
    validateBoundedRegionCore input = ok ↔ ValidateBoundedSpec input := by
  unfold validateBoundedRegionCore ValidateBoundedSpec
  exact validateViewCore_conforms_spec input.view input.args

theorem validateParseCore_conforms_spec
    (head len maxtype policy strictStart validate extack tb : UInt64) :
    validateParseCore head len maxtype policy strictStart validate extack tb =
        ok ↔
      ValidateParseSpec head len maxtype policy strictStart validate extack
        tb := by
  unfold validateParseCore ValidateParseSpec
  cases hUnsupported : unsupportedValidateFlags validate
  · cases hHead : head == 0
    · have hView :=
        validateViewCore_conforms_spec (AttrView.ofRaw head len)
          (validateArgs len maxtype policy strictStart validate extack tb)
      simpa [hUnsupported, hHead, validateRegionCore, AttrView.ofRaw,
        AttrView.ofRegion] using hView
    · cases hLen : len == 0 <;>
        simp [ok, einval]
  · simp [unsupported, ok]

theorem validateViewSpec_iff_accepted_of_loop
    (view : AttrView) (args : ValidateArgs)
    (hLoop :
      ValidateLoopSpec view args.len args.maxtype args.policy args.strictStart
          args.validate args.extack 0 args.tb
          (PolicyTableView.ofRaw args.policy args.maxtype)
          (args.len + 1) 0 ↔
        ValidateLoopAccepted view args.len args.maxtype args.policy
          args.strictStart args.validate args.extack 0 args.tb
          (PolicyTableView.ofRaw args.policy args.maxtype)
          (args.len + 1) 0) :
    ValidateViewSpec view args ↔ ValidateViewAccepted view args := by
  unfold ValidateViewSpec ValidateViewAccepted
  by_cases hUnsupported : unsupportedValidateFlags args.validate
  · simp [hUnsupported]
  · simp [hUnsupported, hLoop]

theorem validateParseSpec_iff_accepted_of_loop
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hLoop :
      ValidateLoopSpec (AttrView.ofRaw head len) len maxtype policy
          strictStart validate extack 0 tb
          (PolicyTableView.ofRaw policy maxtype) (len + 1) 0 ↔
        ValidateLoopAccepted (AttrView.ofRaw head len) len maxtype policy
          strictStart validate extack 0 tb
          (PolicyTableView.ofRaw policy maxtype) (len + 1) 0) :
    ValidateParseSpec head len maxtype policy strictStart validate extack tb ↔
      ValidateParseAccepted head len maxtype policy strictStart validate
        extack tb := by
  unfold ValidateParseSpec ValidateParseAccepted
  by_cases hUnsupported : unsupportedValidateFlags validate
  · simp [hUnsupported]
  · by_cases hHead : head == 0
    · by_cases hLen : len == 0 <;>
        simp [hUnsupported, hHead, hLen]
    · have hView :=
        validateViewSpec_iff_accepted_of_loop
          (AttrView.ofRaw head len)
          (validateArgs len maxtype policy strictStart validate extack tb)
          (by
            simpa [validateArgs] using hLoop)
      simpa [hUnsupported, hHead] using hView

theorem validateParseCore_conforms_spec_of_loop
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hLoop :
      ValidateLoopSpec (AttrView.ofRaw head len) len maxtype policy
          strictStart validate extack 0 tb
          (PolicyTableView.ofRaw policy maxtype) (len + 1) 0 ↔
        ValidateLoopAccepted (AttrView.ofRaw head len) len maxtype policy
          strictStart validate extack 0 tb
          (PolicyTableView.ofRaw policy maxtype) (len + 1) 0) :
    validateParseCore head len maxtype policy strictStart validate extack tb =
        ok ↔
      ValidateParseSpec head len maxtype policy strictStart validate extack
        tb :=
  (validateParseCore_conforms head len maxtype policy strictStart validate
    extack tb).trans
    (validateParseSpec_iff_accepted_of_loop head len maxtype policy
      strictStart validate extack tb hLoop).symm

theorem AttrView.attributeSpatialSafety (view : AttrView) :
    AttributeSpatialSafety view := by
  constructor
  · intro off
    unfold AttrView.header
    by_cases h : off.toNat + Memory.nlaHeaderBytes <= view.totalLen
    · exact Or.inl h
    · exact Or.inr (by
        simp [h])
  · intro off ix
    unfold AttrView.byte
    by_cases h :
        off.toNat + Memory.nlaHeaderBytes + ix.toNat < view.totalLen
    · exact Or.inl h
    · exact Or.inr (by
        simp [h])
  · intro off payloadLen
    exact (view.payloadView off payloadLen).fits

theorem AttrView.payloadWindowBounds
    (view : AttrView)
    (off count : UInt64)
    (hWindow :
      off.toNat + Memory.Layout.headerLen + count.toNat ≤ view.totalLen)
    (ix : Nat)
    (hIx : ix < count.toNat) :
    off.toNat + Memory.Layout.headerLen + ix < view.totalLen := by
  omega

theorem nlattrFullView_payload_window_bounds
    (nla declaredLen payloadLen count : UInt64)
    (hRegion : (rawRegion nla declaredLen).totalLen = declaredLen.toNat)
    (hPayload :
      Memory.Layout.headerLen + payloadLen.toNat ≤ declaredLen.toNat)
    (hCount : count.toNat ≤ payloadLen.toNat)
    (ix : Nat)
    (hIx : ix < count.toNat) :
    Memory.Layout.headerLen + ix <
      (nlattrFullView nla declaredLen).totalLen := by
  unfold nlattrFullView AttrView.ofRaw AttrView.ofRegion
  simp [hRegion]
  omega

theorem nlattrPayloadLenFromDeclared_payload_fits
    (declaredLen : UInt64)
    (hSupported :
      nlattrPayloadLenFromDeclared declaredLen != cmpUnsupported) :
    Memory.Layout.headerLen +
        (nlattrPayloadLenFromDeclared declaredLen).toNat ≤
      declaredLen.toNat := by
  unfold nlattrPayloadLenFromDeclared at *
  by_cases hShort : declaredLen < nlaHeaderLen
  · simp [hShort] at hSupported
  · have hLeNat : nlaHeaderLen.toNat ≤ declaredLen.toNat := by
      by_cases hNat : nlaHeaderLen.toNat ≤ declaredLen.toNat
      · exact hNat
      · have hLtNat : declaredLen.toNat < nlaHeaderLen.toNat :=
          Nat.lt_of_not_ge hNat
        exact False.elim (hShort (UInt64.lt_iff_toNat_lt.mpr hLtNat))
    have hLe : nlaHeaderLen ≤ declaredLen :=
      UInt64.le_iff_toNat_le.mpr hLeNat
    have hLeNat := UInt64.le_iff_toNat_le.mp hLe
    simp [hShort]
    rw [UInt64.toNat_sub_of_le _ _ hLe]
    simp [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes] at *
    omega

theorem nlattrFullView_supported_payload_window_bounds
    (nla declaredLen count : UInt64)
    (hRegion : (rawRegion nla declaredLen).totalLen = declaredLen.toNat)
    (hSupported :
      nlattrPayloadLenFromDeclared declaredLen != cmpUnsupported)
    (hCount :
      count.toNat ≤ (nlattrPayloadLenFromDeclared declaredLen).toNat)
    (ix : Nat)
    (hIx : ix < count.toNat) :
    Memory.Layout.headerLen + ix <
      (nlattrFullView nla declaredLen).totalLen := by
  exact nlattrFullView_payload_window_bounds nla declaredLen
    (nlattrPayloadLenFromDeclared declaredLen) count hRegion
    (nlattrPayloadLenFromDeclared_payload_fits declaredLen hSupported)
    hCount ix hIx

theorem min64_toNat_le_right (a b : UInt64) :
    (min64 a b).toNat ≤ b.toNat := by
  unfold min64
  by_cases hLe : a ≤ b
  · simp [hLe]
    exact UInt64.le_iff_toNat_le.mp hLe
  · simp [hLe]

theorem nlattrFullView_min_payload_window_bounds
    (nla declaredLen requested : UInt64)
    (hRegion : (rawRegion nla declaredLen).totalLen = declaredLen.toNat)
    (hSupported :
      nlattrPayloadLenFromDeclared declaredLen != cmpUnsupported)
    (ix : Nat)
    (hIx :
      ix <
        (min64 requested
          (nlattrPayloadLenFromDeclared declaredLen)).toNat) :
    Memory.Layout.headerLen + ix <
      (nlattrFullView nla declaredLen).totalLen := by
  exact nlattrFullView_supported_payload_window_bounds nla declaredLen
    (min64 requested (nlattrPayloadLenFromDeclared declaredLen)) hRegion
    hSupported
    (min64_toNat_le_right requested
      (nlattrPayloadLenFromDeclared declaredLen))
    ix hIx

theorem validateParseCore_attributeSpatialSafety
    (head len _maxtype _policy _strictStart _validate _extack _tb : UInt64) :
    AttributeSpatialSafety (AttrView.ofRaw head len) :=
  AttrView.attributeSpatialSafety (AttrView.ofRaw head len)

theorem validateBoundedRegionCore_attributeSpatialSafety
    (input : BoundedValidateInput) :
    AttributeSpatialSafety input.view :=
  AttrView.attributeSpatialSafety input.view

theorem PolicyRowView.spatialSafety (row : PolicyRowView) :
    PolicyRowSpatialSafety row := by
  constructor
  intro off
  unfold PolicyRowView.byte
  by_cases h : off.toNat < row.totalLen
  · exact Or.inl h
  · exact Or.inr (by simp [h])

theorem rawPolicyRow_spatialSafety (policy ty : UInt64) :
    PolicyRowSpatialSafety (PolicyRowView.ofRaw policy ty) :=
  PolicyRowView.spatialSafety (PolicyRowView.ofRaw policy ty)

theorem policyTableRow_spatialSafety (table : PolicyTableView) (ty : UInt64) :
    PolicyRowSpatialSafety (table.row ty) :=
  PolicyRowView.spatialSafety (table.row ty)

theorem validateBoundedRegionCore_spatialSafety
    (input : BoundedValidateInput) :
    ValidateInputSpatialSafety input := by
  constructor
  · exact AttrView.attributeSpatialSafety input.view
  · intro ty
    exact policyTableRow_spatialSafety input.policyTable ty

theorem validateBoundedRegionCore_wireAttrs_payloadFits
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs) :
    ∀ (entry : Nat × Memory.Layout.WireAttr),
      entry ∈ Memory.Layout.entries 0 attrs →
        Memory.Layout.payloadFits input.region.totalLen entry.1 entry.2 := by
  unfold BoundedValidateInput.wireAttrs? at hParse
  exact Memory.Layout.regionParseAttrs?_entries_payloadFits input.region attrs
    hParse

theorem validateBoundedRegionCore_wireAttrs_header_byte_bounds
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs)
    (ix : Nat)
    (hIx : ix < Memory.Layout.headerLen) :
    entry.1 + ix < input.region.totalLen := by
  exact Memory.Layout.payloadFits_header_index_lt
    (validateBoundedRegionCore_wireAttrs_payloadFits input attrs hParse entry
      hEntry)
    hIx

theorem validateBoundedRegionCore_wireAttrs_payload_byte_bounds
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs)
    (ix : Nat)
    (hIx : ix < entry.2.payloadLen) :
    entry.1 + Memory.Layout.headerLen + ix < input.region.totalLen := by
  exact Memory.Layout.payloadFits_payload_index_lt
    (validateBoundedRegionCore_wireAttrs_payloadFits input attrs hParse entry
      hEntry)
    hIx

theorem validateBoundedRegionCore_wireByteBoundsSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs) :
    input.WireByteBoundsSpec attrs := by
  exact
    { headerBytes :=
        validateBoundedRegionCore_wireAttrs_header_byte_bounds input attrs
          hParse,
      payloadBytes :=
        validateBoundedRegionCore_wireAttrs_payload_byte_bounds input attrs
          hParse }

theorem validateBoundedRegionCore_wireAttrs_entries_wireAttrAt?
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs) :
    input.wireAttrAt? entry.1 = some entry.2 := by
  unfold BoundedValidateInput.wireAttrs? BoundedValidateInput.wireAttrAt? at *
  exact Memory.Layout.regionParseAttrs?_entries_wireAttrAt? input.region attrs
    hParse entry hEntry

theorem validateBoundedRegionCore_wireAttrs_cons_head_wireAttrAt?
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some (attr :: rest)) :
    input.wireAttrAt? 0 = some attr := by
  unfold BoundedValidateInput.wireAttrs? BoundedValidateInput.wireAttrAt? at *
  exact Memory.Layout.regionParseAttrsLoop_cons_head_wireAttrAt? input.region
    (input.region.totalLen + 1) 0 attr rest hParse

theorem validateBoundedRegionCore_wireAttrs_cons_head_declared_end_le
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some (attr :: rest)) :
    ∃ hHeader : 0 + Memory.Layout.headerLen ≤ input.region.totalLen,
      0 + (Memory.attrHeaderLen
        (input.region.header 0 hHeader)).toNat ≤ input.region.totalLen := by
  unfold BoundedValidateInput.wireAttrs? at hParse
  exact Memory.Layout.regionParseAttrsLoop_cons_head_declared_end_le
    input.region (input.region.totalLen + 1) 0 attr rest hParse

theorem validateBoundedRegionCore_wireAttrs_cons_tail_of_next_le
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hNext : 0 + Memory.Layout.wireTotalSize attr ≤ input.region.totalLen) :
    ∃ fuel',
      input.region.totalLen + 1 = fuel' + 1 ∧
        Memory.Layout.regionParseAttrsLoop input.region fuel'
          (0 + Memory.Layout.wireTotalSize attr) = some rest := by
  unfold BoundedValidateInput.wireAttrs? at hParse
  exact Memory.Layout.regionParseAttrsLoop_cons_tail_of_next_le input.region
    (input.region.totalLen + 1) 0 attr rest hParse hNext

theorem validateBoundedRegionCore_wireAttrs_cons_next_le_of_rest_ne_nil
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hRest : rest ≠ []) :
    0 + Memory.Layout.wireTotalSize attr ≤ input.region.totalLen := by
  unfold BoundedValidateInput.wireAttrs? at hParse
  exact Memory.Layout.regionParseAttrsLoop_cons_next_le_of_rest_ne_nil
    input.region (input.region.totalLen + 1) 0 attr rest hParse hRest

theorem validateBoundedRegionCore_parseLoop_cons_head_wireAttrAt?
    (input : BoundedValidateInput)
    (fuel off : Nat)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region fuel off =
        some (attr :: rest)) :
    input.wireAttrAt? off = some attr := by
  unfold BoundedValidateInput.wireAttrAt?
  exact Memory.Layout.regionParseAttrsLoop_cons_head_wireAttrAt? input.region
    fuel off attr rest hParse

theorem validateBoundedRegionCore_parseLoop_cons_next_le_of_rest_ne_nil
    (input : BoundedValidateInput)
    (fuel off : Nat)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region fuel off =
        some (attr :: rest))
    (hRest : rest ≠ []) :
    off + Memory.Layout.wireTotalSize attr ≤ input.region.totalLen := by
  exact Memory.Layout.regionParseAttrsLoop_cons_next_le_of_rest_ne_nil
    input.region fuel off attr rest hParse hRest

theorem validateBoundedRegionCore_parseLoop_cons_tail_of_next_le
    (input : BoundedValidateInput)
    (fuel off : Nat)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region fuel off =
        some (attr :: rest))
    (hNext : off + Memory.Layout.wireTotalSize attr ≤ input.region.totalLen) :
    ∃ fuel',
      fuel = fuel' + 1 ∧
        Memory.Layout.regionParseAttrsLoop input.region fuel'
          (off + Memory.Layout.wireTotalSize attr) = some rest := by
  exact Memory.Layout.regionParseAttrsLoop_cons_tail_of_next_le input.region
    fuel off attr rest hParse hNext

theorem validateBoundedRegionCore_wireAttr_header_fields
    (input : BoundedValidateInput) (off : Nat)
    (attr : Memory.Layout.WireAttr)
    (hAttr : input.wireAttrAt? off = some attr) :
    ∃ hHeader : off + Memory.Layout.headerLen ≤ input.region.totalLen,
      let header := input.region.header off hHeader
      attr.ty = (Memory.attrHeaderType header).toNat ∧
        attr.payloadLen = (Memory.attrHeaderLen header).toNat -
          Memory.Layout.headerLen ∧
        attr.nested = (Memory.attrHeaderIsNested header != 0) := by
  unfold BoundedValidateInput.wireAttrAt? at hAttr
  exact Memory.Layout.regionWireAttrAt?_some_header_fields hAttr

theorem validateBoundedRegionCore_wireAttr_header_len_ge
    (input : BoundedValidateInput) (off : Nat)
    (attr : Memory.Layout.WireAttr)
    (hAttr : input.wireAttrAt? off = some attr) :
    ∃ hHeader : off + Memory.Layout.headerLen ≤ input.region.totalLen,
      Memory.Layout.headerLen ≤
        (Memory.attrHeaderLen (input.region.header off hHeader)).toNat := by
  unfold BoundedValidateInput.wireAttrAt? at hAttr
  exact Memory.Layout.regionWireAttrAt?_some_header_len_ge hAttr

theorem validateBoundedRegionCore_wireAttr_declared_end_le
    (input : BoundedValidateInput) (off : Nat)
    (attr : Memory.Layout.WireAttr)
    (hAttr : input.wireAttrAt? off = some attr) :
    ∃ hHeader : off + Memory.Layout.headerLen ≤ input.region.totalLen,
      off + (Memory.attrHeaderLen
        (input.region.header off hHeader)).toNat ≤ input.region.totalLen := by
  unfold BoundedValidateInput.wireAttrAt? at hAttr
  exact Memory.Layout.regionWireAttrAt?_some_declared_end_le hAttr

theorem validateBoundedRegionCore_wireAttrs_entries_header_fields
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs) :
    ∃ hHeader : entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
      let header := input.region.header entry.1 hHeader
      entry.2.ty = (Memory.attrHeaderType header).toNat ∧
        entry.2.payloadLen = (Memory.attrHeaderLen header).toNat -
          Memory.Layout.headerLen ∧
        entry.2.nested = (Memory.attrHeaderIsNested header != 0) := by
  exact validateBoundedRegionCore_wireAttr_header_fields input entry.1 entry.2
    (validateBoundedRegionCore_wireAttrs_entries_wireAttrAt? input attrs hParse
      entry hEntry)

theorem validateBoundedRegionCore_wireAttrs_matchesRegion
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs) :
    input.WireStreamMatches attrs := by
  unfold BoundedValidateInput.WireStreamMatches
  unfold BoundedValidateInput.wireAttrs? at hParse
  exact Memory.Layout.regionParseAttrs?_matchesRegion input.region attrs hParse

theorem validateBoundedRegionCore_wireMessageSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs) :
    input.WireMessageSpec attrs := by
  exact
    { parsed := hParse,
      stream := validateBoundedRegionCore_wireAttrs_matchesRegion input attrs
        hParse,
      payloadFits := validateBoundedRegionCore_wireAttrs_payloadFits input
        attrs hParse,
      headerFields := validateBoundedRegionCore_wireAttrs_entries_header_fields
        input attrs hParse }

theorem validateBoundedRegionCore_wireStructuralSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some attrs) :
    input.WireStructuralSpec := by
  exact ⟨attrs,
    validateBoundedRegionCore_wireMessageSpec_of_parse input attrs hParse⟩

theorem validateBoundedRegionCore_ok_wireMessageSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs) :
    ValidateBoundedSpec input ∧ input.WireMessageSpec attrs := by
  exact ⟨
    (validateBoundedRegionCore_conforms_spec input).mp hOk,
    validateBoundedRegionCore_wireMessageSpec_of_parse input attrs hParse⟩

theorem validateBoundedRegionCore_ok_wireByteBoundsSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs) :
    ValidateBoundedSpec input ∧ input.WireByteBoundsSpec attrs := by
  exact ⟨
    (validateBoundedRegionCore_conforms_spec input).mp hOk,
    validateBoundedRegionCore_wireByteBoundsSpec_of_parse input attrs
      hParse⟩

theorem headerKnown_toNat_bounds
    (ty maxtype : UInt64)
    (hKnown : (ty == 0 || ty > maxtype) = false) :
    ty.toNat ≠ 0 ∧ ty.toNat ≤ maxtype.toNat := by
  simp at hKnown
  constructor
  · intro hZero
    apply hKnown.1
    have hOf := UInt64.ofNat_toNat (x := ty)
    rw [hZero] at hOf
    simpa using hOf.symm
  · have hLe := hKnown.2
    change ty.toBitVec.toNat ≤ maxtype.toBitVec.toNat at hLe
    exact hLe

theorem attrHeaderLen_eq_memory (header : UInt64) :
    attrHeaderLen header = Memory.attrHeaderLen header := by
  rfl

theorem attrHeaderType_eq_memory (header : UInt64) :
    attrHeaderType header = Memory.attrHeaderType header := by
  rfl

theorem attrHeaderIsNested_eq_memory (header : UInt64) :
    attrHeaderIsNested header = Memory.attrHeaderIsNested header := by
  rfl

theorem attrHeaderLen_toNat_lt_u32 (header : UInt64) :
    (attrHeaderLen header).toNat < 4294967296 := by
  unfold attrHeaderLen
  rw [UInt64.toNat_and]
  have hLe :
      header.toNat &&& (0xffffffff : UInt64).toNat ≤
        (0xffffffff : UInt64).toNat :=
    Nat.and_le_right
  have hMask :
      (0xffffffff : UInt64).toNat = 4294967295 := by
    decide
  omega

theorem wireAttr_totalSize_eq_align4_headerLen
    (input : BoundedValidateInput)
    (off : Nat)
    (attr : Memory.Layout.WireAttr)
    (hAttr : input.wireAttrAt? off = some attr)
    (hHeader : off + Memory.Layout.headerLen ≤ input.region.totalLen) :
    Memory.Layout.wireTotalSize attr =
      Memory.Layout.align4
        (Memory.attrHeaderLen (input.region.header off hHeader)).toNat := by
  rcases validateBoundedRegionCore_wireAttr_header_fields input off attr hAttr
    with ⟨hHeaderFields, _hTy, hPayloadLen, _hNested⟩
  rcases validateBoundedRegionCore_wireAttr_header_len_ge input off attr hAttr
    with ⟨hHeaderLen, hLenGe⟩
  have hHeaderFieldsEq : hHeaderFields = hHeader := by
    exact Subsingleton.elim hHeaderFields hHeader
  subst hHeaderFields
  have hHeaderLenEq : hHeaderLen = hHeader := by
    exact Subsingleton.elim hHeaderLen hHeader
  subst hHeaderLen
  unfold Memory.Layout.wireTotalSize Memory.Layout.totalSize
    Memory.Layout.attrSize
  rw [hPayloadLen]
  have hSub :
      Memory.Layout.headerLen + ((Memory.attrHeaderLen
        (input.region.header off hHeader)).toNat -
          Memory.Layout.headerLen) =
        (Memory.attrHeaderLen (input.region.header off hHeader)).toNat := by
    omega
  rw [hSub]

theorem wireAttr_totalSize_eq_align4_view_header
    (input : BoundedValidateInput)
    (off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (hAttr : input.wireAttrAt? off.toNat = some attr)
    (hHeader : off.toNat + Memory.Layout.headerLen ≤ input.region.totalLen) :
    Memory.Layout.wireTotalSize attr =
      (align4 (attrHeaderLen (input.view.header off))).toNat := by
  have hWire :=
    wireAttr_totalSize_eq_align4_headerLen input off.toNat attr hAttr hHeader
  have hViewHeader :
      input.view.header off = input.region.header off.toNat hHeader :=
    BoundedValidateInput.view_header_eq_region_header input off hHeader
  rw [hViewHeader, attrHeaderLen_eq_memory]
  rw [hWire]
  exact (align4_toNat_eq_layout_align4_of_u32
    (Memory.attrHeaderLen (input.region.header off.toNat hHeader))
    (attrHeaderLen_toNat_lt_u32 (input.region.header off.toNat hHeader))).symm

theorem wireMessageSpec_entry_type_bounds_of_headerKnown
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (maxtype : UInt64)
    (entry : Nat × Memory.Layout.WireAttr)
    (hMsg : input.WireMessageSpec attrs)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs)
    (hKnown :
      ∀ hHeader :
          entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
        (Memory.attrHeaderType (input.region.header entry.1 hHeader) == 0 ||
          Memory.attrHeaderType (input.region.header entry.1 hHeader) >
            maxtype) = false) :
    entry.2.ty ≠ 0 ∧ entry.2.ty ≤ maxtype.toNat := by
  rcases hMsg.headerFields entry hEntry with
    ⟨hHeader, hTy, _hPayloadLen, _hNested⟩
  have hBounds :=
    headerKnown_toNat_bounds
      (Memory.attrHeaderType (input.region.header entry.1 hHeader))
      maxtype (hKnown hHeader)
  constructor
  · intro hZero
    exact hBounds.1 (by
      rw [← hTy]
      exact hZero)
  · rw [hTy]
    exact hBounds.2

theorem wireAttrsAllowedByMaxType_of_headerKnown
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hMsg : input.WireMessageSpec attrs)
    (hKnown :
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          ∀ hHeader :
            entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
            (Memory.attrHeaderType
                (input.region.header entry.1 hHeader) == 0 ||
              Memory.attrHeaderType
                (input.region.header entry.1 hHeader) >
                input.args.maxtype) = false) :
    input.WireAttrsAllowedByMaxType attrs := by
  unfold BoundedValidateInput.WireAttrsAllowedByMaxType
  by_cases hMaxType : hasFlag input.args.validate validateMaxType
  · simp only [hMaxType, if_true]
    intro entry hEntry
    exact wireMessageSpec_entry_type_bounds_of_headerKnown input attrs
      input.args.maxtype entry hMsg hEntry (hKnown entry hEntry)
  · have hMaxTypeFalse :
        hasFlag input.args.validate validateMaxType = false := by
      cases hFlag : hasFlag input.args.validate validateMaxType <;>
        simp [hFlag] at hMaxType ⊢
    simp [hMaxTypeFalse]

theorem wireMaxTypeSpec_of_headerKnown
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hMsg : input.WireMessageSpec attrs)
    (hKnown :
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          ∀ hHeader :
            entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
            (Memory.attrHeaderType
                (input.region.header entry.1 hHeader) == 0 ||
              Memory.attrHeaderType
                (input.region.header entry.1 hHeader) >
                input.args.maxtype) = false) :
    input.WireMaxTypeSpec attrs := by
  exact ⟨hMsg,
    wireAttrsAllowedByMaxType_of_headerKnown input attrs hMsg hKnown⟩

theorem wirePolicyIndexSpec_of_wireMaxTypeSpec
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hMaxSpec : input.WireMaxTypeSpec attrs) :
    input.WirePolicyIndexSpec attrs := by
  intro hMaxType hNoOverflow entry hEntry hHeader
  unfold BoundedValidateInput.WireMaxTypeSpec at hMaxSpec
  have hAllowed := hMaxSpec.2
  unfold BoundedValidateInput.WireAttrsAllowedByMaxType at hAllowed
  have hAllowedForall :
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          entry.2.ty ≠ 0 ∧
            entry.2.ty ≤ input.args.maxtype.toNat := by
    simpa [hMaxType] using hAllowed
  have hEntryBounds := hAllowedForall entry hEntry
  rcases hMaxSpec.1.headerFields entry hEntry with
    ⟨hHeaderFields, hTy, _hPayloadLen, _hNested⟩
  have hHeaderEq : hHeaderFields = hHeader :=
    Subsingleton.elim hHeaderFields hHeader
  subst hHeaderFields
  have hTypeLe :
      (Memory.attrHeaderType
        (input.region.header entry.1 hHeader)).toNat ≤
        input.args.maxtype.toNat := by
    rw [← hTy]
    exact hEntryBounds.2
  exact arrayIndexNospec_eq_of_le_maxtype_no_overflow
    (Memory.attrHeaderType (input.region.header entry.1 hHeader))
    input.args.maxtype hTypeLe hNoOverflow

theorem validateBoundedRegionCore_ok_wireMaxTypeSpec_of_parse_and_headerKnown
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs)
    (hKnown :
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          ∀ hHeader :
            entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
            (Memory.attrHeaderType
                (input.region.header entry.1 hHeader) == 0 ||
              Memory.attrHeaderType
                (input.region.header entry.1 hHeader) >
                input.args.maxtype) = false) :
    ValidateBoundedSpec input ∧ input.WireMaxTypeSpec attrs := by
  have hCombined :=
    validateBoundedRegionCore_ok_wireMessageSpec_of_parse input attrs hOk
      hParse
  exact ⟨hCombined.1,
    wireMaxTypeSpec_of_headerKnown input attrs hCombined.2 hKnown⟩

theorem validateLoopSpec_fuel_ne_zero
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hSpec :
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off) :
    fuel != 0 := by
  by_cases hFuel : fuel == 0
  · rw [ValidateLoopSpec] at hSpec
    simp [hFuel] at hSpec
  · simpa using hFuel

theorem validateBoundedSpec_loopSpec
    (input : BoundedValidateInput)
    (hSpec : ValidateBoundedSpec input) :
    ValidateLoopSpec input.view input.args.len input.args.maxtype
      input.args.policy input.args.strictStart input.args.validate
      input.args.extack 0 input.args.tb
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
      (input.args.len + 1) 0 := by
  unfold ValidateBoundedSpec ValidateViewSpec at hSpec
  cases hUnsupported : unsupportedValidateFlags input.args.validate
  · simpa [hUnsupported] using hSpec
  · simp [hUnsupported] at hSpec

theorem validateLoopSpec_known_header_of_validateMaxType
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hSpec :
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hMaxType : hasFlag validate validateMaxType) :
    (attrHeaderType (view.header off) == 0 ||
      attrHeaderType (view.header off) > maxtype) = false := by
  cases hUnknown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype)
  · rfl
  · have hFuelNe : ¬(fuel == 0) = true := by
      simpa using hFuel
    rw [ValidateLoopSpec] at hSpec
    simp [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hUnknown,
      hMaxType] at hSpec

theorem validateLoopSpec_headerType_bounds_of_validateMaxType
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hSpec :
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hMaxType : hasFlag validate validateMaxType) :
    (attrHeaderType (view.header off)).toNat ≠ 0 ∧
      (attrHeaderType (view.header off)).toNat ≤ maxtype.toNat := by
  exact headerKnown_toNat_bounds (attrHeaderType (view.header off)) maxtype
    (validateLoopSpec_known_header_of_validateMaxType view totalLen maxtype
      policy strictStart validate extack depth tb fuel off policyTable hSpec
      hFuel hDepth hOff hHeader hLen hOverrun hMaxType)

theorem validateLoopSpec_wireAttr_type_bounds_at_offset_of_validateMaxType
    (input : BoundedValidateInput)
    (fuel off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (hSpec :
      ValidateLoopSpec input.view input.args.len input.args.maxtype
        input.args.policy input.args.strictStart input.args.validate
        input.args.extack 0 input.args.tb
        (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
        fuel off)
    (hAttr : input.wireAttrAt? off.toNat = some attr)
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    attr.ty ≠ 0 ∧ attr.ty ≤ input.args.maxtype.toNat := by
  rcases validateBoundedRegionCore_wireAttr_header_fields input off.toNat
      attr hAttr with
    ⟨hHeaderFields, hTy, _hPayloadLen, _hNested⟩
  rcases validateBoundedRegionCore_wireAttr_header_len_ge input off.toNat
      attr hAttr with
    ⟨hHeaderLen, hLenGe⟩
  rcases validateBoundedRegionCore_wireAttr_declared_end_le input off.toNat
      attr hAttr with
    ⟨hHeaderEnd, hEndLe⟩
  have hFuel :=
    validateLoopSpec_fuel_ne_zero input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb fuel off
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hSpec
  have hDepth :
      ((0 : UInt64) >= maxPolicyRecursionDepth) = false := by
    decide
  have hOff : (off == input.args.len) = false := by
    apply u64_eq_false_of_toNat_ne
    intro hNatEq
    have hOffLt : off.toNat < input.args.len.toNat := by
      rw [input.len_matches_region]
      have hHeaderNat := hHeaderFields
      unfold Memory.Layout.headerLen Memory.nlaHeaderBytes at hHeaderNat
      omega
    omega
  have hHeaderAddNat :
      (off + nlaHeaderLen).toNat =
        off.toNat + Memory.Layout.headerLen := by
    have hNoOverflow :
        off.toNat + nlaHeaderLen.toNat < UInt64.size := by
      have hHeaderLe :
          off.toNat + nlaHeaderLen.toNat ≤ input.args.len.toNat := by
        simpa [nlaHeaderLen, Memory.Layout.headerLen,
          Memory.nlaHeaderBytes, input.len_matches_region] using hHeaderFields
      exact Nat.lt_of_le_of_lt hHeaderLe
        (UInt64.toNat_lt_size input.args.len)
    calc
      (off + nlaHeaderLen).toNat = off.toNat + nlaHeaderLen.toNat :=
        u64_add_toNat_of_lt_size off nlaHeaderLen hNoOverflow
      _ = off.toNat + Memory.Layout.headerLen := by
        simp [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
  have hShortHeader :
      (off + nlaHeaderLen > input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hHeaderAddNat, input.len_matches_region]
    exact hHeaderFields
  have hViewHeaderLen :
      input.view.header off = input.region.header off.toNat hHeaderLen :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderLen
  have hBadLen :
      (attrHeaderLen (input.view.header off) < nlaHeaderLen) = false := by
    apply u64_lt_false_of_toNat_le
    rw [hViewHeaderLen, attrHeaderLen_eq_memory]
    simpa [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
      using hLenGe
  have hViewHeaderEnd :
      input.view.header off = input.region.header off.toNat hHeaderEnd :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderEnd
  have hDeclaredAddNat :
      (off + attrHeaderLen (input.view.header off)).toNat =
        off.toNat +
          (Memory.attrHeaderLen
            (input.region.header off.toNat hHeaderEnd)).toNat := by
    have hNoOverflow :
        off.toNat +
            (attrHeaderLen (input.view.header off)).toNat <
          UInt64.size := by
      rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
      have hEndLeLen :
          off.toNat +
              (Memory.attrHeaderLen
                (input.region.header off.toNat hHeaderEnd)).toNat ≤
            input.args.len.toNat := by
        simpa [input.len_matches_region] using hEndLe
      exact Nat.lt_of_le_of_lt hEndLeLen
        (UInt64.toNat_lt_size input.args.len)
    calc
      (off + attrHeaderLen (input.view.header off)).toNat =
          off.toNat + (attrHeaderLen (input.view.header off)).toNat :=
        u64_add_toNat_of_lt_size off
          (attrHeaderLen (input.view.header off)) hNoOverflow
      _ = off.toNat +
          (Memory.attrHeaderLen
            (input.region.header off.toNat hHeaderEnd)).toNat := by
        rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
  have hOverrun :
      (off + attrHeaderLen (input.view.header off) >
        input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hDeclaredAddNat, input.len_matches_region]
    exact hEndLe
  have hBounds :=
    validateLoopSpec_headerType_bounds_of_validateMaxType input.view
      input.args.len input.args.maxtype input.args.policy
      input.args.strictStart input.args.validate input.args.extack 0
      input.args.tb fuel off
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hSpec
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hMaxType
  have hViewHeaderFields :
      input.view.header off =
        input.region.header off.toNat hHeaderFields :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderFields
  have hTypeEq :
      (attrHeaderType (input.view.header off)).toNat =
        (Memory.attrHeaderType
          (input.region.header off.toNat hHeaderFields)).toNat := by
    rw [hViewHeaderFields, attrHeaderType_eq_memory]
  constructor
  · intro hZero
    exact hBounds.1 (by
      rw [hTypeEq, ← hTy]
      exact hZero)
  · rw [hTy]
    rw [← hTypeEq]
    exact hBounds.2

theorem validateLoopSpec_policyIndex_eq_headerType_at_offset_of_validateMaxType
    (input : BoundedValidateInput)
    (fuel off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (hSpec :
      ValidateLoopSpec input.view input.args.len input.args.maxtype
        input.args.policy input.args.strictStart input.args.validate
        input.args.extack 0 input.args.tb
        (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
        fuel off)
    (hAttr : input.wireAttrAt? off.toNat = some attr)
    (hMaxType : hasFlag input.args.validate validateMaxType)
    (hNoOverflow : input.args.maxtype.toNat + 1 < UInt64.size) :
    arrayIndexNospec (attrHeaderType (input.view.header off))
        (input.args.maxtype + 1) =
      attrHeaderType (input.view.header off) := by
  have hAttrBounds :=
    validateLoopSpec_wireAttr_type_bounds_at_offset_of_validateMaxType input
      fuel off attr hSpec hAttr hMaxType
  rcases validateBoundedRegionCore_wireAttr_header_fields input off.toNat
      attr hAttr with
    ⟨hHeaderFields, hTy, _hPayloadLen, _hNested⟩
  have hViewHeaderFields :
      input.view.header off =
        input.region.header off.toNat hHeaderFields :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderFields
  have hTypeLe :
      (attrHeaderType (input.view.header off)).toNat ≤
        input.args.maxtype.toNat := by
    rw [hViewHeaderFields, attrHeaderType_eq_memory]
    rw [← hTy]
    exact hAttrBounds.2
  exact arrayIndexNospec_eq_of_le_maxtype_no_overflow
    (attrHeaderType (input.view.header off)) input.args.maxtype hTypeLe
    hNoOverflow

theorem validateLoopSpec_known_continue_tail
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb fuel off :
      UInt64)
    (policyTable : PolicyTableView)
    (hSpec :
      ValidateLoopSpec view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off)
    (hFuel : fuel != 0)
    (hDepth : (depth >= maxPolicyRecursionDepth) = false)
    (hOff : (off == totalLen) = false)
    (hHeader : (off + nlaHeaderLen > totalLen) = false)
    (hLen : (attrHeaderLen (view.header off) < nlaHeaderLen) = false)
    (hOverrun :
      (off + attrHeaderLen (view.header off) > totalLen) = false)
    (hKnown :
      (attrHeaderType (view.header off) == 0 ||
        attrHeaderType (view.header off) > maxtype) = false)
    (hNext :
      (off + align4 (attrHeaderLen (view.header off)) > totalLen) = false) :
    ValidateLoopSpec view totalLen maxtype policy strictStart validate extack
      depth tb policyTable (fuel - 1)
      (off + align4 (attrHeaderLen (view.header off))) := by
  have hFuelNe : ¬(fuel == 0) = true := by
    simpa using hFuel
  rw [ValidateLoopSpec] at hSpec
  simp [hFuelNe, hDepth, hOff, hHeader, hLen, hOverrun, hKnown, hNext] at hSpec
  exact hSpec.2.2

theorem validateBoundedSpec_first_wireAttr_type_bounds_of_validateMaxType
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hSpec : ValidateBoundedSpec input)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    attr.ty ≠ 0 ∧ attr.ty ≤ input.args.maxtype.toNat := by
  have hEntry : (0, attr) ∈ Memory.Layout.entries 0 (attr :: rest) := by
    simp [Memory.Layout.entries]
  have hAt :
      input.wireAttrAt? 0 = some attr :=
    validateBoundedRegionCore_wireAttrs_entries_wireAttrAt? input
      (attr :: rest) hParse (0, attr) hEntry
  rcases validateBoundedRegionCore_wireAttr_header_fields input 0 attr hAt with
    ⟨hHeaderFields, hTy, _hPayloadLen, _hNested⟩
  rcases validateBoundedRegionCore_wireAttr_header_len_ge input 0 attr hAt with
    ⟨hHeaderLen, hLenGe⟩
  rcases validateBoundedRegionCore_wireAttr_declared_end_le input 0 attr hAt with
    ⟨hHeaderEnd, hEndLe⟩
  have hLoop :=
    validateBoundedSpec_loopSpec input hSpec
  have hFuel :=
    validateLoopSpec_fuel_ne_zero input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb
      (input.args.len + 1) 0
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hLoop
  have hDepth :
      ((0 : UInt64) >= maxPolicyRecursionDepth) = false := by
    decide
  have hOff : ((0 : UInt64) == input.args.len) = false := by
    apply u64_eq_false_of_toNat_ne
    intro hNatEq
    have hLenZero : input.args.len.toNat = 0 := by
      simpa using hNatEq.symm
    have hRegionNonzero : 0 < input.region.totalLen := by
      have hHeaderNat := hHeaderFields
      unfold Memory.Layout.headerLen Memory.nlaHeaderBytes at hHeaderNat
      omega
    rw [input.len_matches_region] at hLenZero
    omega
  have hShortHeader :
      ((0 : UInt64) + nlaHeaderLen > input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    simpa [nlaHeaderLen, Memory.Layout.headerLen,
      Memory.nlaHeaderBytes, input.len_matches_region] using hHeaderFields
  have hViewHeaderLen :
      input.view.header 0 = input.region.header 0 hHeaderLen :=
    BoundedValidateInput.view_header_eq_region_header input 0 hHeaderLen
  have hBadLen :
      (attrHeaderLen (input.view.header 0) < nlaHeaderLen) = false := by
    apply u64_lt_false_of_toNat_le
    rw [hViewHeaderLen, attrHeaderLen_eq_memory]
    simpa [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
      using hLenGe
  have hViewHeaderEnd :
      input.view.header 0 = input.region.header 0 hHeaderEnd :=
    BoundedValidateInput.view_header_eq_region_header input 0 hHeaderEnd
  have hOverrun :
      ((0 : UInt64) + attrHeaderLen (input.view.header 0) >
        input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
    simpa [input.len_matches_region] using hEndLe
  have hBounds :=
    validateLoopSpec_headerType_bounds_of_validateMaxType input.view
      input.args.len input.args.maxtype input.args.policy
      input.args.strictStart input.args.validate input.args.extack 0
      input.args.tb (input.args.len + 1) 0
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hLoop
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hMaxType
  have hViewHeaderFields :
      input.view.header 0 = input.region.header 0 hHeaderFields :=
    BoundedValidateInput.view_header_eq_region_header input 0 hHeaderFields
  have hTypeEq :
      (attrHeaderType (input.view.header 0)).toNat =
        (Memory.attrHeaderType
          (input.region.header 0 hHeaderFields)).toNat := by
    rw [hViewHeaderFields, attrHeaderType_eq_memory]
  constructor
  · intro hZero
    exact hBounds.1 (by
      rw [hTypeEq, ← hTy]
      exact hZero)
  · rw [hTy]
    rw [← hTypeEq]
    exact hBounds.2

theorem validateBoundedRegionCore_ok_first_wireAttr_type_bounds_of_validateMaxType
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    attr.ty ≠ 0 ∧ attr.ty ≤ input.args.maxtype.toNat := by
  exact
    validateBoundedSpec_first_wireAttr_type_bounds_of_validateMaxType input
      attr rest ((validateBoundedRegionCore_conforms_spec input).mp hOk)
      hParse hMaxType

theorem validateBoundedRegionCore_first_wireAttr_next_not_past_of_rest_ne_nil
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hRest : rest ≠ []) :
    ((0 : UInt64) + align4 (attrHeaderLen (input.view.header 0)) >
      input.args.len) = false := by
  have hAt :
      input.wireAttrAt? 0 = some attr :=
    validateBoundedRegionCore_wireAttrs_cons_head_wireAttrAt? input attr rest
      hParse
  rcases validateBoundedRegionCore_wireAttr_header_fields input 0 attr hAt with
    ⟨hHeader, _hTy, _hPayloadLen, _hNested⟩
  have hNextLe :
      0 + Memory.Layout.wireTotalSize attr ≤ input.region.totalLen :=
    validateBoundedRegionCore_wireAttrs_cons_next_le_of_rest_ne_nil input
      attr rest hParse hRest
  have hNextEq :
      Memory.Layout.wireTotalSize attr =
        (align4 (attrHeaderLen (input.view.header 0))).toNat :=
    wireAttr_totalSize_eq_align4_view_header input 0 attr hAt hHeader
  apply u64_gt_false_of_toNat_le
  simp
  rw [← hNextEq]
  rw [input.len_matches_region]
  simpa using hNextLe

theorem validateBoundedRegionCore_parseLoop_next_not_past_of_rest_ne_nil
    (input : BoundedValidateInput)
    (fuel : Nat)
    (off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region fuel off.toNat =
        some (attr :: rest))
    (hRest : rest ≠ []) :
    (off + align4 (attrHeaderLen (input.view.header off)) >
      input.args.len) = false := by
  have hAt :
      input.wireAttrAt? off.toNat = some attr :=
    validateBoundedRegionCore_parseLoop_cons_head_wireAttrAt? input fuel
      off.toNat attr rest hParse
  rcases validateBoundedRegionCore_wireAttr_header_fields input off.toNat
      attr hAt with
    ⟨hHeader, _hTy, _hPayloadLen, _hNested⟩
  have hNextLe :
      off.toNat + Memory.Layout.wireTotalSize attr ≤
        input.region.totalLen :=
    validateBoundedRegionCore_parseLoop_cons_next_le_of_rest_ne_nil input
      fuel off.toNat attr rest hParse hRest
  have hNextEq :
      Memory.Layout.wireTotalSize attr =
        (align4 (attrHeaderLen (input.view.header off))).toNat :=
    wireAttr_totalSize_eq_align4_view_header input off attr hAt hHeader
  have hAddNat :
      (off + align4 (attrHeaderLen (input.view.header off))).toNat =
        off.toNat + Memory.Layout.wireTotalSize attr := by
    have hNoOverflow :
        off.toNat +
            (align4 (attrHeaderLen (input.view.header off))).toNat <
          UInt64.size := by
      rw [← hNextEq]
      have hNextLeLen :
          off.toNat + Memory.Layout.wireTotalSize attr ≤
            input.args.len.toNat := by
        simpa [input.len_matches_region] using hNextLe
      exact Nat.lt_of_le_of_lt hNextLeLen
        (UInt64.toNat_lt_size input.args.len)
    calc
      (off + align4 (attrHeaderLen (input.view.header off))).toNat =
          off.toNat +
            (align4 (attrHeaderLen (input.view.header off))).toNat :=
        u64_add_toNat_of_lt_size off
          (align4 (attrHeaderLen (input.view.header off))) hNoOverflow
      _ = off.toNat + Memory.Layout.wireTotalSize attr := by
        rw [← hNextEq]
  apply u64_gt_false_of_toNat_le
  rw [hAddNat, input.len_matches_region]
  exact hNextLe

theorem validateBoundedRegionCore_parseLoop_next_offset_toNat
    (input : BoundedValidateInput)
    (fuel : Nat)
    (off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region fuel off.toNat =
        some (attr :: rest))
    (hNextLe :
      off.toNat + Memory.Layout.wireTotalSize attr ≤
        input.region.totalLen) :
    (off + align4 (attrHeaderLen (input.view.header off))).toNat =
      off.toNat + Memory.Layout.wireTotalSize attr := by
  have hAt :
      input.wireAttrAt? off.toNat = some attr :=
    validateBoundedRegionCore_parseLoop_cons_head_wireAttrAt? input fuel
      off.toNat attr rest hParse
  rcases validateBoundedRegionCore_wireAttr_header_fields input off.toNat
      attr hAt with
    ⟨hHeader, _hTy, _hPayloadLen, _hNested⟩
  have hNextEq :
      Memory.Layout.wireTotalSize attr =
        (align4 (attrHeaderLen (input.view.header off))).toNat :=
    wireAttr_totalSize_eq_align4_view_header input off attr hAt hHeader
  have hNoOverflow :
      off.toNat +
          (align4 (attrHeaderLen (input.view.header off))).toNat <
        UInt64.size := by
    rw [← hNextEq]
    have hNextLeLen :
        off.toNat + Memory.Layout.wireTotalSize attr ≤
          input.args.len.toNat := by
      simpa [input.len_matches_region] using hNextLe
    exact Nat.lt_of_le_of_lt hNextLeLen
      (UInt64.toNat_lt_size input.args.len)
  calc
    (off + align4 (attrHeaderLen (input.view.header off))).toNat =
        off.toNat +
          (align4 (attrHeaderLen (input.view.header off))).toNat :=
      u64_add_toNat_of_lt_size off
        (align4 (attrHeaderLen (input.view.header off))) hNoOverflow
    _ = off.toNat + Memory.Layout.wireTotalSize attr := by
      rw [← hNextEq]

theorem validateLoopSpec_tail_after_parseLoop_wireAttr_of_rest_ne_nil
    (input : BoundedValidateInput)
    (parseFuel : Nat)
    (fuel off : UInt64)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hSpec :
      ValidateLoopSpec input.view input.args.len input.args.maxtype
        input.args.policy input.args.strictStart input.args.validate
        input.args.extack 0 input.args.tb
        (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
        fuel off)
    (hParse :
      Memory.Layout.regionParseAttrsLoop input.region parseFuel off.toNat =
        some (attr :: rest))
    (hRest : rest ≠ [])
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    ValidateLoopSpec input.view input.args.len input.args.maxtype
      input.args.policy input.args.strictStart input.args.validate
      input.args.extack 0 input.args.tb
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
      (fuel - 1)
      (off + align4 (attrHeaderLen (input.view.header off))) := by
  have hAt :
      input.wireAttrAt? off.toNat = some attr :=
    validateBoundedRegionCore_parseLoop_cons_head_wireAttrAt? input
      parseFuel off.toNat attr rest hParse
  rcases validateBoundedRegionCore_wireAttr_header_fields input off.toNat
      attr hAt with
    ⟨hHeaderFields, _hTy, _hPayloadLen, _hNested⟩
  rcases validateBoundedRegionCore_wireAttr_header_len_ge input off.toNat
      attr hAt with
    ⟨hHeaderLen, hLenGe⟩
  rcases validateBoundedRegionCore_wireAttr_declared_end_le input off.toNat
      attr hAt with
    ⟨hHeaderEnd, hEndLe⟩
  have hFuel :=
    validateLoopSpec_fuel_ne_zero input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb fuel off
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hSpec
  have hDepth :
      ((0 : UInt64) >= maxPolicyRecursionDepth) = false := by
    decide
  have hOff : (off == input.args.len) = false := by
    apply u64_eq_false_of_toNat_ne
    intro hNatEq
    have hOffLt : off.toNat < input.args.len.toNat := by
      rw [input.len_matches_region]
      have hHeaderNat := hHeaderFields
      unfold Memory.Layout.headerLen Memory.nlaHeaderBytes at hHeaderNat
      omega
    omega
  have hHeaderAddNat :
      (off + nlaHeaderLen).toNat =
        off.toNat + Memory.Layout.headerLen := by
    have hNoOverflow :
        off.toNat + nlaHeaderLen.toNat < UInt64.size := by
      have hHeaderLe :
          off.toNat + nlaHeaderLen.toNat ≤ input.args.len.toNat := by
        simpa [nlaHeaderLen, Memory.Layout.headerLen,
          Memory.nlaHeaderBytes, input.len_matches_region] using hHeaderFields
      exact Nat.lt_of_le_of_lt hHeaderLe
        (UInt64.toNat_lt_size input.args.len)
    calc
      (off + nlaHeaderLen).toNat = off.toNat + nlaHeaderLen.toNat :=
        u64_add_toNat_of_lt_size off nlaHeaderLen hNoOverflow
      _ = off.toNat + Memory.Layout.headerLen := by
        simp [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
  have hShortHeader :
      (off + nlaHeaderLen > input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hHeaderAddNat, input.len_matches_region]
    exact hHeaderFields
  have hViewHeaderLen :
      input.view.header off = input.region.header off.toNat hHeaderLen :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderLen
  have hBadLen :
      (attrHeaderLen (input.view.header off) < nlaHeaderLen) = false := by
    apply u64_lt_false_of_toNat_le
    rw [hViewHeaderLen, attrHeaderLen_eq_memory]
    simpa [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
      using hLenGe
  have hViewHeaderEnd :
      input.view.header off = input.region.header off.toNat hHeaderEnd :=
    BoundedValidateInput.view_header_eq_region_header input off hHeaderEnd
  have hDeclaredAddNat :
      (off + attrHeaderLen (input.view.header off)).toNat =
        off.toNat +
          (Memory.attrHeaderLen
            (input.region.header off.toNat hHeaderEnd)).toNat := by
    have hNoOverflow :
        off.toNat +
            (attrHeaderLen (input.view.header off)).toNat <
          UInt64.size := by
      rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
      have hEndLeLen :
          off.toNat +
              (Memory.attrHeaderLen
                (input.region.header off.toNat hHeaderEnd)).toNat ≤
            input.args.len.toNat := by
        simpa [input.len_matches_region] using hEndLe
      exact Nat.lt_of_le_of_lt hEndLeLen
        (UInt64.toNat_lt_size input.args.len)
    calc
      (off + attrHeaderLen (input.view.header off)).toNat =
          off.toNat + (attrHeaderLen (input.view.header off)).toNat :=
        u64_add_toNat_of_lt_size off
          (attrHeaderLen (input.view.header off)) hNoOverflow
      _ = off.toNat +
          (Memory.attrHeaderLen
            (input.region.header off.toNat hHeaderEnd)).toNat := by
        rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
  have hOverrun :
      (off + attrHeaderLen (input.view.header off) >
        input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hDeclaredAddNat, input.len_matches_region]
    exact hEndLe
  have hKnown :=
    validateLoopSpec_known_header_of_validateMaxType input.view
      input.args.len input.args.maxtype input.args.policy
      input.args.strictStart input.args.validate input.args.extack 0
      input.args.tb fuel off
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hSpec
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hMaxType
  have hNext :=
    validateBoundedRegionCore_parseLoop_next_not_past_of_rest_ne_nil input
      parseFuel off attr rest hParse hRest
  exact
    validateLoopSpec_known_continue_tail input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb fuel off
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hSpec
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hKnown hNext

theorem validateLoopSpec_parseLoop_entries_type_bounds_of_validateMaxType
    (input : BoundedValidateInput) :
    ∀ (attrs : List Memory.Layout.WireAttr) (parseFuel : Nat)
      (loopFuel off : UInt64),
      ValidateLoopSpec input.view input.args.len input.args.maxtype
        input.args.policy input.args.strictStart input.args.validate
        input.args.extack 0 input.args.tb
        (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
        loopFuel off →
      Memory.Layout.regionParseAttrsLoop input.region parseFuel off.toNat =
        some attrs →
      hasFlag input.args.validate validateMaxType →
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries off.toNat attrs →
          entry.2.ty ≠ 0 ∧ entry.2.ty ≤ input.args.maxtype.toNat := by
  intro attrs
  induction attrs with
  | nil =>
      intro parseFuel loopFuel off _hSpec _hParse _hMaxType entry hEntry
      simp [Memory.Layout.entries] at hEntry
  | cons attr rest ih =>
      intro parseFuel loopFuel off hSpec hParse hMaxType entry hEntry
      simp [Memory.Layout.entries] at hEntry
      rcases hEntry with hHead | hTail
      · subst entry
        have hAt :
            input.wireAttrAt? off.toNat = some attr :=
          validateBoundedRegionCore_parseLoop_cons_head_wireAttrAt? input
            parseFuel off.toNat attr rest hParse
        exact
          validateLoopSpec_wireAttr_type_bounds_at_offset_of_validateMaxType
            input loopFuel off attr hSpec hAt hMaxType
      · have hRestNe : rest ≠ [] := by
          intro hNil
          subst rest
          simp [Memory.Layout.entries] at hTail
        have hNextLe :
            off.toNat + Memory.Layout.wireTotalSize attr ≤
              input.region.totalLen :=
          validateBoundedRegionCore_parseLoop_cons_next_le_of_rest_ne_nil
            input parseFuel off.toNat attr rest hParse hRestNe
        rcases
          validateBoundedRegionCore_parseLoop_cons_tail_of_next_le input
            parseFuel off.toNat attr rest hParse hNextLe
          with ⟨parseFuel', _hFuelEq, hTailParse⟩
        have hTailSpec :
            ValidateLoopSpec input.view input.args.len input.args.maxtype
              input.args.policy input.args.strictStart input.args.validate
              input.args.extack 0 input.args.tb
              (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
              (loopFuel - 1)
              (off + align4 (attrHeaderLen (input.view.header off))) :=
          validateLoopSpec_tail_after_parseLoop_wireAttr_of_rest_ne_nil
            input parseFuel loopFuel off attr rest hSpec hParse hRestNe
            hMaxType
        have hNextToNat :
            (off + align4 (attrHeaderLen (input.view.header off))).toNat =
              off.toNat + Memory.Layout.wireTotalSize attr :=
          validateBoundedRegionCore_parseLoop_next_offset_toNat input
            parseFuel off attr rest hParse hNextLe
        have hTailParseU :
            Memory.Layout.regionParseAttrsLoop input.region parseFuel'
              (off + align4 (attrHeaderLen (input.view.header off))).toNat =
                some rest := by
          rw [hNextToNat]
          exact hTailParse
        have hTailEntryU :
            entry ∈ Memory.Layout.entries
              (off + align4 (attrHeaderLen (input.view.header off))).toNat
              rest := by
          simpa [Memory.Layout.nextOff, hNextToNat] using hTail
        exact
          ih parseFuel' (loopFuel - 1)
            (off + align4 (attrHeaderLen (input.view.header off)))
            hTailSpec hTailParseU hMaxType entry hTailEntryU

theorem validateBoundedRegionCore_ok_wireAttrsAllowedByMaxType_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs) :
    input.WireAttrsAllowedByMaxType attrs := by
  unfold BoundedValidateInput.WireAttrsAllowedByMaxType
  by_cases hMaxType : hasFlag input.args.validate validateMaxType
  · simp only [hMaxType, if_true]
    intro entry hEntry
    have hSpec : ValidateBoundedSpec input :=
      (validateBoundedRegionCore_conforms_spec input).mp hOk
    have hLoop :=
      validateBoundedSpec_loopSpec input hSpec
    have hParseLoop :
        Memory.Layout.regionParseAttrsLoop input.region
          (input.region.totalLen + 1) 0 = some attrs := by
      simpa [BoundedValidateInput.wireAttrs?,
        Memory.Layout.regionParseAttrs?] using hParse
    exact
      validateLoopSpec_parseLoop_entries_type_bounds_of_validateMaxType
        input attrs (input.region.totalLen + 1) (input.args.len + 1)
        0 hLoop hParseLoop hMaxType entry hEntry
  · have hMaxTypeFalse :
        hasFlag input.args.validate validateMaxType = false := by
      cases hFlag : hasFlag input.args.validate validateMaxType <;>
        simp [hFlag] at hMaxType ⊢
    simp [hMaxTypeFalse]

theorem validateBoundedRegionCore_ok_wireMaxTypeSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs) :
    ValidateBoundedSpec input ∧ input.WireMaxTypeSpec attrs := by
  exact ⟨
    (validateBoundedRegionCore_conforms_spec input).mp hOk,
    validateBoundedRegionCore_wireMessageSpec_of_parse input attrs hParse,
    validateBoundedRegionCore_ok_wireAttrsAllowedByMaxType_of_parse input
      attrs hOk hParse⟩

theorem validateBoundedRegionCore_ok_wirePolicyIndexSpec_of_parse
    (input : BoundedValidateInput)
    (attrs : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some attrs) :
    ValidateBoundedSpec input ∧ input.WirePolicyIndexSpec attrs := by
  have hMaxSpec :=
    validateBoundedRegionCore_ok_wireMaxTypeSpec_of_parse input attrs hOk
      hParse
  exact ⟨hMaxSpec.1,
    wirePolicyIndexSpec_of_wireMaxTypeSpec input attrs hMaxSpec.2⟩

theorem validateBoundedSpec_tail_loopSpec_after_first_wireAttr_of_rest_ne_nil
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hSpec : ValidateBoundedSpec input)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hRest : rest ≠ [])
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    ValidateLoopSpec input.view input.args.len input.args.maxtype
      input.args.policy input.args.strictStart input.args.validate
      input.args.extack 0 input.args.tb
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
      (input.args.len + 1 - 1)
      ((0 : UInt64) + align4 (attrHeaderLen (input.view.header 0))) := by
  have hAt :
      input.wireAttrAt? 0 = some attr :=
    validateBoundedRegionCore_wireAttrs_cons_head_wireAttrAt? input attr rest
      hParse
  rcases validateBoundedRegionCore_wireAttr_header_fields input 0 attr hAt with
    ⟨hHeaderFields, _hTy, _hPayloadLen, _hNested⟩
  rcases validateBoundedRegionCore_wireAttr_header_len_ge input 0 attr hAt with
    ⟨hHeaderLen, hLenGe⟩
  rcases validateBoundedRegionCore_wireAttr_declared_end_le input 0 attr hAt with
    ⟨hHeaderEnd, hEndLe⟩
  have hLoop :=
    validateBoundedSpec_loopSpec input hSpec
  have hFuel :=
    validateLoopSpec_fuel_ne_zero input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb
      (input.args.len + 1) 0
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hLoop
  have hDepth :
      ((0 : UInt64) >= maxPolicyRecursionDepth) = false := by
    decide
  have hOff : ((0 : UInt64) == input.args.len) = false := by
    apply u64_eq_false_of_toNat_ne
    intro hNatEq
    have hLenZero : input.args.len.toNat = 0 := by
      simpa using hNatEq.symm
    have hRegionNonzero : 0 < input.region.totalLen := by
      have hHeaderNat := hHeaderFields
      unfold Memory.Layout.headerLen Memory.nlaHeaderBytes at hHeaderNat
      omega
    rw [input.len_matches_region] at hLenZero
    omega
  have hShortHeader :
      ((0 : UInt64) + nlaHeaderLen > input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    simpa [nlaHeaderLen, Memory.Layout.headerLen,
      Memory.nlaHeaderBytes, input.len_matches_region] using hHeaderFields
  have hViewHeaderLen :
      input.view.header 0 = input.region.header 0 hHeaderLen :=
    BoundedValidateInput.view_header_eq_region_header input 0 hHeaderLen
  have hBadLen :
      (attrHeaderLen (input.view.header 0) < nlaHeaderLen) = false := by
    apply u64_lt_false_of_toNat_le
    rw [hViewHeaderLen, attrHeaderLen_eq_memory]
    simpa [nlaHeaderLen, Memory.Layout.headerLen, Memory.nlaHeaderBytes]
      using hLenGe
  have hViewHeaderEnd :
      input.view.header 0 = input.region.header 0 hHeaderEnd :=
    BoundedValidateInput.view_header_eq_region_header input 0 hHeaderEnd
  have hOverrun :
      ((0 : UInt64) + attrHeaderLen (input.view.header 0) >
        input.args.len) = false := by
    apply u64_gt_false_of_toNat_le
    rw [hViewHeaderEnd, attrHeaderLen_eq_memory]
    simpa [input.len_matches_region] using hEndLe
  have hKnown :=
    validateLoopSpec_known_header_of_validateMaxType input.view
      input.args.len input.args.maxtype input.args.policy
      input.args.strictStart input.args.validate input.args.extack 0
      input.args.tb (input.args.len + 1) 0
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hLoop
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hMaxType
  have hNext :=
    validateBoundedRegionCore_first_wireAttr_next_not_past_of_rest_ne_nil
      input attr rest hParse hRest
  exact
    validateLoopSpec_known_continue_tail input.view input.args.len
      input.args.maxtype input.args.policy input.args.strictStart
      input.args.validate input.args.extack 0 input.args.tb
      (input.args.len + 1) 0
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype) hLoop
      hFuel hDepth hOff hShortHeader hBadLen hOverrun hKnown hNext

theorem validateBoundedRegionCore_ok_tail_loopSpec_after_first_wireAttr_of_rest_ne_nil
    (input : BoundedValidateInput)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hOk : validateBoundedRegionCore input = ok)
    (hParse : input.wireAttrs? = some (attr :: rest))
    (hRest : rest ≠ [])
    (hMaxType : hasFlag input.args.validate validateMaxType) :
    ValidateLoopSpec input.view input.args.len input.args.maxtype
      input.args.policy input.args.strictStart input.args.validate
      input.args.extack 0 input.args.tb
      (PolicyTableView.ofRaw input.args.policy input.args.maxtype)
      (input.args.len + 1 - 1)
      ((0 : UInt64) + align4 (attrHeaderLen (input.view.header 0))) := by
  exact
    validateBoundedSpec_tail_loopSpec_after_first_wireAttr_of_rest_ne_nil
      input attr rest ((validateBoundedRegionCore_conforms_spec input).mp hOk)
      hParse hRest hMaxType

theorem validateParseCore_nonzero_eq_validateBoundedRegionCore
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat) :
    validateParseCore head len maxtype policy strictStart validate extack tb =
      validateBoundedRegionCore
        (BoundedValidateInput.ofRaw head len maxtype policy strictStart
          validate extack tb hLen) := by
  have hHeadNe : head ≠ 0 := by
    intro hEq
    simp [hEq] at hHead
  cases hUnsupported : unsupportedValidateFlags validate <;>
    simp [validateParseCore, validateRegionCore, validateBoundedRegionCore,
      BoundedValidateInput.view, _root_.LeanNlAttr.validateViewCore,
      AttrView.ofRegion, validateArgs, BoundedValidateInput.ofRaw, hHeadNe,
      hUnsupported]

theorem validateParseCore_spatialSafety_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat) :
    exists input : BoundedValidateInput,
      validateParseCore head len maxtype policy strictStart validate extack tb =
        validateBoundedRegionCore input ∧
      ValidateInputSpatialSafety input := by
  let input : BoundedValidateInput :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  exact ⟨input,
    validateParseCore_nonzero_eq_validateBoundedRegionCore
      head len maxtype policy strictStart validate extack tb hHead hLen,
    validateBoundedRegionCore_spatialSafety input⟩

theorem validateParseCore_nonzero_ok_wireMessageSpec_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    ValidateParseSpec head len maxtype policy strictStart validate extack tb ∧
      input.WireMessageSpec attrs := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact ⟨
    (validateParseCore_conforms_spec head len maxtype policy strictStart
      validate extack tb).mp hOk,
    (validateBoundedRegionCore_ok_wireMessageSpec_of_parse input attrs
      hBoundedOk hInputParse).2⟩

theorem validateParseCore_nonzero_ok_wireMaxTypeSpec_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    ValidateParseSpec head len maxtype policy strictStart validate extack tb ∧
      input.WireMaxTypeSpec attrs := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact ⟨
    (validateParseCore_conforms_spec head len maxtype policy strictStart
      validate extack tb).mp hOk,
    (validateBoundedRegionCore_ok_wireMaxTypeSpec_of_parse input attrs
      hBoundedOk hInputParse).2⟩

theorem validateParseCore_nonzero_ok_wireByteBoundsSpec_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    ValidateParseSpec head len maxtype policy strictStart validate extack tb ∧
      input.WireByteBoundsSpec attrs := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact ⟨
    (validateParseCore_conforms_spec head len maxtype policy strictStart
      validate extack tb).mp hOk,
    (validateBoundedRegionCore_ok_wireByteBoundsSpec_of_parse input attrs
      hBoundedOk hInputParse).2⟩

theorem validateParseCore_nonzero_ok_wirePolicyIndexSpec_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    ValidateParseSpec head len maxtype policy strictStart validate extack tb ∧
      input.WirePolicyIndexSpec attrs := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact ⟨
    (validateParseCore_conforms_spec head len maxtype policy strictStart
      validate extack tb).mp hOk,
    (validateBoundedRegionCore_ok_wirePolicyIndexSpec_of_parse input attrs
      hBoundedOk hInputParse).2⟩

theorem validateParseCore_nonzero_ok_entries_type_bounds_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok)
    (hMaxType : hasFlag validate validateMaxType)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs) :
    entry.2.ty ≠ 0 ∧ entry.2.ty ≤ maxtype.toNat := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  have hAllowed :=
    validateBoundedRegionCore_ok_wireAttrsAllowedByMaxType_of_parse input attrs
      hBoundedOk hInputParse
  unfold BoundedValidateInput.WireAttrsAllowedByMaxType at hAllowed
  have hInputMaxType : hasFlag input.args.validate validateMaxType := by
    simpa [input, BoundedValidateInput.ofRaw, validateArgs] using hMaxType
  have hAllowedForall :
      ∀ (entry : Nat × Memory.Layout.WireAttr),
        entry ∈ Memory.Layout.entries 0 attrs →
          entry.2.ty ≠ 0 ∧
            entry.2.ty ≤ input.args.maxtype.toNat := by
    simpa [hInputMaxType] using hAllowed
  have hBounds := hAllowedForall entry hEntry
  simpa [input, BoundedValidateInput.ofRaw, validateArgs] using hBounds

theorem validateParseCore_wireAttrs_header_byte_bounds_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs)
    (ix : Nat)
    (hIx : ix < Memory.Layout.headerLen) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    entry.1 + ix < input.region.totalLen := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact validateBoundedRegionCore_wireAttrs_header_byte_bounds input attrs
    hInputParse entry hEntry ix hIx

theorem validateParseCore_wireAttrs_payload_byte_bounds_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attrs : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some attrs)
    (entry : Nat × Memory.Layout.WireAttr)
    (hEntry : entry ∈ Memory.Layout.entries 0 attrs)
    (ix : Nat)
    (hIx : ix < entry.2.payloadLen) :
    let input :=
      BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
        extack tb hLen
    entry.1 + Memory.Layout.headerLen + ix < input.region.totalLen := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hInputParse : input.wireAttrs? = some attrs := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  exact validateBoundedRegionCore_wireAttrs_payload_byte_bounds input attrs
    hInputParse entry hEntry ix hIx

theorem validateParseCore_nonzero_ok_first_wireAttr_type_bounds_of_rawRegion
    (head len maxtype policy strictStart validate extack tb : UInt64)
    (hHead : head != 0)
    (hLen : (rawRegion head len).totalLen = len.toNat)
    (attr : Memory.Layout.WireAttr)
    (rest : List Memory.Layout.WireAttr)
    (hParse : Memory.Layout.regionParseAttrs? (rawRegion head len) =
      some (attr :: rest))
    (hOk :
      validateParseCore head len maxtype policy strictStart validate extack
        tb = ok)
    (hMaxType : hasFlag validate validateMaxType) :
    attr.ty ≠ 0 ∧ attr.ty ≤ maxtype.toNat := by
  let input :=
    BoundedValidateInput.ofRaw head len maxtype policy strictStart validate
      extack tb hLen
  have hEq :
      validateParseCore head len maxtype policy strictStart validate extack
          tb =
        validateBoundedRegionCore input := by
    simpa [input] using
      validateParseCore_nonzero_eq_validateBoundedRegionCore head len maxtype
        policy strictStart validate extack tb hHead hLen
  have hBoundedOk : validateBoundedRegionCore input = ok := by
    rw [← hEq]
    exact hOk
  have hInputParse : input.wireAttrs? = some (attr :: rest) := by
    simpa [input, BoundedValidateInput.ofRaw, BoundedValidateInput.wireAttrs?]
      using hParse
  simpa [input, BoundedValidateInput.ofRaw, validateArgs] using
    validateBoundedRegionCore_ok_first_wireAttr_type_bounds_of_validateMaxType
      input attr rest hBoundedOk hInputParse hMaxType

theorem viewValidateLoop_total
    (view : AttrView)
    (totalLen maxtype policy strictStart validate extack depth tb : UInt64)
    (policyTable : PolicyTableView)
    (fuel off : UInt64) :
    exists result : UInt64,
      viewValidateLoop view totalLen maxtype policy strictStart validate
        extack depth tb policyTable fuel off = result :=
  Exists.intro
    (viewValidateLoop view totalLen maxtype policy strictStart validate
      extack depth tb policyTable fuel off)
    rfl

theorem validateParseCore_total
    (head len maxtype policy strictStart validate extack tb : UInt64) :
    exists result : UInt64,
      validateParseCore head len maxtype policy strictStart validate extack tb =
        result :=
  Exists.intro
    (validateParseCore head len maxtype policy strictStart validate extack tb)
    rfl

theorem validateBoundedRegionCore_total (input : BoundedValidateInput) :
    exists result : UInt64,
      validateBoundedRegionCore input = result :=
  Exists.intro (validateBoundedRegionCore input) rfl

theorem validateParseCore_headline
    (head len maxtype policy strictStart validate extack tb : UInt64) :
    AttributeSpatialSafety (AttrView.ofRaw head len) ∧
      (exists result : UInt64,
        validateParseCore head len maxtype policy strictStart validate extack tb =
          result) ∧
      (validateParseCore head len maxtype policy strictStart validate extack tb =
          ok ↔
        ValidateParseSpec head len maxtype policy strictStart validate
          extack tb) := by
  exact ⟨
    validateParseCore_attributeSpatialSafety head len maxtype policy strictStart
      validate extack tb,
    validateParseCore_total head len maxtype policy strictStart validate extack
      tb,
    validateParseCore_conforms_spec head len maxtype policy strictStart validate
      extack tb⟩

theorem validateBoundedRegionCore_headline (input : BoundedValidateInput) :
    ValidateInputSpatialSafety input ∧
      (exists result : UInt64, validateBoundedRegionCore input = result) ∧
      (validateBoundedRegionCore input = ok ↔ ValidateBoundedSpec input) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        validateBoundedRegionCore input = ok →
          input.wireAttrs? = some attrs →
            ValidateBoundedSpec input ∧ input.WireMessageSpec attrs) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        validateBoundedRegionCore input = ok →
          input.wireAttrs? = some attrs →
            ValidateBoundedSpec input ∧ input.WireMaxTypeSpec attrs) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        validateBoundedRegionCore input = ok →
          input.wireAttrs? = some attrs →
            ValidateBoundedSpec input ∧ input.WireByteBoundsSpec attrs) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        validateBoundedRegionCore input = ok →
          input.wireAttrs? = some attrs →
            ValidateBoundedSpec input ∧ input.WirePolicyIndexSpec attrs) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          input.WireStructuralSpec) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          input.WireStreamMatches attrs) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          ∀ (entry : Nat × Memory.Layout.WireAttr),
            entry ∈ Memory.Layout.entries 0 attrs →
              Memory.Layout.payloadFits input.region.totalLen entry.1 entry.2) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          ∀ (entry : Nat × Memory.Layout.WireAttr),
            entry ∈ Memory.Layout.entries 0 attrs →
              ∀ (ix : Nat),
                ix < Memory.Layout.headerLen →
                  entry.1 + ix < input.region.totalLen) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          ∀ (entry : Nat × Memory.Layout.WireAttr),
            entry ∈ Memory.Layout.entries 0 attrs →
              ∀ (ix : Nat),
                ix < entry.2.payloadLen →
                  entry.1 + Memory.Layout.headerLen + ix <
                    input.region.totalLen) ∧
      (∀ (attrs : List Memory.Layout.WireAttr),
        input.wireAttrs? = some attrs →
          ∀ (entry : Nat × Memory.Layout.WireAttr),
            entry ∈ Memory.Layout.entries 0 attrs →
              ∃ hHeader :
                entry.1 + Memory.Layout.headerLen ≤ input.region.totalLen,
                let header := input.region.header entry.1 hHeader
                entry.2.ty = (Memory.attrHeaderType header).toNat ∧
                  entry.2.payloadLen = (Memory.attrHeaderLen header).toNat -
                    Memory.Layout.headerLen ∧
                  entry.2.nested = (Memory.attrHeaderIsNested header != 0)) ∧
      (∀ (off : Nat) (attr : Memory.Layout.WireAttr),
        input.wireAttrAt? off = some attr →
          ∃ hHeader : off + Memory.Layout.headerLen ≤ input.region.totalLen,
            let header := input.region.header off hHeader
            attr.ty = (Memory.attrHeaderType header).toNat ∧
              attr.payloadLen = (Memory.attrHeaderLen header).toNat -
                Memory.Layout.headerLen ∧
              attr.nested = (Memory.attrHeaderIsNested header != 0)) := by
  exact ⟨
    validateBoundedRegionCore_spatialSafety input,
    validateBoundedRegionCore_total input,
    validateBoundedRegionCore_conforms_spec input,
    validateBoundedRegionCore_ok_wireMessageSpec_of_parse input,
    validateBoundedRegionCore_ok_wireMaxTypeSpec_of_parse input,
    validateBoundedRegionCore_ok_wireByteBoundsSpec_of_parse input,
    validateBoundedRegionCore_ok_wirePolicyIndexSpec_of_parse input,
    validateBoundedRegionCore_wireStructuralSpec_of_parse input,
    validateBoundedRegionCore_wireAttrs_matchesRegion input,
    validateBoundedRegionCore_wireAttrs_payloadFits input,
    validateBoundedRegionCore_wireAttrs_header_byte_bounds input,
    validateBoundedRegionCore_wireAttrs_payload_byte_bounds input,
    validateBoundedRegionCore_wireAttrs_entries_header_fields input,
    validateBoundedRegionCore_wireAttr_header_fields input⟩

end Verified

@[export lean_nlattr_memcmp_core]
def memcmpCore (nla data size : UInt64) : UInt64 :=
  if nla == 0 || data == 0 || size > intMax then
    cmpUnsupported
  else
    let declaredLen := nlattrDeclaredLen nla
    let payloadLen := nlattrPayloadLenFromDeclared declaredLen
    if payloadLen == cmpUnsupported || payloadLen > intMax then
      cmpUnsupported
    else
      let diff := cmpEncodeDiff payloadLen size
      if diff != 0 then
        diff
      else
        viewAttrMemcmp (nlattrFullView nla declaredLen) data size

@[export lean_nlattr_memcpy_core]
def memcpyCore (dest src count : UInt64) : UInt64 :=
  if dest == 0 || src == 0 || count > intMax then
    cmpUnsupported
  else
    let declaredLen := nlattrDeclaredLen src
    let payloadLen := nlattrPayloadLenFromDeclared declaredLen
    if payloadLen == cmpUnsupported || payloadLen > intMax then
      cmpUnsupported
    else
      let view := nlattrFullView src declaredLen
      let copyLen := min64 count payloadLen
      let ret := viewAttrCopy dest view copyLen
      if ret != 0 then
        ret
      else if count > copyLen then
        let ret := zeroBytes dest copyLen (count - copyLen)
        if ret != 0 then ret else copyLen
      else
        copyLen

@[export lean_nlattr_strscpy_core]
def strscpyCore (dst nla dstsize : UInt64) : UInt64 :=
  if dst == 0 || nla == 0 then
    cmpUnsupported
  else if dstsize == 0 || dstsize > u16Max then
    cmpNegative + e2big
  else
    let declaredLen := nlattrDeclaredLen nla
    let payloadLen := nlattrPayloadLenFromDeclared declaredLen
    if payloadLen == cmpUnsupported || payloadLen > intMax then
      cmpUnsupported
    else
      let view := nlattrFullView nla declaredLen
      let srcLen := viewTrimOneTrailingZero view payloadLen
      let copyLen := if srcLen >= dstsize then dstsize - 1 else srcLen
      let status := if srcLen >= dstsize then cmpNegative + e2big else srcLen
      let ret := viewAttrCopy dst view copyLen
      if ret != 0 then
        ret
      else
        let ret := zeroBytes dst copyLen (dstsize - copyLen)
        if ret != 0 then ret else status

@[export lean_nlattr_strcmp_core]
def strcmpCore (nla str : UInt64) : UInt64 :=
  if nla == 0 || str == 0 then
    cmpUnsupported
  else
    let declaredLen := nlattrDeclaredLen nla
    let payloadLen := nlattrPayloadLenFromDeclared declaredLen
    let strLen := cstrLen str
    if payloadLen == cmpUnsupported || payloadLen > intMax || strLen > intMax then
      cmpUnsupported
    else
      let view := nlattrFullView nla declaredLen
      let attrLen := viewTrimTrailingZeros view payloadLen (payloadLen + 1)
      let diff := cmpEncodeDiff attrLen strLen
      if diff != 0 then
        diff
      else
        viewAttrMemcmp view str strLen

@[export lean_nlattr_policy_len_core]
def policyLenCore (policy count : UInt64) : UInt64 :=
  if policy == 0 then
    0
  else
    policyLenLoop policy count 0 0 (count + 1)

@[export lean_nlattr_str_payload_len_core]
def strPayloadLenCore (nla : UInt64) : UInt64 :=
  if nla == 0 then
    cmpUnsupported
  else
    let declaredLen := nlattrDeclaredLen nla
    let payloadLen := nlattrPayloadLenFromDeclared declaredLen
    if payloadLen == cmpUnsupported || payloadLen > intMax then
      cmpUnsupported
    else
      viewTrimOneTrailingZero (nlattrFullView nla declaredLen) payloadLen

@[export lean_nlattr_range_unsigned_supported_core]
def rangeUnsignedSupportedCore (ty : UInt64) : UInt64 :=
  if isUnsignedRangeType ty then 1 else 0

@[export lean_nlattr_range_unsigned_min_core]
def rangeUnsignedMinCore
    (ty validation policyMin rangeMin : UInt64) : UInt64 :=
  if !isUnsignedRangeType ty then
    0
  else if validation == policyValidateRange ||
      validation == policyValidateRangeWarnTooLong then
    policyMin
  else if validation == policyValidateRangePtr then
    rangeMin
  else if validation == policyValidateMin then
    policyMin
  else
    0

@[export lean_nlattr_range_unsigned_max_core]
def rangeUnsignedMaxCore
    (ty validation policyMax rangeMax : UInt64) : UInt64 :=
  if !isUnsignedRangeType ty then
    0
  else if validation == policyValidateRange ||
      validation == policyValidateRangeWarnTooLong then
    policyMax
  else if validation == policyValidateRangePtr then
    rangeMax
  else if validation == policyValidateMax then
    policyMax
  else
    unsignedRangeDefaultMax ty

@[export lean_nlattr_range_signed_supported_core]
def rangeSignedSupportedCore (ty : UInt64) : UInt64 :=
  if isSignedRangeType ty then 1 else 0

@[export lean_nlattr_range_signed_min_core]
def rangeSignedMinCore
    (ty validation policyMin rangeMin : UInt64) : UInt64 :=
  if !isSignedRangeType ty then
    0
  else if validation == policyValidateRange then
    policyMin
  else if validation == policyValidateRangePtr then
    rangeMin
  else if validation == policyValidateMin then
    policyMin
  else
    signedRangeDefaultMin ty

@[export lean_nlattr_range_signed_max_core]
def rangeSignedMaxCore
    (ty validation policyMax rangeMax : UInt64) : UInt64 :=
  if !isSignedRangeType ty then
    0
  else if validation == policyValidateRange then
    policyMax
  else if validation == policyValidateRangePtr then
    rangeMax
  else if validation == policyValidateMax then
    policyMax
  else
    signedRangeDefaultMax ty

@[export lean_nlattr_builder_required_core]
def builderRequiredCore (attrLen flags : UInt64) : UInt64 :=
  builderRequiredSize attrLen flags

@[export lean_nlattr_builder_attr_size_core]
def builderAttrSizeCore (attrLen : UInt64) : UInt64 :=
  nlaAttrSize attrLen

@[export lean_nlattr_builder_padlen_core]
def builderPadLenCore (attrLen : UInt64) : UInt64 :=
  nlaPadLen attrLen

@[export lean_nlattr_builder_status_core]
def builderStatusCore (tailroom attrLen flags : UInt64) : UInt64 :=
  builderStatus tailroom attrLen flags

def kernelErr (errno : UInt64) : UInt64 :=
  0 - errno

def decodeStatusForKernel (code : UInt64) : UInt64 :=
  if code == unsupported then
    kernelErr eopnotsupp
  else if (code &&& errnoFlag) != 0 then
    let errno := code &&& 0xffffffff
    if errno == 0 || errno > intMax then kernelErr einval else kernelErr errno
  else if code == ok then
    ok
  else if code > intMax then
    kernelErr einval
  else
    kernelErr code

def decodeCmpForKernel (code : UInt64) : UInt64 :=
  if code == cmpUnsupported then
    intMinReturn
  else
    let mag := code &&& (0xffffffffffffffff - cmpNegative)
    if mag > intMax then
      intMinReturn
    else if (code &&& cmpNegative) != 0 then
      kernelErr mag
    else
      mag

def publicValidateParse
    (head len maxtype policy validate extack tb : UInt64) : UInt64 :=
  if len > intMax || maxtype > intMax then
    kernelErr eopnotsupp
  else
    let strictStart := if policy == 0 then 0 else policyStrictStart policy
    let clear :=
      if tb == 0 then
        0
      else
        zeroTable tb (maxtype + 1)
    if clear != 0 then
      kernelErr einval
    else
      decodeStatusForKernel
        (validateParseCore head len maxtype policy strictStart validate extack tb)

@[export lean_public___nla_validate]
def publicNlaValidate
    (head len maxtype policy validate extack : UInt64) : UInt64 :=
  publicValidateParse head len maxtype policy validate extack 0

@[export lean_public___nla_parse]
def publicNlaParse
    (tb maxtype head len policy validate extack : UInt64) : UInt64 :=
  publicValidateParse head len maxtype policy validate extack tb

namespace Verified

theorem publicNlaValidate_bounded_eq_decodeValidateParseCore
    (head len maxtype policy validate extack : UInt64)
    (hLen : (len > intMax) = false)
    (hMaxtype : (maxtype > intMax) = false) :
    publicNlaValidate head len maxtype policy validate extack =
      decodeStatusForKernel
        (validateParseCore head len maxtype policy
          (if policy == 0 then 0 else policyStrictStart policy)
          validate extack 0) := by
  simp [publicNlaValidate, publicValidateParse, hLen, hMaxtype]

theorem publicNlaParse_bounded_eq_decodeValidateParseCore
    (tb maxtype head len policy validate extack : UInt64)
    (hLen : (len > intMax) = false)
    (hMaxtype : (maxtype > intMax) = false)
    (hClear :
      (if tb == 0 then 0 else zeroTable tb (maxtype + 1)) = 0) :
    publicNlaParse tb maxtype head len policy validate extack =
      decodeStatusForKernel
        (validateParseCore head len maxtype policy
          (if policy == 0 then 0 else policyStrictStart policy)
          validate extack tb) := by
  by_cases hTb : tb = 0
  · simp [publicNlaParse, publicValidateParse, hLen, hMaxtype, hTb]
  · have hTbBool : (tb == 0) = false := by
      simp [hTb]
    have hZeroTable : zeroTable tb (maxtype + 1) = 0 := by
      simpa [hTbBool] using hClear
    simp [publicNlaParse, publicValidateParse, hLen, hMaxtype, hTbBool,
      hZeroTable]

end Verified

@[export nla_find]
def publicNlaFind (head len attrtype : UInt64) : UInt64 :=
  if len > intMax || attrtype > intMax then
    0
  else
    findCore head len attrtype

@[export nla_memcmp]
def publicNlaMemcmp (nla data size : UInt64) : UInt64 :=
  decodeCmpForKernel (memcmpCore nla data size)

@[export nla_memcpy]
def publicNlaMemcpy (dest src count : UInt64) : UInt64 :=
  if count > intMax then
    intMinReturn
  else
    decodeCmpForKernel (memcpyCore dest src count)

@[export nla_strscpy]
def publicNlaStrscpy (dst nla dstsize : UInt64) : UInt64 :=
  decodeCmpForKernel (strscpyCore dst nla dstsize)

@[export nla_strcmp]
def publicNlaStrcmp (nla str : UInt64) : UInt64 :=
  decodeCmpForKernel (strcmpCore nla str)

@[export nla_policy_len]
def publicNlaPolicyLen (policy count : UInt64) : UInt64 :=
  if count > intMax then
    kernelErr 1
  else if count == 0 then
    0
  else
    let ret := policyLenCore policy count
    if ret > intMax then kernelErr 1 else ret

@[export nla_get_range_unsigned]
def publicNlaGetRangeUnsigned (policy range : UInt64) : UInt64 :=
  let info := policyInfo policy 0
  let ty := policyInfoType info
  let validation := policyInfoValidation info
  let minValue := policyNormalMin policy 0 validation
  let maxValue := policyNormalMax policy 0 validation
  if range == 0 || rangeUnsignedSupportedCore ty == 0 then
    0
  else if validation != policyValidateRangePtr &&
      (isNegative64 minValue || isNegative64 maxValue) then
    0
  else
    rangeUnsignedStore range
      (rangeUnsignedMinCore ty validation minValue minValue)
      (rangeUnsignedMaxCore ty validation maxValue maxValue)

@[export nla_get_range_signed]
def publicNlaGetRangeSigned (policy range : UInt64) : UInt64 :=
  let info := policyInfo policy 0
  let ty := policyInfoType info
  let validation := policyInfoValidation info
  let minValue := policyNormalMin policy 0 validation
  let maxValue := policyNormalMax policy 0 validation
  if range == 0 || rangeSignedSupportedCore ty == 0 then
    0
  else
    rangeSignedStore range
      (rangeSignedMinCore ty validation minValue minValue)
      (rangeSignedMaxCore ty validation maxValue maxValue)

@[export nla_strdup]
def publicNlaStrdup (nla flags : UInt64) : UInt64 :=
  let declaredLen := nlattrDeclaredLen nla
  let payloadLen := nlattrPayloadLenFromDeclared declaredLen
  let len :=
    if nla == 0 || payloadLen == cmpUnsupported || payloadLen > intMax then
      cmpUnsupported
    else
      viewTrimOneTrailingZero (nlattrFullView nla declaredLen) payloadLen
  if len == cmpUnsupported || len > intMax then
    0
  else
    let dst := strdupAlloc len flags
    if dst == 0 then
      0
    else
      let ret := viewAttrCopy dst (nlattrFullView nla declaredLen) len
      if ret != 0 then
        0
      else
        let ret := ptrSetByte dst len 0
        if ret != 0 then 0 else dst

@[export lean_public___nla_reserve]
def publicNlaReserveRaw (skb attrtype attrlen : UInt64) : UInt64 :=
  if attrlen > intMax then
    0
  else
    let totalSize := builderRequiredSize attrlen 0
    let attrSize := nlaAttrSize attrlen
    let padLen := nlaPadLen attrlen
    if skbPutAttrArgsValid totalSize attrSize padLen then
      let nla := skbPutRaw skb totalSize
      if nla == 0 then
        0
      else
        let ret := initNlAttr nla attrtype attrSize padLen
        if ret != 0 then 0 else nla
    else
      0

@[export lean_public___nla_reserve_64bit]
def publicNlaReserve64Raw (skb attrtype attrlen padattr : UInt64) : UInt64 :=
  let _ := skbAlign64Bit skb padattr
  publicNlaReserveRaw skb attrtype attrlen

@[export lean_public___nla_reserve_nohdr]
def publicNlaReserveNohdrRaw (skb attrlen : UInt64) : UInt64 :=
  if attrlen > intMax then
    0
  else
    let len := builderRequiredSize attrlen 1
    if skbPutZeroLenValid len then
      let dest := skbPutRaw skb len
      if dest == 0 then
        0
      else
        let ret := zeroBytes dest 0 len
        if ret != 0 then 0 else dest
    else
      0

@[export nla_reserve]
def publicNlaReserve (skb attrtype attrlen : UInt64) : UInt64 :=
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen 0 != ok then
    0
  else
    publicNlaReserveRaw skb attrtype attrlen

@[export nla_reserve_64bit]
def publicNlaReserve64
    (skb attrtype attrlen padattr : UInt64) : UInt64 :=
  let flags := if skbNeeds64BitPadding skb != 0 then 2 else 0
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen flags != ok then
    0
  else
    publicNlaReserve64Raw skb attrtype attrlen padattr

@[export nla_reserve_nohdr]
def publicNlaReserveNohdr (skb attrlen : UInt64) : UInt64 :=
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen 1 != ok then
    0
  else
    publicNlaReserveNohdrRaw skb attrlen

@[export lean_public___nla_put]
def publicNlaPutRaw (skb attrtype attrlen data : UInt64) : UInt64 :=
  let nla := publicNlaReserveRaw skb attrtype attrlen
  let _ := if nla == 0 || data == 0 then 0 else nlaCopyData nla data attrlen
  0

@[export lean_public___nla_put_64bit]
def publicNlaPut64Raw
    (skb attrtype attrlen data padattr : UInt64) : UInt64 :=
  let nla := publicNlaReserve64Raw skb attrtype attrlen padattr
  let _ := if nla == 0 || data == 0 then 0 else nlaCopyData nla data attrlen
  0

@[export lean_public___nla_put_nohdr]
def publicNlaPutNohdrRaw (skb attrlen data : UInt64) : UInt64 :=
  let dest := publicNlaReserveNohdrRaw skb attrlen
  let _ := if dest == 0 || data == 0 then 0 else copyData dest data attrlen
  0

@[export nla_put]
def publicNlaPut (skb attrtype attrlen data : UInt64) : UInt64 :=
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen 0 != ok then
    kernelErr emsgsize
  else
    let _ := publicNlaPutRaw skb attrtype attrlen data
    0

@[export nla_put_64bit]
def publicNlaPut64
    (skb attrtype attrlen data padattr : UInt64) : UInt64 :=
  let flags := if skbNeeds64BitPadding skb != 0 then 2 else 0
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen flags != ok then
    kernelErr emsgsize
  else
    let _ := publicNlaPut64Raw skb attrtype attrlen data padattr
    0

@[export nla_put_nohdr]
def publicNlaPutNohdr (skb attrlen data : UInt64) : UInt64 :=
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen 1 != ok then
    kernelErr emsgsize
  else
    let _ := publicNlaPutNohdrRaw skb attrlen data
    0

@[export nla_append]
def publicNlaAppend (skb attrlen data : UInt64) : UInt64 :=
  if attrlen > intMax || builderStatus (skbTailroom skb) attrlen 1 != ok then
    kernelErr emsgsize
  else if data == 0 then
    kernelErr emsgsize
  else
    let dest := skbPutRaw skb attrlen
    if dest == 0 then
      kernelErr emsgsize
    else
      let ret := copyData dest data attrlen
      if ret != 0 then ret else 0

end LeanNlAttr
