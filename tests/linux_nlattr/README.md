# Lean nlattr Replacement

This directory contains a Lean-backed replacement for Linux `lib/nlattr.c`.

The publication path is deliberately linear:

1. Lean implements the nlattr behavior in `NlAttrCore.lean`.
2. `install_replacement.sh` copies the Lean source, raw ABI helpers, freestanding runtime, export table, hook adapter, and Kbuild fragment into a Linux tree.
3. Linux Kbuild invokes Lean and LLVM to build `lib/lean_nlattr_core.o`.
4. Linux links that object with `lib/nlattr.o` and `lib/lean_nlattr_hook.o`.
5. QEMU boots exercise the replacement through real netlink workloads and a custom boot-time nlattr selftest.

The replacement path is linear; benchmark and selftest files are only attached by the check runners.

## Replacement Files

- `NlAttrMemory.lean` contains the proof-carrying `ByteArray` memory model used to make nlattr reads require in-bounds proofs.
- `NlAttrCore.lean` contains the exported Lean implementation compiled into the kernel object.
- `nlattr_raw.c` is the narrow generic raw-memory helper for Linux ABI access. Policy-row decoding is implemented in Lean.
- `lean_nlattr_hook.c` is the kernel adapter for callbacks, static ABI checks, allocation, skb helpers, and optional trace counters.
- `nlattr_exports.c` replaces Linux `lib/nlattr.c` with export metadata for symbols defined by the Lean core object.
- `lean_nlattr_kbuild.mk` teaches Kbuild how to invoke Lean, compile helper bitcode, link the freestanding runtime, and emit `lean_nlattr_core.o`.
- `install_replacement.sh` installs the replacement into a Linux source tree.
- `PUBLICATION_STATUS.md` is the explicit claim, proof, boundary, and test-status matrix.

## Verification Files

- `check_publication_hygiene.sh` checks the package file manifest, executable script bits, removed working labels, Lean proof placeholders, shell syntax errors, and shell issues when `shellcheck` is available.
- `smoke_lean_core.sh` and `lean_core_host_smoke.c` build and exercise the Lean scalar core on the host.
- `smoke_install_replacement.sh` checks installer idempotence against a small Linux-like tree.
- `audit_replacement.sh` checks the object and linked-kernel symbol routing invariants.
- `run_linux_check_docker.sh` is the shared Docker runner used by the small `run_*_docker.sh` entry points.
- `kernel_object_smoke.sh`, `qemu_boot_smoke.sh`, `qemu_netlink_stress.sh`, `kernel_benchmark.sh`, and `size_report.sh` are the Linux-tree checks invoked inside Docker.
- `lean_nlattr_selftest.c`, `lean_nlattr_netlink_stress_init.c`, and `lean_nlattr_benchmark.c` are attached only by their check runners.
- `Dockerfile` and `prepare_linux_lean_docker.sh` provide the Linux-runnable Lean/LLVM check environment.

## Quick Checks

Run the local Lean/core smoke:

```sh
./smoke_lean_core.sh
./smoke_install_replacement.sh
./check_publication_hygiene.sh
```

Prepare a Linux-runnable Lean toolchain inside Docker:

```sh
./prepare_linux_lean_docker.sh
```

Compile the kernel objects:

```sh
./run_kernel_object_docker.sh
```

Boot QEMU and exercise netlink paths:

```sh
./run_qemu_boot_docker.sh
./run_netlink_stress_docker.sh
```

Run the serialized acceptance pass:

```sh
./run_acceptance_docker.sh
```

That pass runs local smoke, install smoke, publication hygiene, prepares the Docker Lean toolchain once, then runs kernel object audit, QEMU boot audit, size report, kernel benchmark, and netlink stress.

Pass `/path/to/linux` to any Docker runner to use an existing Linux checkout instead of the shared Docker volume.

## Replacement Audit

`audit_replacement.sh` enforces the publication invariant:

