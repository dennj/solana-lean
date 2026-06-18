# Lean browser WebAssembly runtime adapter

This directory holds the runtime adapter for browser/reactor builds using
`lean --target=wasm32-unknown-unknown` and
`leanc --target=wasm32-unknown-unknown`.

Unlike `runtime/wasm`, this target is not a WASI command:

- it has no `_start`;
- it imports no `wasi_snapshot_preview1` functions;
- it exports `lean_web_init` and keeps the instance alive;
- browser/JS code supplies the `lean_web` import module.

The shared freestanding runtime still provides Lean objects, strings, arrays,
closures, reference counting, and allocation. This adapter only routes host
operations into JS imports and exposes a few helpers for JS string marshalling.

Required JS imports:

```js
{
  lean_web: {
    log(ptr, len) {},
    panic(ptr, len) {},
    dom_set_text(idPtr, idLen, textPtr, textLen) {},
    dom_set_html(idPtr, idLen, htmlPtr, htmlLen) {},
    dom_get_value_len(idPtr, idLen) {},
    dom_get_value(idPtr, idLen, dstPtr, dstLen) {},
    dom_set_value(idPtr, idLen, valuePtr, valueLen) {}
  }
}
```

The linked module exports memory, `lean_web_init`, and any Lean functions marked
with `@[export ...]` by the compiler/linker.
