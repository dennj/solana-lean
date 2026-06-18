# Lean nlattr Publication Status

This is the closure audit for the Lean-backed `lib/nlattr.c` replacement.
It records what can be claimed now, what is only partially established, and
what must still be checked before publication.

Last refreshed: 2026-06-08, after the installer cleanup and full acceptance run.

## Current Claim

The current repository supports this claim:

> A Lean implementation is routed into the Linux `lib/nlattr.c` replacement
> path for the exported nlattr API surface. The main validator/parser path has
> connected Lean proofs for totality, executable conformance, parsed-message
> byte bounds, max-type acceptance, and policy-index behavior. The remaining C
> code is a narrow kernel adapter for raw ABI access, effects, skb mutation,
> runtime entry points, and export metadata.

The current repository does not yet support this stronger claim:

> Every behavior of upstream `lib/nlattr.c` is independently specified and
> fully proved equivalent to the Lean replacement under all kernel inputs.

## Local Checks Run

| Check | Status | Notes |
| --- | --- | --- |
| `./smoke_lean_core.sh` | Pass | Compiles the Lean core, runs host smoke tests, and checks that `lean_nlattr_array_index_nospec` remains referenced by generated code. |
| `./smoke_install_replacement.sh` | Pass | Verifies the install path can populate a Linux-like tree. |
| `./run_kernel_object_docker.sh` | Pass | Builds `lib/nlattr.o`, `lib/lean_nlattr_hook.o`, and `lib/lean_nlattr_core.o` in a Linux tree, then runs object-level replacement audit. |
| `./run_qemu_boot_docker.sh` | Pass | Builds and boots a RISC-V kernel with the Lean nlattr replacement, then runs linked-mode replacement audit. |
| `./run_netlink_stress_docker.sh` | Pass | Builds and boots a RISC-V kernel with the Lean nlattr replacement, runs linked-mode audit, then exercises netlink stress workload. |
| `./run_acceptance_docker.sh` | Pass | Serialized pass covering local smoke, install smoke, publication hygiene, one Docker Lean-toolchain prepare, kernel object build/audit, QEMU boot/audit, size report, kernel benchmark, and netlink stress. |
| `./run_kernel_benchmark_docker.sh` | Pass | Builds the benchmark module, boots QEMU, checks observable validation behavior, and reports QEMU-only timing. |
| `./run_size_report_docker.sh` | Pass | Saved `build/lean_nlattr/size_report.txt`; Lean replacement text is currently 1070% of original C `nlattr.o` text. |
| `./check_publication_hygiene.sh` | Pass | Checks the package file manifest, executable script bits, removed working labels, `NlAttrCore.lean`/`NlAttrMemory.lean` proof placeholders and partial definitions, shell syntax, and `shellcheck` when available. |

No required Docker publication check remains unrun in this audit. Publication-grade
performance on pinned hardware remains outside this audit.

## Size Report

The latest `run_size_report_docker.sh` output is saved at
`build/lean_nlattr/size_report.txt`.

| Object | Text | Data | BSS | File bytes | Instructions |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original C `nlattr.o` | 7,670 | 344 | 0 | 43,976 | 1,961 |
| Lean exports/thunks | 352 | 176 | 0 | 6,000 | 0 |
| Lean hook | 3,257 | 71 | 65,536 | 19,472 | 859 |
| Lean core | 78,486 | 0 | 0 | 232,400 | 26,339 |
| Lean total | 82,095 | 247 | 65,536 | 257,872 | - |

Current size result: Lean replacement text is 1070% of the original C
`nlattr.o` text. Lean text+data, excluding BSS, is 1027% of original C
text+data. Lean total allocatable sections are 1845% of original C `nlattr.o`.

## Proof Coverage

