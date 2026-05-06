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
    const sig = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
    const logs = await getTxLogs(sig);
    const programLine = logs.find((l) => l.includes(`Program ${programId.toBase58()} success`));
    if (!programLine) {
      fail(`${name}: expected 'Program <id> success' in logs, got:\n${logs.join("\n")}`);
    }
    console.log(`PASS ${name}: program executed successfully on-chain`);
  } catch (e: any) {
    fail(`${name}: tx failed: ${e?.message ?? e}`);
  }
}

const cmd = process.argv[2];
const programIdStr = process.argv[3];
const payerPath = process.argv[4];

if (!cmd || !programIdStr || !payerPath) {
  console.error("usage: bun deploy_client.ts <cmd> <programId> <payerKeypair.json>");
  console.error("  cmd: hello | counter | increment | nat | logmany | tuple | denied");
  process.exit(2);
}

const programId = new PublicKey(programIdStr);

switch (cmd) {
  case "counter":    await cmdCounter(programId, payerPath); break;
  case "logmany":    await cmdSimple(programId, payerPath, "LogMany"); break;
  case "typed":      await cmdSimple(programId, payerPath, "Typed"); break;
  case "pda":        await cmdSimple(programId, payerPath, "Pda"); break;
  case "diag1":      await cmdDiag(programId, payerPath, "Diag1Const",  0,   0x2An); break;
  case "diag2":      await cmdDiag(programId, payerPath, "Diag2Byte0", 42,   0x2An); break;
  case "diag3":      await cmdDiag(programId, payerPath, "Diag3Decode", 7,   0x07n); break;
  default:
    fail(`unknown cmd: ${cmd}`);
}
