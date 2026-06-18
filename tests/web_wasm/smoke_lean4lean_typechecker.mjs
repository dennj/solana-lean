import { readFile } from "node:fs/promises";

const wasmPath = process.argv[2];
if (!wasmPath) {
  console.error("usage: node smoke_lean4lean_typechecker.mjs <lean4lean_typechecker.wasm>");
  process.exit(2);
}

class ProcExit extends Error {
  constructor(code) {
    super(`proc_exit ${code}`);
    this.code = code;
  }
}

const wasm = await readFile(wasmPath);
let memory;
const encoder = new TextEncoder();

function dataView() {
  return new DataView(memory.buffer);
}

function u32(addr) {
  return dataView().getUint32(addr, true);
}

function writeUtf8(text) {
  const bytes = encoder.encode(text);
  const ptr = exports.lean4lean_alloc_bytes(bytes.length);
  new Uint8Array(memory.buffer).set(bytes, ptr);
  return { ptr, len: bytes.length };
}

const imports = {
  wasi_snapshot_preview1: {
    fd_write(_fd, iovs, iovsLen, out) {
      let written = 0;
      for (let i = 0; i < iovsLen; i++) {
        written += u32(iovs + i * 8 + 4);
      }
      if (out) dataView().setUint32(out, written, true);
      return 0;
    },
    fd_read(_fd, _iovs, _iovsLen, out) {
      if (out) dataView().setUint32(out, 0, true);
      return 0;
    },
    args_sizes_get(argc, argvBufSize) {
      dataView().setUint32(argc, 0, true);
      dataView().setUint32(argvBufSize, 0, true);
      return 0;
    },
    args_get() {
      return 0;
    },
    proc_exit(code) {
      throw new ProcExit(code);
    },
  },
};

const { instance } = await WebAssembly.instantiate(wasm, imports);
memory = instance.exports.memory;
const exports = instance.exports;

for (const name of [
  "lean_wasm_module_init",
  "lean4lean_typechecker_main",
  "lean4lean_check_text",
  "lean4lean_alloc_bytes",
]) {
  if (typeof exports[name] !== "function") {
    throw new Error(`missing ${name}`);
  }
}

exports.lean_wasm_module_init(1, 0);

const checks = [
  ["main(0)", () => exports.lean4lean_typechecker_main(0), 0],
];

for (const [name, run, expected] of checks) {
  const actual = run();
  if (actual !== expected) {
    throw new Error(`${name}: expected ${expected}, got ${actual}`);
  }
}

const acceptedAst = `module Lean4Lean.Tx.Text
level zero
expr 0 sort 0
expr 1 bvar 0
expr 2 bvar 1
expr 3 forall h 1 2
expr 4 forall P 0 3
expr 5 lam h 1 1
expr 6 lam P 0 5
expr 7 const Lean4Lean.Tx.Text.idProp
decl def Lean4Lean.Tx.Text.idProp 4 6
decl theorem Lean4Lean.Tx.Text.idPropThm 4 7
`;

const rejectedAxiomAst = `module Lean4Lean.Tx.Text
level zero
expr 0 sort 0
decl axiom Lean4Lean.Tx.Text.bad 0
`;

const rejectedSorryAst = `module Lean4Lean.Tx.Text
level zero
expr 0 sort 0
expr 1 bvar 0
expr 2 bvar 1
expr 3 forall h 1 2
expr 4 forall P 0 3
expr 5 const sorryAx
expr 6 const Bool.false
expr 7 app 5 4
expr 8 app 7 6
decl theorem Lean4Lean.Tx.Text.bad 4 8
`;

{
  const { ptr, len } = writeUtf8(acceptedAst);
  const code = exports.lean4lean_check_text(ptr, len);
  if (code !== 0) {
    throw new Error(`accepted AST failed with code ${code}`);
  }
}

{
  const { ptr, len } = writeUtf8(rejectedAxiomAst);
  const code = exports.lean4lean_check_text(ptr, len);
  if (code === 0) {
    throw new Error("rejected axiom AST unexpectedly passed");
  }
}

{
  const { ptr, len } = writeUtf8(rejectedSorryAst);
  const code = exports.lean4lean_check_text(ptr, len);
  if (code === 0) {
    throw new Error("rejected sorryAx AST unexpectedly passed");
  }
}

try {
  exports._start();
} catch (error) {
  if (!(error instanceof ProcExit) || error.code !== 0) {
    throw error;
  }
}

console.log(`ok ${wasmPath}`);