| Area | Connected to compiled code | Current proof status | Gap |
| --- | --- | --- | --- |
| Validator entry | Yes: `validateParseCore`, `validateBoundedRegionCore` | Totality, `ok <-> ValidateParseSpec`, `ok <-> ValidateBoundedSpec`, spatial safety, byte-bounds, max-type, policy-index theorems. | `ValidateLoopSpec` is still close to executable structure, not an independent nlattr+policy grammar. |
| Raw nlattr parsing model | Yes through `rawRegion` and `BoundedValidateInput.ofRaw` | `ByteArray` region access carries bounds proofs; parsed entries have payload/header bounds. | Initial `rawByteArray` materialization is a C boundary copying raw kernel memory into Lean-owned memory. |
| Attribute payload helpers | Partially | Payload-window bounds are proved for `nlattrFullView` and `min64 requested payloadLen`. | No full API equivalence proof for `nla_memcmp`, `nla_memcpy`, `nla_strscpy`, `nla_strcmp`, `nla_strdup`. |
| Policy table reads | Partially | Policy rows are represented as bounded `PolicyTableView.row`; policy-index equality is proved under max-type and non-overflow. | Policy range-pointer reads, callback behavior, and effect results remain C/kernel boundaries. |
| Diagnostics and extack | No, effect boundary | Lean decides when diagnostics are requested. | Message text, `bad_attr`, `policy`, and warning side effects are not fully specified in Lean. |
| Parse table writes | Partially | `TableWriteAccepted` records expected table-write success. | Actual table mutation is through C `setTb`; memory aliasing and table layout are not fully modeled. |
| skb builders | Partially | Size arithmetic and builder status are Lean code. | `skb_tailroom`, padding, `skb_put`, and output mutation are C/kernel effects without a full Lean heap/skb model. |
| Runtime/export integration | Build path only | Kbuild path links Lean object and C adapter; smoke install, kernel object audit, QEMU boot, netlink stress, acceptance, and size report pass. | Needs repeatable CI/release logs before publication. |

## Exported Surface Matrix

Legend:

- Logic: where the behavioral decision lives.
- Boundary: remaining C/kernel dependency.
- Proof: connected theorem coverage, not tests.
- Test: local evidence currently available.

### Validator And Parser

| Export | Linux role | Logic | Boundary | Proof | Test |
| --- | --- | --- | --- | --- | --- |
| `lean_nlattr_validate_parse_core` | Internal scalar validator/parser core | Lean | Raw byte copy, policy callbacks, extack, table writes, nospec extern | Strongest connected coverage: totality, conformance to `ValidateParseSpec`, byte bounds, max-type, policy-index | Host smoke |
| `lean_public___nla_validate` | `__nla_validate` body | Lean wrapper over validator core | Same as core | Covered through core theorem shape, public return decoding not separately proved | Host smoke, install smoke |
| `lean_public___nla_parse` | `__nla_parse` body | Lean wrapper over validator core | Same as core plus parse table clearing | Covered through core theorem shape, table mutation not fully modeled | Host smoke, install smoke |

### Lookup

| Export | Linux role | Logic | Boundary | Proof | Test |
| --- | --- | --- | --- | --- | --- |
| `lean_nlattr_find_core` | Internal scalar `nla_find` core | Lean | Raw byte copy | Memory model has find/entry bounds lemmas; no public API equivalence theorem | Host smoke |
| `nla_find` | Public `nla_find` | Lean wrapper | Raw byte copy | Same as core | Host smoke, install smoke |

### Attribute Data Helpers

| Export | Linux role | Logic | Boundary | Proof | Test |
| --- | --- | --- | --- | --- | --- |
| `lean_nlattr_memcmp_core` | Internal compare core | Lean | Raw input data copy | Payload-window bounds only; no full equivalence theorem | Host smoke |
| `nla_memcmp` | Public compare | Lean wrapper | Raw input data copy | Same as core | Host smoke, install smoke |
| `lean_nlattr_memcpy_core` | Internal copy core | Lean | Destination writes through C | Payload source bounds only; destination mutation not modeled | Host smoke |
| `nla_memcpy` | Public copy | Lean wrapper | Destination writes through C | Same as core | Host smoke, install smoke |
| `lean_nlattr_strscpy_core` | Internal string-copy core | Lean | Destination writes through C | Payload source bounds only; destination and truncation equivalence not fully proved | Host smoke |
| `nla_strscpy` | Public string copy | Lean wrapper | Destination writes through C | Same as core | Host smoke, install smoke |
| `lean_nlattr_strcmp_core` | Internal string compare core | Lean | C-string length reads through C | Attribute payload bounds only; peer C-string bounds are caller/kernel contract | Host smoke |
| `nla_strcmp` | Public string compare | Lean wrapper | C-string length reads through C | Same as core | Host smoke, install smoke |
| `lean_nlattr_str_payload_len_core` | Internal payload string length | Lean | Raw byte copy | Payload-window bounds only | Host smoke |
| `nla_strdup` | Public string duplicate | Lean plus C allocation | Allocation and destination writes through C | No full allocation/result equivalence theorem | Host smoke, install smoke |

