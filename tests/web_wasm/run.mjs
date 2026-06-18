import { readFile } from 'node:fs/promises';
import { argv } from 'node:process';

const wasm = await readFile(argv[2]);
const module = await WebAssembly.compile(wasm);
const decoder = new TextDecoder();
const encoder = new TextEncoder();
const importsNeeded = WebAssembly.Module.imports(module);
const wasiImports = importsNeeded.filter((imp) => imp.module === 'wasi_snapshot_preview1');
if (wasiImports.length !== 0) {
  throw new Error(`browser module unexpectedly imports WASI: ${wasiImports.map((i) => i.name).join(', ')}`);
}

const metadataSections = WebAssembly.Module.customSections(module, 'lean4wasm');
if (metadataSections.length !== 1) {
  throw new Error(`expected one lean4wasm custom section, got ${metadataSections.length}`);
}
const metadata = JSON.parse(decoder.decode(metadataSections[0]));
if (metadata.generator !== 'Lean4Wasm' || metadata.target !== 'wasm32-unknown-unknown') {
  throw new Error(`unexpected lean4wasm metadata: ${JSON.stringify(metadata)}`);
}

let instance;
const dom = new Map();

function memoryBytes() {
  return new Uint8Array(instance.exports.memory.buffer);
}

function readUtf8(ptr, len) {
  return decoder.decode(memoryBytes().subarray(ptr, ptr + len));
}

const imports = {
  lean_web: {
    log(ptr, len) {
      console.log(readUtf8(ptr, len));
    },
    panic(ptr, len) {
      throw new Error(readUtf8(ptr, len));
    },
    dom_set_text(idPtr, idLen, textPtr, textLen) {
      dom.set(readUtf8(idPtr, idLen), readUtf8(textPtr, textLen));
    },
    dom_set_html(idPtr, idLen, htmlPtr, htmlLen) {
      dom.set(readUtf8(idPtr, idLen), readUtf8(htmlPtr, htmlLen));
    },
    dom_get_value_len(idPtr, idLen) {
      return encoder.encode(dom.get(readUtf8(idPtr, idLen)) ?? '').length;
    },
    dom_get_value(idPtr, idLen, dstPtr, dstLen) {
      const bytes = encoder.encode(dom.get(readUtf8(idPtr, idLen)) ?? '').subarray(0, dstLen);
      memoryBytes().set(bytes, dstPtr);
      return bytes.length;
    },
    dom_set_value(idPtr, idLen, valuePtr, valueLen) {
      dom.set(readUtf8(idPtr, idLen), readUtf8(valuePtr, valueLen));
    },
  },
};

instance = await WebAssembly.instantiate(module, imports);

if (typeof instance.exports.lean_web_init !== 'function') {
  throw new Error('missing lean_web_init export');
}
if (typeof instance.exports.lean_render !== 'function') {
  throw new Error('missing lean_render export');
}
if (typeof instance.exports.lean_render_plot !== 'function') {
  throw new Error('missing lean_render_plot export');
}
if (typeof instance.exports.lean_render_todo !== 'function') {
  throw new Error('missing lean_render_todo export');
}
if (typeof instance.exports.lean_next_calendar !== 'function') {
  throw new Error('missing lean_next_calendar export');
}
if (typeof instance.exports.lean_next_amplitude !== 'function') {
  throw new Error('missing lean_next_amplitude export');
}
if (typeof instance.exports.lean_next_frequency !== 'function') {
  throw new Error('missing lean_next_frequency export');
}

instance.exports.lean_web_init();
let calendarState = 40;
let eventCount = 0;
let amplitudeState = 6;
let frequencyState = 2;
instance.exports.lean_render(calendarState, 0, 0, eventCount, amplitudeState, frequencyState, 0);
calendarState = instance.exports.lean_next_calendar(110, calendarState);
eventCount += 1;
instance.exports.lean_render(calendarState, 0, 0, eventCount, amplitudeState, frequencyState, 0);
instance.exports.lean_render_todo(1, 1, 0);
dom.set('todo-text-0', 'Write Lean todo');
amplitudeState = instance.exports.lean_next_amplitude(10, amplitudeState);
frequencyState = instance.exports.lean_next_frequency(12, frequencyState);
eventCount += 1;
instance.exports.lean_render_plot(calendarState, 0, eventCount, amplitudeState, frequencyState, 0);

const app = [...dom.values()].join('\n');
for (const marker of [
  'Lean component registry',
  'Calendar',
  'June 2026',
  'Sun</span><span>Mon</span>',
  'Selected by Lean: June 10',
  'Todo list',
  'id="todo-input"',
  'Add</button>',
  'type="checkbox"',
  'Lean todo state: 1/1 done',
  'Write Lean todo',
  'Sine plot',
  'Amplitude <strong id="plot-amplitude-label">',
  'Frequency <strong id="plot-frequency-label">',
  'Lean4Lean typechecker',
  'id="checker-file"',
  'Upload package</label>',
  'id="checker-input"',
  'Check package</button>',
  'Lean4Solana',
  'Lean4Wasm',
  'Lean4Linux',
  'Linux lib/nlattr.c replacement',
  'NlAttrCore.lean compiles to an allocation-free kernel-linked RISC-V object.',
]) {
  if (!app.includes(marker)) {
    throw new Error(`Lean-rendered page missing marker: ${marker}`);
  }
}

for (const staleMarker of [
  'Driver' + '.lean',
  'Netlink-style' + ' TLV',
  'kernel-module' + ' path',
  'kernel module' + ' path',
  'It still' + ' presents',
  'now' + ' behaves',
]) {
  if (app.includes(staleMarker)) {
    throw new Error(`Lean-rendered page still contains stale Linux driver marker: ${staleMarker}`);
  }
}

if (dom.get('plot-amplitude-label') !== '1.10x') {
  throw new Error(`plot amplitude label was not updated by Lean: ${dom.get('plot-amplitude-label') ?? '<missing>'}`);
}
if (dom.get('plot-frequency-label') !== '12 cycles') {
  throw new Error(`plot frequency label was not updated by Lean: ${dom.get('plot-frequency-label') ?? '<missing>'}`);
}

console.log(`counter=${dom.get('counter') ?? ''}`);