- the saved upstream `lib/nlattr.c` `EXPORT_SYMBOL` surface exactly matches the replacement export surface;
- `lib/nlattr.o` does not contain or relocate to comparison-only original-C symbols;
- exported behavior is routed to `lib/lean_nlattr_core.o`, with `lib/nlattr.o` acting only as export metadata;
- exported helpers such as `__nla_validate`, `__nla_parse`, `nla_find`, `nla_policy_len`, and `nla_strscpy` are defined by Lean-generated code, not C helper bodies;
- non-exported helpers that matter to nlattr semantics, such as `nla_get_range_unsigned` and `nla_get_range_signed`, are still required in the Lean core object and final linked kernel.

This supports the claim that the `lib/nlattr.c` implementation path is replaced by Lean. It does not claim that the kernel build contains no C support code: generic raw Linux ABI access, callback bridges, skb mutation, runtime entry points, and `EXPORT_SYMBOL` metadata are intentionally kept in narrow C adapters.

## Manual Install

From this directory:

```sh
./install_replacement.sh /path/to/linux
```

Then build with a Linux-runnable Lean and LLVM toolchain available to Kbuild:

```sh
make -C /path/to/linux ARCH=riscv LLVM=1 olddefconfig
make -C /path/to/linux ARCH=riscv LLVM=1 \
  LEAN_NLATTR_LEAN=/path/to/lean \
  LEAN_NLATTR_CLANG=clang-19 \
  LEAN_NLATTR_LD=ld.lld-19 \
  LEAN_NLATTR_OBJCOPY=llvm-objcopy-19 \
  LEAN_NLATTR_LLVM_LINK=llvm-link-19 \
  lib/nlattr.o lib/lean_nlattr_hook.o lib/lean_nlattr_core.o
```

`install_replacement.sh` saves the original Linux file as `lib/nlattr_c_original.c` before replacing `lib/nlattr.c`.

## Reports

Generate a size report comparing the saved original C object against the Lean replacement:

```sh
./run_size_report_docker.sh
```

Run the boot-time benchmark:

```sh
./run_kernel_benchmark_docker.sh
```

The benchmark generates a private `lean_nlattr_benchmark_original.c` include from `lib/nlattr_c_original.c`, then installs the Lean replacement and compares both implementations inside the same booted kernel.
Before timing, it checks return values and observable `struct netlink_ext_ack` diagnostics (`_msg`, `bad_attr`, and `policy`) for the validation cases.
It runs several rounds, alternates whether C or Lean runs first, and reports best and median samples. This is useful for regression tracking under QEMU, but it is not a final publication-grade performance claim.

For a longer run:

```sh
LEAN_NLATTR_BENCH_ITERS=100000 LEAN_NLATTR_BENCH_ROUNDS=21 ./run_kernel_benchmark_docker.sh
```

Publication-quality timing should run on pinned real hardware against an exact same-workload C baseline. The current QEMU benchmark intentionally prints method notes and counter-scope notes in the kernel log.

## Validation Boundary

The Lean side covers nlattr stream traversal, parse-table behavior, payload-size checks, raw `struct nla_policy` row decoding, policy metadata, range decisions, string and memory helpers, and the netlink builder functions from `lib/nlattr.c`.
`NlAttrMemory.lean` is the current checked model for moving raw nlattr reads into Lean-owned memory: header and payload reads are over a `ByteArray` region and every byte access is a `ByteArray.get` with an explicit `i < bytes.size` proof.

The C adapter is intentionally narrow: Lean decides when diagnostics, callbacks, and skb updates happen, while C currently performs generic raw memory access, nospec masking, extack/warning effects, callback invocation, skb mutation, runtime entry points, `EXPORT_SYMBOL` metadata, and static assertions that Linux layout assumptions still match the Lean model. Kbuild renames the generated Lean symbols that Lean cannot spell directly as C++ export identifiers, so public `__nla_*` bodies still come from the Lean object. Proof terms are checked by Lean and erased from the generated object.

The current automated target is RISC-V Linux under QEMU.