### Policy Helpers

| Export | Linux role | Logic | Boundary | Proof | Test |
| --- | --- | --- | --- | --- | --- |
| `lean_nlattr_policy_len_core` | Internal policy length core | Lean | Raw policy memory copy | No full API equivalence theorem | Host smoke |
| `nla_policy_len` | Public policy length | Lean wrapper | Raw policy memory copy | Same as core | Host smoke, install smoke |
| `lean_nlattr_range_unsigned_supported_core` | Internal unsigned range support predicate | Lean | None beyond scalar inputs | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `lean_nlattr_range_unsigned_min_core` | Internal unsigned range min | Lean | Caller-supplied policy/range values | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `lean_nlattr_range_unsigned_max_core` | Internal unsigned range max | Lean | Caller-supplied policy/range values | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `nla_get_range_unsigned` | Public unsigned range extraction | Lean wrapper | Raw policy/range memory copy | No full public equivalence theorem | Host smoke, install smoke |
| `lean_nlattr_range_signed_supported_core` | Internal signed range support predicate | Lean | None beyond scalar inputs | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `lean_nlattr_range_signed_min_core` | Internal signed range min | Lean | Caller-supplied policy/range values | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `lean_nlattr_range_signed_max_core` | Internal signed range max | Lean | Caller-supplied policy/range values | Local arithmetic/branch logic, no public API theorem | Host smoke |
| `nla_get_range_signed` | Public signed range extraction | Lean wrapper | Raw policy/range memory copy | No full public equivalence theorem | Host smoke, install smoke |

### Builder Arithmetic And skb Mutation

| Export | Linux role | Logic | Boundary | Proof | Test |
| --- | --- | --- | --- | --- | --- |
| `lean_nlattr_builder_required_core` | Internal required-size helper | Lean | None beyond scalar inputs | Arithmetic implementation only; no public theorem | Host smoke |
| `lean_nlattr_builder_attr_size_core` | Internal attr-size helper | Lean | None beyond scalar inputs | Arithmetic implementation only; no public theorem | Host smoke |
| `lean_nlattr_builder_padlen_core` | Internal pad-length helper | Lean | None beyond scalar inputs | Arithmetic implementation only; no public theorem | Host smoke |
| `lean_nlattr_builder_status_core` | Internal builder status helper | Lean | Caller-provided tailroom | Arithmetic implementation only; no public theorem | Host smoke |
| `lean_public___nla_reserve` | `__nla_reserve` body | Lean decision, C skb write | `skb_put`, raw header stores | No full skb/output theorem | Host smoke, install smoke |
| `lean_public___nla_reserve_64bit` | `__nla_reserve_64bit` body | Lean decision, C padding/write | `nla_align_64bit`, `skb_put`, raw stores | No full skb/output theorem | Host smoke, install smoke |
| `lean_public___nla_reserve_nohdr` | `__nla_reserve_nohdr` body | Lean decision, C skb write | `skb_put` | No full skb/output theorem | Host smoke, install smoke |
| `nla_reserve` | Public reserve | Lean wrapper | `skb_tailroom`, `skb_put`, raw stores | No full skb/output theorem | Host smoke, install smoke |
| `nla_reserve_64bit` | Public 64-bit reserve | Lean wrapper | `skb_tailroom`, padding helper, `skb_put` | No full skb/output theorem | Host smoke, install smoke |
| `nla_reserve_nohdr` | Public no-header reserve | Lean wrapper | `skb_tailroom`, `skb_put` | No full skb/output theorem | Host smoke, install smoke |
| `lean_public___nla_put` | `__nla_put` body | Lean decision, C copy/write | `skb_put`, raw source copy, raw stores | No full skb/output theorem | Host smoke, install smoke |
| `lean_public___nla_put_64bit` | `__nla_put_64bit` body | Lean decision, C copy/write | padding helper, `skb_put`, raw copy/stores | No full skb/output theorem | Host smoke, install smoke |
| `lean_public___nla_put_nohdr` | `__nla_put_nohdr` body | Lean decision, C copy/write | `skb_put`, raw copy | No full skb/output theorem | Host smoke, install smoke |
| `nla_put` | Public put | Lean wrapper | `skb_tailroom`, `skb_put`, raw copy/stores | No full skb/output theorem | Host smoke, install smoke |
| `nla_put_64bit` | Public 64-bit put | Lean wrapper | `skb_tailroom`, padding helper, `skb_put`, raw copy/stores | No full skb/output theorem | Host smoke, install smoke |
| `nla_put_nohdr` | Public no-header put | Lean wrapper | `skb_tailroom`, `skb_put`, raw copy | No full skb/output theorem | Host smoke, install smoke |
| `nla_append` | Public append | Lean wrapper | `skb_tailroom`, `skb_put`, raw copy | No full skb/output theorem | Host smoke, install smoke |

