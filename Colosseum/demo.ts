// Colosseum vault demo client.
//
// Usage:
//   bun install @solana/web3.js
//   PROGRAM_ID=<id> bun demo.ts deposit 100
//   PROGRAM_ID=<id> bun demo.ts withdraw 30
//
// Tracks vault state in a single 24-byte data account (balance,
// totalIn, totalOut as little-endian u64s). The state account's keypair
// is persisted to ./vault.json so successive runs hit the same vault.

import {
  Connection, Keypair, PublicKey, Transaction, TransactionInstruction,
  SystemProgram, sendAndConfirmTransaction, LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";

const RPC = process.env.SOLANA_RPC ?? "https://api.devnet.solana.com";
const PROGRAM_ID = new PublicKey(process.env.PROGRAM_ID!);
const VAULT_KEY_FILE = "./vault.json";
const PAYER_KEY_FILE = process.env.PAYER ?? `${homedir()}/.config/solana/id.json`;

const conn = new Connection(RPC, "confirmed");

function loadKeypair(path: string): Keypair {
  return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(readFileSync(path, "utf8"))));
}

function saveKeypair(path: string, kp: Keypair) {
  writeFileSync(path, JSON.stringify(Array.from(kp.secretKey)));
}

async function getOrCreateVault(payer: Keypair): Promise<Keypair> {
  if (existsSync(VAULT_KEY_FILE)) {
    const kp = loadKeypair(VAULT_KEY_FILE);
    if (await conn.getAccountInfo(kp.publicKey)) return kp;
  }
  const vault = Keypair.generate();
  const space = 24;
  const lamports = await conn.getMinimumBalanceForRentExemption(space);
  const tx = new Transaction().add(
    SystemProgram.createAccount({
      fromPubkey: payer.publicKey,
      newAccountPubkey: vault.publicKey,
      lamports, space,
      programId: PROGRAM_ID,
    }),
  );
  const sig = await sendAndConfirmTransaction(conn, tx, [payer, vault]);
  console.log(`created vault account ${vault.publicKey.toBase58()}`);
  console.log(`  https://explorer.solana.com/tx/${sig}?cluster=devnet`);
  saveKeypair(VAULT_KEY_FILE, vault);
  return vault;
}

function encodeInstr(op: number, amount: bigint): Buffer {
  const buf = Buffer.alloc(9);
  buf.writeUInt8(op, 0);
  buf.writeBigUInt64LE(amount, 1);
  return buf;
}

function decodeVault(data: Buffer): { balance: bigint, totalIn: bigint, totalOut: bigint } {
  return {
    balance:  data.readBigUInt64LE(0),
    totalIn:  data.readBigUInt64LE(8),
    totalOut: data.readBigUInt64LE(16),
  };
}

async function main() {
  const [_, __, opName, amountStr] = process.argv;
  if (!["deposit", "withdraw"].includes(opName)) {
    console.error("usage: PROGRAM_ID=<id> bun demo.ts <deposit|withdraw> <amount>");
    process.exit(1);
  }
  const op = opName === "deposit" ? 0 : 1;
  const amount = BigInt(amountStr);

  const payer = loadKeypair(PAYER_KEY_FILE);
  const vault = await getOrCreateVault(payer);

  const ix = new TransactionInstruction({
    keys: [{ pubkey: vault.publicKey, isSigner: false, isWritable: true }],
    programId: PROGRAM_ID,
    data: encodeInstr(op, amount),
  });

  const tx = new Transaction().add(ix);
  const sig = await sendAndConfirmTransaction(conn, tx, [payer]);
  const after = decodeVault((await conn.getAccountInfo(vault.publicKey))!.data);
  console.log(`${opName}(${amount}) sent`);
  console.log(`  https://explorer.solana.com/tx/${sig}?cluster=devnet`);
  console.log(`  vault state: balance=${after.balance} totalIn=${after.totalIn} totalOut=${after.totalOut}`);
}

main().catch(e => { console.error(e); process.exit(1); });
