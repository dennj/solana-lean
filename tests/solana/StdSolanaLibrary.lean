import Std.Solana

open Std.Solana

namespace StdSolanaLibraryTest

private def repeated32 (value : UInt8) : ByteArray :=
  ByteArray.mk #[
    value, value, value, value, value, value, value, value,
    value, value, value, value, value, value, value, value,
    value, value, value, value, value, value, value, value,
    value, value, value, value, value, value, value, value]

private def key (value : UInt8) : Pubkey :=
  { bytes := repeated32 value
    size_eq := by rfl }

private def encoded : ByteArray := Id.run do
  let mut out := Borsh.Encoder.withCapacity 48
  out := Borsh.Encoder.putUInt8 out 0xab
  out := Borsh.Encoder.putBool out true
  out := Borsh.Encoder.putUInt16LE out 0x1234
  out := Borsh.Encoder.putUInt32LE out 0x01020304
  out := Borsh.Encoder.putUInt64LE out 0x0102030405060708
  out := Borsh.Encoder.putPubkey out (key 0x55)
  out

private def decoded : Option (UInt8 × Bool × UInt16 × UInt32 × UInt64 × Bool × Bool) := do
  let (tag, d) ← Borsh.Decoder.readUInt8? (Borsh.Decoder.ofBytes encoded)
  let (flag, d) ← Borsh.Decoder.readBool? d
  let (small, d) ← Borsh.Decoder.readUInt16LE? d
  let (medium, d) ← Borsh.Decoder.readUInt32LE? d
  let (large, d) ← Borsh.Decoder.readUInt64LE? d
  let (decodedKey, d) ← Borsh.Decoder.readPubkey? d
  some (tag, flag, small, medium, large, decodedKey == key 0x55, d.done)

private def decodedOk : Bool :=
  match decoded with
  | some (tag, flag, small, medium, large, keyOk, done) =>
      tag == 0xab
        && flag
        && small == 0x1234
        && medium == 0x01020304
        && large == 0x0102030405060708
        && keyOk
        && done
  | none => false

