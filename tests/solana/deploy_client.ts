// On-chain test client for the live-deploy gate.
//
// Talks to a local solana-test-validator (default http://localhost:8899)
// using @solana/web3.js. Each subcommand exercises one Lean-compiled
// program's runtime semantics:
//
//   hello      — deploy Hello.so, send a no-op tx, assert "hello from
//                lean" appears in the validator's program log.
//   counter    — deploy Counter.so, create a data account owned by the
//                program, send increment tx with 8-byte instruction
//                data, read account back and assert byte 0 incremented.
//   increment  — deploy Increment42.so, send tx, assert success.
//   nat        — deploy NatOverflow.so, assert success (exercises
//                bounded Nat arithmetic on chain).
//
// Exit code 0 = pass, non-zero = fail.

import {
  Connection,
  ComputeBudgetProgram,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  SystemProgram,
  sendAndConfirmTransaction,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import { readFileSync } from "node:fs";

const RPC = process.env.SOLANA_RPC ?? "http://localhost:8899";
const conn = new Connection(RPC, "confirmed");

function loadKeypair(path: string): Keypair {
  const secret = JSON.parse(readFileSync(path, "utf8")) as number[];
  return Keypair.fromSecretKey(Uint8Array.from(secret));
}

async function ensureFunded(payer: Keypair) {
  const bal = await conn.getBalance(payer.publicKey);
  if (bal < LAMPORTS_PER_SOL) {
    const sig = await conn.requestAirdrop(payer.publicKey, 5 * LAMPORTS_PER_SOL);
    await conn.confirmTransaction(sig, "confirmed");
  }
}

// Wait for the program account to be visible AND executable. After
// `solana program deploy` returns, there is a brief window where the
// program account is committed but not yet propagated to the leader's
// program cache; transactions sent during this window fail with
// "Program is not deployed".
async function waitForExecutable(programId: PublicKey, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const info = await conn.getAccountInfo(programId, "confirmed");
    if (info?.executable) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  fail(`program ${programId.toBase58()} did not become executable within ${timeoutMs}ms`);
}

async function getTxLogs(signature: string): Promise<string[]> {
  // Test-validator's transaction logs settle a beat after confirmation; poll briefly.
  for (let i = 0; i < 15; i++) {
    const tx = await conn.getTransaction(signature, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    if (tx?.meta?.logMessages) return tx.meta.logMessages;
    await new Promise((r) => setTimeout(r, 200));
  }
  return [];
}

function fail(msg: string): never {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
}

async function cmdCounter(programId: PublicKey, payerPath: string) {
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);

  // 1. Create an 8-byte data account owned by the program.
  const counterAccount = Keypair.generate();
  const space = 8;
  const rent = await conn.getMinimumBalanceForRentExemption(space);
  const createIx = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: counterAccount.publicKey,
    lamports: rent,
    space,
    programId,
  });
  await sendAndConfirmTransaction(conn, new Transaction().add(createIx), [payer, counterAccount]);

  const before = await conn.getAccountInfo(counterAccount.publicKey);
  if (!before) fail("Counter: account not created");
  if (before.data.length !== 8) fail(`Counter: expected 8 bytes, got ${before.data.length}`);
  // Account starts zeroed; counter = 0.
  const beforeVal = before.data.readBigUInt64LE(0);
  if (beforeVal !== 0n) fail(`Counter: pre-state expected 0, got ${beforeVal}`);

  // 2. Send increment-by-7 instruction. Instruction data layout (per
  //    Counter.lean): 8-byte little-endian uint64 = increment amount.
  const incData = Buffer.alloc(8);
  incData.writeBigUInt64LE(7n, 0);
  const ix = new TransactionInstruction({
    keys: [{ pubkey: counterAccount.publicKey, isSigner: false, isWritable: true }],
    programId,
    data: incData,
  });
  const sig = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  const logs = await getTxLogs(sig);

  // 3. Read account back, assert byte 0..8 == 7.
  const after = await conn.getAccountInfo(counterAccount.publicKey);
  if (!after) fail("Counter: account vanished after tx");
  const afterVal = after.data.readBigUInt64LE(0);
  if (afterVal !== 7n) {
    fail(`Counter: expected 7 after increment, got ${afterVal}\nlogs:\n${logs.join("\n")}`);
  }

  // 4. Increment by 35 → 42.
  const incData2 = Buffer.alloc(8);
  incData2.writeBigUInt64LE(35n, 0);
  const ix2 = new TransactionInstruction({
    keys: [{ pubkey: counterAccount.publicKey, isSigner: false, isWritable: true }],
    programId,
    data: incData2,
  });
  await sendAndConfirmTransaction(conn, new Transaction().add(ix2), [payer]);
  const finalState = await conn.getAccountInfo(counterAccount.publicKey);
  const finalVal = finalState!.data.readBigUInt64LE(0);
  if (finalVal !== 42n) fail(`Counter: expected 42 after second increment, got ${finalVal}`);

  console.log(`PASS counter: state mutation observable on-chain (0 → 7 → 42)`);
}

