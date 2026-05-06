// Tiny WASI host runner for the wasm32-wasip1 test corpus. Loads a .wasm
// module, instantiates it with Node's built-in WASI preview1, and runs
// `_start`. Stdout/stderr from the module are forwarded to this
// process's stdout/stderr; the WASI exit code is reported on stdout
// as `exit=<n>` so the bash harness can grep for it.

import { WASI } from 'node:wasi';
import { readFile } from 'node:fs/promises';
import { argv } from 'node:process';

const wasm = await readFile(argv[2]);
const wasi = new WASI({
  version: 'preview1',
  args: [argv[2]],
  env: {},
});
const { instance } = await WebAssembly.instantiate(wasm, wasi.getImportObject());
try {
  const exitCode = wasi.start(instance);
  console.log(`exit=${exitCode ?? 0}`);
} catch (e) {
  if (e && typeof e === 'object' && 'code' in e) {
    console.log(`exit=${e.code}`);
  } else {
    throw e;
  }
}