example :
    Bytes.readUInt64LEAt?
      (ByteArray.mk #[0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]) 0
      = some 0x0102030405060708 := by
  native_decide

example : decodedOk = true := by
  native_decide

example : Borsh.Decoder.readBool? (Borsh.Decoder.ofBytes (ByteArray.mk #[2])) = none := by
  native_decide

private def encodedM1? : Option ByteArray := do
  let mut out := Borsh.Encoder.empty
  out := Borsh.Encoder.putUInt128LE out 0x0102030405060708090a0b0c0d0e0f10
  out ← Borsh.Encoder.putInt16LE? out (-2)
  out := Borsh.Encoder.putString out "lean"
  out := Borsh.Encoder.putOption out (some 0x77) Borsh.Encoder.putUInt8
  out ← Borsh.Encoder.putVector? out #[0x1234, 0x5678]
    (fun out value => some (Borsh.Encoder.putUInt16LE out value))
  out := Borsh.Encoder.putEnumTag out 3
  some out

private def decodedM1Ok : Bool :=
  match encodedM1? with
  | none => false
  | some bytes =>
      match Borsh.decodeExact? bytes (fun d => do
          let (wide, d) ← Borsh.Decoder.readUInt128LE? d
          let (signed, d) ← Borsh.Decoder.readInt16LE? d
          let (text, d) ← Borsh.Decoder.readString? d
          let (maybeByte, d) ← Borsh.Decoder.readOption? d Borsh.Decoder.readUInt8?
          let (items, d) ← Borsh.Decoder.readVector? d Borsh.Decoder.readUInt16LE?
          let (tag, d) ← Borsh.Decoder.readEnumTag? d
          some ((wide, signed, text, maybeByte, items, tag), d)) with
      | some (wide, signed, text, maybeByte, items, tag) =>
          wide == 0x0102030405060708090a0b0c0d0e0f10
            && signed == (-2)
            && text == "lean"
            && maybeByte == some 0x77
            && items == #[0x1234, 0x5678]
            && tag == 3
      | none => false

private def exactUInt8? (bytes : ByteArray) : Option UInt8 :=
  Borsh.decodeExact? bytes Borsh.Decoder.readUInt8?

private def overlargeUInt128Rejected : Bool :=
  match Bytes.appendUInt128LE? ByteArray.empty (2 ^ 128) with
  | none => true
  | some _ => false

example : Bytes.readInt16LEAt? (ByteArray.mk #[0xfe, 0xff]) 0 = some (-2) := by
  native_decide

example : decodedM1Ok = true := by
  native_decide

example : exactUInt8? (ByteArray.mk #[7]) = some 7 := by
  native_decide

example : exactUInt8? (ByteArray.mk #[7, 8]) = none := by
  native_decide

example : overlargeUInt128Rejected = true := by
  native_decide

private def counterDisc : Anchor.Discriminator :=
  { bytes := ByteArray.mk #[0xc0, 0x0a, 0xc0, 0x0a, 0xc0, 0x0a, 0xc0, 0x0a]
    size_eq := by rfl }

private def wrongDisc : Anchor.Discriminator :=
  { bytes := ByteArray.mk #[0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef]
    size_eq := by rfl }

private structure CounterState where
  owner   : Pubkey
  count   : UInt64
  enabled : Bool

private def counterPayloadLen : Nat := 32 + 8 + 1 + 3

private def decodeCounterPayload (d : Borsh.Decoder) : Option (CounterState × Borsh.Decoder) := do
  let (owner, d) ← Borsh.Decoder.readPubkey? d
  let (count, d) ← Borsh.Decoder.readUInt64LE? d
  let (enabled, d) ← Borsh.Decoder.readBool? d
  let d ← Borsh.Decoder.readZeroPadding? d 3
  some ({ owner, count, enabled }, d)

private def encodeCounterPayload (state : CounterState) : Option ByteArray :=
  some <| Id.run do
    let mut out := Borsh.Encoder.withCapacity counterPayloadLen
    out := Borsh.Encoder.putPubkey out state.owner
    out := Borsh.Encoder.putUInt64LE out state.count
    out := Borsh.Encoder.putBool out state.enabled
    out := Borsh.Encoder.putZeroPadding out 3
    out

private def counterCodec : AccountCodec CounterState :=
  { discriminator := some counterDisc
    fixedPayloadLen := some counterPayloadLen
    decodePayload := decodeCounterPayload
    encodePayload := encodeCounterPayload }

private def counterState : CounterState :=
  { owner := key 7, count := 42, enabled := true }

private def counterData? : Option ByteArray :=
  counterCodec.encode? counterState

private def counterAccount? : Option AccountInfo := do
  let data ← counterData?
  some {
    key := key 10
    owner := key 20
    lamports := 500
    data
    rentEpoch := 0
    isSigner := false
    isWritable := true
    executable := false
  }

private def counterConstraints : AccountConstraints :=
  { owner := some (key 20)
    writable := true
    dataLenAtLeast := FixedLayout.accountLen counterPayloadLen true }

private def m2LoadOk : Bool :=
  match counterAccount? with
  | none => false
  | some account =>
      let ctx : ProgramContext := { accounts := #[account], data := ByteArray.empty, programId := key 99 }
      match ctx.loadValidatedAccount 0 counterConstraints counterCodec (0xee : UInt64) with
      | .ok loaded =>
          loaded.index == 0
            && loaded.value.count == 42
            && loaded.value.enabled
            && loaded.value.owner == key 7
      | .error _ => false

private def m2DiscriminatorRejects : Bool :=
  match encodeCounterPayload counterState with
  | none => false
  | some payload =>
      match counterCodec.decode? (Anchor.withDiscriminator wrongDisc payload) with
      | none => true
      | some _ => false

private def badPaddingData : ByteArray := Id.run do
  let mut payload := Borsh.Encoder.withCapacity counterPayloadLen
  payload := Borsh.Encoder.putPubkey payload counterState.owner
  payload := Borsh.Encoder.putUInt64LE payload counterState.count
  payload := Borsh.Encoder.putBool payload counterState.enabled
  payload := Borsh.Encoder.putRepeated payload 1 3
  Anchor.withDiscriminator counterDisc payload

private def m2PaddingRejects : Bool :=
  match counterCodec.decode? badPaddingData with
  | none => true
  | some _ => false

private def m2MutateEncodeOk : Bool :=
  match counterAccount? with
  | none => false
  | some account =>
      match account.decodeWith counterCodec (0xee : UInt64) with
      | .error _ => false
      | .ok state =>
          let updated := { state with count := state.count + 1 }
          match counterCodec.encodeOr updated (0xef : UInt64) with
          | .error _ => false
          | .ok bytes =>
              match counterCodec.decode? bytes with
              | some reread => reread.count == 43 && reread.owner == key 7 && reread.enabled
              | none => false

example : FixedLayout.accountLen counterPayloadLen true = counterPayloadLen + 8 := by
  native_decide

example : m2LoadOk = true := by
  native_decide

example : m2DiscriminatorRejects = true := by
  native_decide

example : m2PaddingRejects = true := by
  native_decide

example : m2MutateEncodeOk = true := by
  native_decide

private def account : AccountInfo :=
  { key := key 1
    owner := key 2
    lamports := 10
    data := encoded
    rentEpoch := 0
    isSigner := true
    isWritable := false
    executable := false }

private def ctx : ProgramContext :=
  { accounts := #[account]
    data := encoded
    programId := key 9 }

private def signerOk : Bool :=
  match account.requireSigner (0xe1 : UInt64) with
  | .ok () => true
  | .error _ => false

private def writableRejected : Bool :=
  match account.requireWritable (0xe2 : UInt64) with
  | .error 0xe2 => true
  | _ => false

private def accountLookupOk : Bool :=
  match ctx.accountOr 0 (0xe3 : UInt64) with
  | .ok acct => acct.key == key 1
  | .error _ => false

private def accountLookupRejected : Bool :=
  match ctx.accountOr 1 (0xe4 : UInt64) with
  | .error 0xe4 => true
  | _ => false

example : signerOk = true := by
  native_decide

example : writableRejected = true := by
  native_decide

example : accountLookupOk = true := by
  native_decide

example : accountLookupRejected = true := by
  native_decide

example :
    let acctMeta := AccountMeta.writableSigner (key 3)
    (acctMeta.pubkey == key 3, acctMeta.isWritable, acctMeta.isSigner) = (true, true, true) := by
  native_decide

example : Pda.bumpSeed 7 = ByteArray.mk #[7] := by
  native_decide

private def tagPayloadData : ByteArray :=
  Borsh.Encoder.putUInt64LE (Borsh.Encoder.putUInt8 Borsh.Encoder.empty 2) 41

private def tagCases : Array (Dispatch.TagCase UInt64) := #[
  { tag := 1
    run := Dispatch.exact Borsh.Decoder.readUInt64LE? },
  { tag := 2
    run := fun d => do
      let value ← ProgramResult.decodeExact d Borsh.Decoder.readUInt64LE?
        ProgramError.invalidInstructionData
      .ok (value + 1) }
]

private def m3TagDispatchOk : Bool :=
  match Dispatch.byTag tagPayloadData tagCases with
  | .ok 42 => true
  | _ => false

private def m3TagDispatchRejectsUnknown : Bool :=
  match Dispatch.byTag (ByteArray.mk #[9]) tagCases with
  | .error err => err == ProgramError.unsupportedInstruction
  | .ok _ => false

private def anchorInstructionData : ByteArray :=
  Anchor.withDiscriminator counterDisc
    (Borsh.Encoder.putUInt16LE Borsh.Encoder.empty 0x1234)

private def anchorCases : Array (Dispatch.AnchorCase UInt64) := #[
  { discriminator := wrongDisc
    run := fun _ => .ok 0 },
  { discriminator := counterDisc
    run := fun d => do
      let value ← ProgramResult.decodeExact d Borsh.Decoder.readUInt16LE?
        ProgramError.invalidInstructionData
      .ok value.toUInt64 }
]

private def m3AnchorDispatchOk : Bool :=
  match Dispatch.byAnchor anchorInstructionData anchorCases with
  | .ok 0x1234 => true
  | _ => false

private def m3AnchorDispatchRejectsTrailing : Bool :=
  let data := (Anchor.withDiscriminator counterDisc
    (Borsh.Encoder.putUInt16LE Borsh.Encoder.empty 0x1234)).push 0
  match Dispatch.byAnchor data anchorCases with
  | .error err => err == ProgramError.invalidInstructionData
  | .ok _ => false

private def m3RequireOk : Bool :=
  match (do
      ProgramResult.require true 0xaa
      ProgramResult.requireSome (some 5) 0xab) with
  | .ok 5 => true
  | _ => false

private def m3RequireRejects : Bool :=
  match ProgramResult.require false 0xac with
  | .error 0xac => true
  | _ => false

example : ProgramResult.toReturnCode (.ok ()) = ProgramError.success := by
  native_decide

example : ProgramResult.toReturnCode (.error 0xbeef) = 0xbeef := by
  native_decide

example : ProgramResult.entrypoint (fun _ => .ok ()) ctx = ProgramError.success := by
  native_decide

example : m3RequireOk = true := by
  native_decide

example : m3RequireRejects = true := by
  native_decide

example : m3TagDispatchOk = true := by
  native_decide

example : m3TagDispatchRejectsUnknown = true := by
  native_decide

example : m3AnchorDispatchOk = true := by
  native_decide

example : m3AnchorDispatchRejectsTrailing = true := by
  native_decide

example :
    SystemProgram.transferData 0x0102030405060708 =
      ByteArray.mk #[2, 0, 0, 0, 8, 7, 6, 5, 4, 3, 2, 1] := by
  native_decide

private def m4TransferInstructionOk : Bool :=
  let inst := SystemProgram.transferInstruction (key 1) (key 2) 55
  inst.programId == SystemProgram.id
    && inst.data == SystemProgram.transferData 55
    && match (inst.accounts[0]?, inst.accounts[1]?) with
      | (some source, some destination) =>
          source.pubkey == key 1
            && source.isWritable
            && source.isSigner
            && destination.pubkey == key 2
            && destination.isWritable
            && !destination.isSigner
      | _ => false

private def m4CreateAccountDataOk : Bool :=
  let data := SystemProgram.createAccountData 9 128 (key 3)
  data.size == 52
    && Bytes.readUInt32LEAt? data 0 == some 0
    && Bytes.readUInt64LEAt? data 4 == some 9
    && Bytes.readUInt64LEAt? data 12 == some 128
    && Bytes.readPubkeyAt? data 20 == some (key 3)

example : Bytes.readUInt32LEAt? (SystemProgram.assignData (key 4)) 0 = some 1 := by
  native_decide

example : Bytes.readUInt32LEAt? (SystemProgram.allocateData 512) 0 = some 8 := by
  native_decide

private def clockData? : Option ByteArray := do
  let mut out := Borsh.Encoder.withCapacity Sysvar.Clock.dataLen
  out := Borsh.Encoder.putUInt64LE out 1
  out ← Borsh.Encoder.putInt64LE? out (-2)
  out := Borsh.Encoder.putUInt64LE out 3
  out := Borsh.Encoder.putUInt64LE out 4
  out ← Borsh.Encoder.putInt64LE? out (-5)
  some out

private def m4ClockDecodeOk : Bool :=
  match clockData? with
  | none => false
  | some data =>
      let account : AccountInfo :=
        { key := Sysvar.Clock.id
          owner := key 20
          lamports := 0
          data
          rentEpoch := 0
          isSigner := false
          isWritable := false
          executable := false }
      let ctx : ProgramContext :=
        { accounts := #[account], data := ByteArray.empty, programId := key 9 }
      match ctx.sysvarClock? with
      | some clock =>
          clock.slot == 1
            && clock.epochStartTimestamp == (-2)
            && clock.epoch == 3
            && clock.leaderScheduleEpoch == 4
            && clock.unixTimestamp == (-5)
      | none => false

private def m4ClockRejectsWrongKey : Bool :=
  match clockData? with
  | none => false
  | some data =>
      let account : AccountInfo :=
        { key := key 1
          owner := key 20
          lamports := 0
          data
          rentEpoch := 0
          isSigner := false
          isWritable := false
          executable := false }
      match Sysvar.Clock.fromAccount? account with
      | none => true
      | some _ => false

private def rentData : ByteArray := Id.run do
  let mut out := Borsh.Encoder.withCapacity Sysvar.Rent.dataLen
  out := Borsh.Encoder.putUInt64LE out 100
  out := Borsh.Encoder.putUInt64LE out 0x4000000000000000
  out := Borsh.Encoder.putUInt8 out 50
  out

private def m4RentDecodeOk : Bool :=
  let account : AccountInfo :=
    { key := Sysvar.Rent.id
      owner := key 20
      lamports := 0
      data := rentData
      rentEpoch := 0
      isSigner := false
      isWritable := false
      executable := false }
  let ctx : ProgramContext :=
    { accounts := #[account], data := ByteArray.empty, programId := key 9 }
  match ctx.sysvarRent? with
  | some rent =>
      rent.lamportsPerByteYear == 100
        && rent.exemptionThresholdBits == 0x4000000000000000
        && rent.burnPercent == 50
        && Sysvar.Rent.minimumBalanceDefault? rent 10 == some 2000
  | none => false

example : m4TransferInstructionOk = true := by
  native_decide

example : m4CreateAccountDataOk = true := by
  native_decide

example : m4ClockDecodeOk = true := by
  native_decide

example : m4ClockRejectsWrongKey = true := by
  native_decide

example : m4RentDecodeOk = true := by
  native_decide

example : Sysvar.Rent.minimumBalanceForExemption? 100 10 1 0 = none := by
  native_decide

private def m4RequireRentOk : Bool :=
  match Sysvar.Rent.requireExemptWithMinimum 2000 2000 (0xe5 : UInt64) with
  | .ok () => true
  | .error _ => false

example : m4RequireRentOk = true := by
  native_decide

private def tokenAmount : UInt64 := 0x0102030405060708

private def amountPayload (tag : UInt8) : ByteArray :=
  ByteArray.mk #[tag, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]

example : TokenProgram.transferData tokenAmount = amountPayload TokenProgram.transferTag := by
  native_decide

example :
    TokenProgram.transferCheckedData tokenAmount 6 =
      ByteArray.mk #[TokenProgram.transferCheckedTag, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 6] := by
  native_decide

private def m5TransferInstructionOk : Bool :=
  let inst := TokenProgram.transferInstruction (key 1) (key 2) (key 3) tokenAmount
  inst.programId == TokenProgram.id
    && inst.data == amountPayload TokenProgram.transferTag
    && match (inst.accounts[0]?, inst.accounts[1]?, inst.accounts[2]?) with
      | (some source, some destination, some authority) =>
          source.pubkey == key 1
            && source.isWritable
            && !source.isSigner
            && destination.pubkey == key 2
            && destination.isWritable
            && !destination.isSigner
            && authority.pubkey == key 3
            && !authority.isWritable
            && authority.isSigner
      | _ => false

private def m5MultisigInstructionOk : Bool :=
  let inst := TokenProgram.transferInstruction (key 1) (key 2) (key 3) tokenAmount #[key 4, key 5]
  inst.accounts.size == 5
    && match (inst.accounts[2]?, inst.accounts[3]?, inst.accounts[4]?) with
      | (some owner, some signer0, some signer1) =>
          owner.pubkey == key 3
            && !owner.isWritable
            && !owner.isSigner
            && signer0.pubkey == key 4
            && !signer0.isWritable
            && signer0.isSigner
            && signer1.pubkey == key 5
            && !signer1.isWritable
            && signer1.isSigner
      | _ => false

private def m5CheckedToken2022Ok : Bool :=
  let inst :=
    TokenProgram.transferCheckedInstructionWithProgram TokenProgram.token2022Id
      (key 1) (key 2) (key 3) (key 4) tokenAmount 9
  inst.programId == TokenProgram.token2022Id
    && inst.data == TokenProgram.transferCheckedData tokenAmount 9
    && match (inst.accounts[0]?, inst.accounts[1]?, inst.accounts[2]?, inst.accounts[3]?) with
      | (some source, some mint, some destination, some authority) =>
          source.pubkey == key 1
            && source.isWritable
            && !source.isSigner
            && mint.pubkey == key 2
            && !mint.isWritable
            && !mint.isSigner
            && destination.pubkey == key 3
            && destination.isWritable
            && !destination.isSigner
            && authority.pubkey == key 4
            && !authority.isWritable
            && authority.isSigner
      | _ => false

example : TokenProgram.mintToData tokenAmount = amountPayload TokenProgram.mintToTag := by
  native_decide

example : TokenProgram.burnData tokenAmount = amountPayload TokenProgram.burnTag := by
  native_decide

example : (TokenProgram.syncNativeInstruction (key 1)).data = ByteArray.mk #[TokenProgram.syncNativeTag] := by
  native_decide

example :
    (TokenProgram.initializeAccount3Instruction (key 1) (key 2) (key 3)).data =
      (ByteArray.mk #[TokenProgram.initializeAccount3Tag]).append (key 3).toBytes := by
  native_decide

private def mintData : ByteArray := Id.run do
  let mut out := Borsh.Encoder.withCapacity Token.Mint.dataLen
  out := Token.COption.putPubkey out (some (key 1))
  out := Borsh.Encoder.putUInt64LE out 500
  out := Borsh.Encoder.putUInt8 out 6
  out := Borsh.Encoder.putBool out true
  out := Token.COption.putPubkey out none
  out

private def m5MintDecodeOk : Bool :=
  let account : AccountInfo :=
    { key := key 10
      owner := TokenProgram.id
      lamports := 0
      data := mintData
      rentEpoch := 0
      isSigner := false
      isWritable := false
      executable := false }
  match Token.Mint.fromAccount? account with
  | some mint =>
      mint.mintAuthority == some (key 1)
        && mint.supply == 500
        && mint.decimals == 6
        && mint.isInitialized
        && mint.freezeAuthority == none
  | none => false

private def tokenAccountData : ByteArray := Id.run do
  let mut out := Borsh.Encoder.withCapacity Token.Account.dataLen
  out := Borsh.Encoder.putPubkey out (key 1)
  out := Borsh.Encoder.putPubkey out (key 2)
  out := Borsh.Encoder.putUInt64LE out 99
  out := Token.COption.putPubkey out (some (key 3))
  out := Borsh.Encoder.putUInt8 out Token.AccountState.initialized.toUInt8
  out := Token.COption.putUInt64 out none
  out := Borsh.Encoder.putUInt64LE out 7
  out := Token.COption.putPubkey out none
  out

private def m5TokenAccountDecodeOk : Bool :=
  let account : AccountInfo :=
    { key := key 11
      owner := TokenProgram.token2022Id
      lamports := 0
      data := tokenAccountData
      rentEpoch := 0
      isSigner := false
      isWritable := false
      executable := false }
  match Token.Account.fromAccount? account with
  | some tokenAccount =>
      tokenAccount.mint == key 1
        && tokenAccount.owner == key 2
        && tokenAccount.amount == 99
        && tokenAccount.delegate == some (key 3)
        && tokenAccount.state == Token.AccountState.initialized
        && tokenAccount.isNative == none
        && tokenAccount.delegatedAmount == 7
        && tokenAccount.closeAuthority == none
  | none => false

private def m5AssociatedTokenCreateOk : Bool :=
  let inst := AssociatedTokenProgram.createInstruction (key 1) (key 2) (key 3) (key 4)
  inst.programId == AssociatedTokenProgram.id
    && inst.data == AssociatedTokenProgram.createData
    && match (inst.accounts[0]?, inst.accounts[1]?, inst.accounts[2]?,
        inst.accounts[3]?, inst.accounts[4]?, inst.accounts[5]?) with
      | (some payer, some ata, some wallet, some mint, some system, some tokenProgram) =>
          payer.pubkey == key 1
            && payer.isWritable
            && payer.isSigner
            && ata.pubkey == key 2
            && ata.isWritable
            && !ata.isSigner
            && wallet.pubkey == key 3
            && !wallet.isWritable
            && !wallet.isSigner
            && mint.pubkey == key 4
            && !mint.isWritable
            && !mint.isSigner
            && system.pubkey == SystemProgram.id
            && tokenProgram.pubkey == TokenProgram.id
      | _ => false

example :
    AssociatedTokenProgram.addressSeeds (key 1) (key 2) TokenProgram.token2022Id =
      #[(key 1).toBytes, TokenProgram.token2022Id.toBytes, (key 2).toBytes] := by
  native_decide

example :
    (AssociatedTokenProgram.createIdempotentInstruction (key 1) (key 2) (key 3) (key 4)).data =
      ByteArray.mk #[1] := by
  native_decide

example : m5TransferInstructionOk = true := by
  native_decide

example : m5MultisigInstructionOk = true := by
  native_decide

example : m5CheckedToken2022Ok = true := by
  native_decide

example : m5MintDecodeOk = true := by
  native_decide

example : m5TokenAccountDecodeOk = true := by
  native_decide

example : m5AssociatedTokenCreateOk = true := by
  native_decide

private def helloWorldBytes : ByteArray :=
  "hello world".toUTF8

example : Base58.encodeBytes ByteArray.empty = ByteArray.empty := by
  native_decide

example : Base58.decodeBytes? ByteArray.empty = some ByteArray.empty := by
  native_decide

example : Base58.encodeBytes (ByteArray.mk #[0, 0, 1]) = "112".toUTF8 := by
  native_decide

example : Base58.decodeBytes? "112".toUTF8 = some (ByteArray.mk #[0, 0, 1]) := by
  native_decide

example : Base58.encodeBytes helloWorldBytes = "StV1DL6CwTryKyV".toUTF8 := by
  native_decide

example : Base58.decode? "StV1DL6CwTryKyV" = some helloWorldBytes := by
  native_decide

example : SystemProgram.id.toBase58 = "11111111111111111111111111111111" := by
  native_decide

example :
    TokenProgram.id.toBase58 = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" := by
  native_decide

private def m6InvalidDecodeOk : Bool :=
  match Base58.decodeBytes? "0OIl".toUTF8 with
  | none => true
  | some _ => false

private def m6PubkeyRoundTripOk : Bool :=
  let encoded := TokenProgram.token2022Id.toBase58Bytes
  match Pubkey.ofBase58Bytes? encoded with
  | some key => key == TokenProgram.token2022Id
  | none => false

private def m6PubkeyRejectsWrongLen : Bool :=
  match Pubkey.ofBase58? "112" with
  | none => true
  | some _ => false

example : m6InvalidDecodeOk = true := by
  native_decide

example : m6PubkeyRoundTripOk = true := by
  native_decide

example : m6PubkeyRejectsWrongLen = true := by
  native_decide

end StdSolanaLibraryTest
