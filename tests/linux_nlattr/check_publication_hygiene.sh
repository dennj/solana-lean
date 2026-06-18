#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v rg >/dev/null 2>&1; then
  echo "missing required tool: rg" >&2
  exit 1
fi

replacement_files=(
  ".gitignore"
  "NlAttrCore.lean"
  "NlAttrMemory.lean"
  "lean_nlattr_hook.c"
  "lean_nlattr_kbuild.mk"
  "nlattr_exports.c"
  "nlattr_raw.c"
)

verification_files=(
  "Dockerfile"
  "PUBLICATION_STATUS.md"
  "README.md"
  "audit_replacement.sh"
  "check_publication_hygiene.sh"
  "install_replacement.sh"
  "kernel_benchmark.sh"
  "kernel_object_smoke.sh"
  "lean_core_host_smoke.c"
  "lean_nlattr_benchmark.c"
  "lean_nlattr_netlink_stress_init.c"
  "lean_nlattr_selftest.c"
  "prepare_linux_lean_docker.sh"
  "qemu_boot_smoke.sh"
  "qemu_netlink_stress.sh"
  "run_acceptance_docker.sh"
  "run_kernel_benchmark_docker.sh"
  "run_kernel_object_docker.sh"
  "run_linux_check_docker.sh"
  "run_netlink_stress_docker.sh"
  "run_qemu_boot_docker.sh"
  "run_size_report_docker.sh"
  "size_report.sh"
  "smoke_install_replacement.sh"
  "smoke_lean_core.sh"
)

check_file_manifest() {
  local work actual expected

  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  actual="$work/actual"
  expected="$work/expected"

  find "$SCRIPT_DIR" -maxdepth 1 -type f -exec basename {} \; |
    LC_ALL=C sort > "$actual"
  printf '%s\n' "${replacement_files[@]}" "${verification_files[@]}" |
    LC_ALL=C sort > "$expected"

  if ! diff -u "$expected" "$actual"; then
    echo "FAIL: top-level file manifest changed; classify the file in the hygiene gate and README" >&2
    exit 1
  fi
}

check_executable_scripts() {
  local script

  for script in "$SCRIPT_DIR"/*.sh; do
    if [[ ! -x "$script" ]]; then
      echo "FAIL: script is not executable: $script" >&2
      exit 1
    fi
  done
}

check_file_manifest
check_executable_scripts

blocked_terms=(
  "ACCEPTANCE_WITH_""SIZE"
  "size_report.""latest"
  "kernel self""tests"
  "Export-""only"
  "#include \"nlattr_c_"
  "NlAttr""Spec"
  "nlattr_policy_""raw"
  "O""LD_"
  "FULL_""HOOK"
  "leg""acy"
  "fall""back"
  "st""ub"
  "de""bug"
  "TO""DO"
  "FIX""ME"
  "tempo""rary"
  "obso""lete"
  "old at""tempt"
  "t""oy"
  "work""around"
  "W""IP"
  "pha""se"
  "trans""plant"
  "sta""le"
)

blocked_args=()
for term in "${blocked_terms[@]}"; do
  blocked_args+=(-e "$term")
done

if rg -n "${blocked_args[@]}" "$SCRIPT_DIR"; then
  echo "FAIL: publication hygiene found blocked working labels" >&2
  exit 1
fi

proof_terms=(
  "so""rry"
  "ad""mit"
  "axi""om"
  "un""safe"
  "partial ""def"
)

proof_args=()
for term in "${proof_terms[@]}"; do
  proof_args+=(-e "$term")
done

if rg -n "${proof_args[@]}" \
    "$SCRIPT_DIR/NlAttrCore.lean" \
    "$SCRIPT_DIR/NlAttrMemory.lean"; then
  echo "FAIL: Lean proof/code hygiene failed" >&2
  exit 1
fi

bash -n "$SCRIPT_DIR"/*.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$SCRIPT_DIR"/*.sh
else
  echo "SKIP: shellcheck is not installed"
fi

echo "PASS: Lean nlattr publication hygiene"