async function cmdStatusAbort(programId: PublicKey, payerPath: string) {
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);

  const state = Keypair.generate();
  const space = 8;
  const rent = await conn.getMinimumBalanceForRentExemption(space);
  const createIx = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: state.publicKey,
    lamports: rent,
    space,
    programId,
  });
  await sendAndConfirmTransaction(conn, new Transaction().add(createIx), [payer, state]);

  const okIx = new TransactionInstruction({
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    programId,
    data: Buffer.from([0]),
  });
  await sendAndConfirmTransaction(conn, new Transaction().add(okIx), [payer]);

  const committed = await conn.getAccountInfo(state.publicKey);
  if (!committed) fail("StatusAbort: state account missing after success tx");
  if (committed.data.readUInt8(0) !== 0x11) {
    fail(`StatusAbort: expected committed byte 0x11, got 0x${committed.data.readUInt8(0).toString(16)}`);
  }

  const abortIx = new TransactionInstruction({
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    programId,
    data: Buffer.from([1]),
  });
  const sig = await conn.sendTransaction(
    new Transaction().add(abortIx),
    [payer],
    { skipPreflight: true },
  );
  const confirmed = await conn.confirmTransaction(sig, "confirmed");
  const logs = await getTxLogs(sig);
  if (!confirmed.value.err) {
    fail(`StatusAbort: expected non-zero entry return to fail transaction\nlogs:\n${logs.join("\n")}`);
  }
  const marker = logs.find((l) =>
    l.match(/Program log: 0x1eaa, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x1, 0xe4/i)
  );
  if (!marker) {
    fail(`StatusAbort: missing 0xe4 return marker:\n${logs.join("\n")}`);
  }

  const afterAbort = await conn.getAccountInfo(state.publicKey);
  if (!afterAbort) fail("StatusAbort: state account missing after abort tx");
  const got = afterAbort.data.readUInt8(0);
  if (got !== 0x11) {
    fail(`StatusAbort: rollback failed, expected byte 0x11 after abort, got 0x${got.toString(16)}\nlogs:\n${logs.join("\n")}`);
  }

  console.log("PASS StatusAbort: non-zero status aborts transaction and rolls back account write");
}

// Diagnostic: send `dataByte` as the first byte of an 8-byte instruction
// data buffer, then assert that the validator log line
// `Program log: 0x1eaa, 0x0, 0x0, 0x8, 0x<RESULT>` shows `expectedResult`.
async function cmdDiag(
  programId: PublicKey,
  payerPath: string,
  name: string,
  dataByte: number,
  expectedResult: bigint,
) {
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);
  const data = Buffer.alloc(8);
  data.writeUInt8(dataByte & 0xff, 0);
  const ix = new TransactionInstruction({
    keys: [{ pubkey: payer.publicKey, isSigner: true, isWritable: true }],
    programId,
    data,
  });
  const sig = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  const logs = await getTxLogs(sig);
  const m = logs
    .map((l) => l.match(/Program log: 0x1eaa, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x([0-9a-f]+)/i))
    .find((x) => x !== null);
  if (!m) {
    fail(`${name}: no 0x1eaa marker line in logs:\n${logs.join("\n")}`);
  }
  const got = BigInt("0x" + m[1]);
  if (got !== expectedResult) {
    fail(`${name}: expected result 0x${expectedResult.toString(16)}, got 0x${got.toString(16)}\nlogs:\n${logs.join("\n")}`);
  }
  console.log(`PASS ${name}: result 0x${got.toString(16)} matches expected`);
}