## C Boundary Inventory

These are expected C/kernel boundaries, not Lean proofs:

| Boundary | Current role | Publication treatment |
| --- | --- | --- |
| `lean_nlattr_raw_byte_array` | Copies raw kernel memory into Lean `ByteArray` regions. | Must be described as trusted ABI materialization. |
| `lean_nlattr_raw_ptr_byte` | Reads caller C strings and similar raw non-nlattr memory. | Must stay outside nlattr payload safety claim. |
| `lean_nlattr_raw_ptr_set_byte` | Writes destination buffers, headers, and skb payloads. | Needs separate mutation model if claiming output correctness. |
| `lean_nlattr_raw_set_tb` | Writes parse table entries. | Needs table memory/aliasing model for full proof. |
| `lean_nlattr_array_index_nospec` | Linux nospec masking/barrier. | Runtime call is preserved; Lean normalizes result for proof. |
| `lean_nlattr_policy_validate_fn_raw` | Policy callback invocation. | Callback contract must be stated as an assumption. |
| `lean_nlattr_report_*` / warning hooks | extack and diagnostic side effects. | Side effects are not fully modeled in Lean. |
| `lean_nlattr_strdup_alloc` | Kernel allocation. | Allocation success/failure and buffer ownership are C boundary. |
| `lean_nlattr_skb_*` | skb tailroom, padding, and mutation. | Needs skb model for full builder correctness. |
| `nlattr_exports.c` | Linux `EXPORT_SYMBOL` metadata. | Acceptable C metadata, not behavior. |

## Required Before Publication

1. Preserve the Docker acceptance and size-report output in release notes or CI logs.
2. Decide whether the paper claim is the current connected-subset proof claim or a stronger full-equivalence claim.
3. If the stronger claim is required, add an independent nlattr+policy spec and prove `ValidateLoopSpec` equivalent to it.
4. Add C-boundary contracts for callback, extack, parse-table writes, allocation, and skb mutation.
5. Add API-level equivalence theorems for each public export, not only validator/parser internals.
6. Run publication-grade performance only after semantic equivalence is frozen.

## Recommended Publication Wording

Use:

> We replace the exported `lib/nlattr.c` implementation path with Lean-generated
> code and prove connected safety/conformance properties for the main validation
> and parsing core.

Avoid:

> We fully prove every behavior of `lib/nlattr.c` equivalent to Lean.

That stronger statement is not yet supported by the current proofs.