async function cmdDiagKey(programId: PublicKey, payerPath: string) {
  // Regression check for the unboxed-`Pubkey` bug: DiagKey projects the first
  // two bytes of accounts[0].key and .owner, then compares both Pubkeys against
  // expected values passed in instruction data. The account at index 0 is the
  // payer, so those projections and equality checks must match the real account.
  const name = "DiagKey";
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);
  const payerInfo = await conn.getAccountInfo(payer.publicKey);
  if (!payerInfo) {
    fail(`${name}: payer account ${payer.publicKey.toBase58()} not found`);
  }
  const expectedKey = payer.publicKey.toBytes();
  const expectedOwner = payerInfo!.owner.toBytes();
  const data = Buffer.concat([Buffer.from(expectedKey), Buffer.from(expectedOwner)]);
  const ix = new TransactionInstruction({
    keys: [{ pubkey: payer.publicKey, isSigner: true, isWritable: true }],
    programId,
    data,
  });
  const sig = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  const logs = await getTxLogs(sig);
  const m = logs
    .map((l) => l.match(/Program log: 0x1eaa, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x([0-9a-f]+)/i))
    .find((x) => x !== null);
  if (!m) {
    fail(`${name}: no 0x1eaa marker line in logs:\n${logs.join("\n")}`);
  }
  const got = BigInt("0x" + m![1]);
  // Layout: ((((key[0], key[1], owner[0], owner[1]) as u32) << 2 | flags) << 24)
  //         | firstKeyMismatchIndex << 16 | actualByte << 8 | expectedByte.
  const mismatchExpected = Number(got & 0xffn);
  const mismatchActual = Number((got >> 8n) & 0xffn);
  const mismatchIdx = Number((got >> 16n) & 0xffn);
  const prefix = got >> 24n;
  const keyEq = (prefix & 0x2n) !== 0n;
  const ownerEq = (prefix & 0x1n) !== 0n;
  const projected = prefix >> 2n;
  const projectedKey0 = Number((projected >> 24n) & 0xffn);
  const projectedKey1 = Number((projected >> 16n) & 0xffn);
  const projectedOwner0 = Number((projected >> 8n) & 0xffn);
  const projectedOwner1 = Number(projected & 0xffn);
  const expectedProjected =
    (BigInt(expectedKey[0]) << 24n) |
    (BigInt(expectedKey[1]) << 16n) |
    (BigInt(expectedOwner[0]) << 8n) |
    BigInt(expectedOwner[1]);
  const expected = (((expectedProjected << 2n) | 0x3n) << 24n) | 0xff0000n;
  if (got !== expected) {
    const mismatch =
      mismatchIdx === 0xff
        ? "none"
        : `${mismatchIdx}: actual=0x${mismatchActual.toString(16)} expected=0x${mismatchExpected.toString(16)}`;
    fail(`${name}: expected 0x${expected.toString(16)} (key[0..1]=0x${expectedKey[0].toString(16)},0x${expectedKey[1].toString(16)} owner[0..1]=0x${expectedOwner[0].toString(16)},0x${expectedOwner[1].toString(16)} keyEq=true ownerEq=true keyMismatch=none), got 0x${got.toString(16)} (key[0..1]=0x${projectedKey0.toString(16)},0x${projectedKey1.toString(16)} owner[0..1]=0x${projectedOwner0.toString(16)},0x${projectedOwner1.toString(16)} keyEq=${keyEq} ownerEq=${ownerEq} keyMismatch=${mismatch})\nlogs:\n${logs.join("\n")}`);
  }
  console.log(`PASS ${name}: key/owner byte projections and Pubkey equality match on-chain account`);
}

async function cmdSimple(programId: PublicKey, payerPath: string, name: string) {
  // Generic "deploys + executes without erroring" check.
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);
  // Most lean_sol_entry / lean_sol_entry_typed programs accept any
  // transaction shape; we send 8 bytes of input (the scalar entry's arg)
  // plus the program's own ID as the only account.
  const data = Buffer.alloc(8);
  data.writeBigUInt64LE(0n, 0);
  const ix = new TransactionInstruction({
    keys: [{ pubkey: payer.publicKey, isSigner: true, isWritable: true }],
    programId,
    data,
  });
  try {
    const tx = new Transaction();
    const computeUnits = Number(process.env.COMPUTE_UNITS ?? "0");
    if (computeUnits > 0) {
      tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: computeUnits }));
    }
    tx.add(ix);
    const sig = await sendAndConfirmTransaction(conn, tx, [payer]);
    const logs = await getTxLogs(sig);
    if (process.env.PRINT_LOGS === "1") {
      console.log(logs.join("\n"));
    }
    const programLine = logs.find((l) => l.includes(`Program ${programId.toBase58()} success`));
    if (!programLine) {
      fail(`${name}: expected 'Program <id> success' in logs, got:\n${logs.join("\n")}`);
    }
    console.log(`PASS ${name}: program executed successfully on-chain`);
  } catch (e: any) {
    fail(`${name}: tx failed: ${e?.message ?? e}`);
  }
}

async function sendWithOptionalCompute(payer: Keypair, ix: TransactionInstruction): Promise<string> {
  const tx = new Transaction();
  const computeUnits = Number(process.env.COMPUTE_UNITS ?? "0");
  if (computeUnits > 0) {
    tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: computeUnits }));
  }
  tx.add(ix);
  return await sendAndConfirmTransaction(conn, tx, [payer]);
}

async function cmdTypecheckerStages(programId: PublicKey, payerPath: string) {
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);

  const state = Keypair.generate();
  const space = 8;
  const rent = await conn.getMinimumBalanceForRentExemption(space);
  const createIx = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: state.publicKey,
    lamports: rent,
    space,
    programId,
  });
  await sendAndConfirmTransaction(conn, new Transaction().add(createIx), [payer, state]);

  for (let stage = 0; stage < 3; stage++) {
    const data = Buffer.from([stage]);
    const ix = new TransactionInstruction({
      keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
      programId,
      data,
    });
    const sig = await sendWithOptionalCompute(payer, ix);
    const logs = await getTxLogs(sig);
    if (process.env.PRINT_LOGS === "1") {
      console.log(logs.join("\n"));
    }
    const marker = logs.find((l) =>
      l.match(/Program log: 0x1eaa, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x[0-9a-f]+, 0x0/i)
    );
    if (!marker) {
      fail(`typechecker-stage ${stage}: missing success marker:\n${logs.join("\n")}`);
    }
    const account = await conn.getAccountInfo(state.publicKey);
    if (!account) fail(`typechecker-stage ${stage}: state account missing`);
    const progress = account.data.readUInt8(0);
    if (progress !== stage + 1) {
      fail(`typechecker-stage ${stage}: expected progress ${stage + 1}, got ${progress}`);
    }
  }

  console.log("PASS typechecker-stages: staged checker advanced 0 → 1 → 2 → 3 on-chain");
}

async function cmdTypecheckerPolicy(programId: PublicKey, payerPath: string) {
  const payer = loadKeypair(payerPath);
  await ensureFunded(payer);
  await waitForExecutable(programId);

  for (const [token, name] of [[50, "reject-submitted-axiom"], [51, "reject-sorryAx"]] as const) {
    const ix = new TransactionInstruction({
      keys: [{ pubkey: payer.publicKey, isSigner: true, isWritable: true }],
      programId,
      data: Buffer.from([token]),
    });
    const sig = await sendWithOptionalCompute(payer, ix);
    const logs = await getTxLogs(sig);
    if (process.env.PRINT_LOGS === "1") {
      console.log(logs.join("\n"));
    }
    const marker = logs.find((l) =>
      l.match(new RegExp(`Program log: 0x1eac, 0x${token.toString(16)}, 0x[0-9a-f]+, 0x0, 0x0`, "i"))
    );
    if (!marker) {
      fail(`typechecker-policy ${name}: missing success marker:\n${logs.join("\n")}`);
    }
  }

  console.log("PASS typechecker-policy: submitted axioms and sorryAx proofs rejected on-chain");
}

const cmd = process.argv[2];
const programIdStr = process.argv[3];
const payerPath = process.argv[4];

if (!cmd || !programIdStr || !payerPath) {
  console.error("usage: bun deploy_client.ts <cmd> <programId> <payerKeypair.json>");
  console.error("  cmd: counter | statusabort | logmany | typed | pda | diag1 | diag2 | diag3 | diagkey | typechecker-stages | typechecker-policy");
  process.exit(2);
}

const programId = new PublicKey(programIdStr);

switch (cmd) {
  case "counter":    await cmdCounter(programId, payerPath); break;
  case "statusabort": await cmdStatusAbort(programId, payerPath); break;
  case "logmany":    await cmdSimple(programId, payerPath, "LogMany"); break;
  case "typed":      await cmdSimple(programId, payerPath, "Typed"); break;
  case "pda":        await cmdSimple(programId, payerPath, "Pda"); break;
  case "diag1":      await cmdDiag(programId, payerPath, "Diag1Const",  0,   0x2An); break;
  case "diag2":      await cmdDiag(programId, payerPath, "Diag2Byte0", 42,   0x2An); break;
  case "diag3":      await cmdDiag(programId, payerPath, "Diag3Decode", 7,   0x07n); break;
  case "diagkey":    await cmdDiagKey(programId, payerPath); break;
  case "typechecker-stages": await cmdTypecheckerStages(programId, payerPath); break;
  case "typechecker-policy": await cmdTypecheckerPolicy(programId, payerPath); break;
  default:
    fail(`unknown cmd: ${cmd}`);
}
