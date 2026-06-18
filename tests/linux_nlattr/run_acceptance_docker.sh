#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [/path/to/linux]" >&2
  exit 2
fi

linux_arg=()
if [[ $# -eq 1 ]]; then
  linux_arg=("$1")
fi

lock_dir="${LEAN_NLATTR_ACCEPTANCE_LOCK:-${TMPDIR:-/tmp}/lean-nlattr-docker-acceptance.lock}"
if [[ "${LEAN_NLATTR_SKIP_ACCEPTANCE_LOCK:-0}" != "1" ]]; then
  if ! mkdir "$lock_dir" 2>/dev/null; then
    echo "another Lean nlattr Docker acceptance run appears to be active: $lock_dir" >&2
    echo "remove the lock only if no check runner is using the shared Linux tree" >&2
    exit 1
  fi
  trap 'rm -rf "$lock_dir"' EXIT
fi

run_check() {
  echo
  echo "==> $*"
  "$@"
}

run_docker_check() {
  if [[ ${#linux_arg[@]} -eq 0 ]]; then
    run_check "$1"
  else
    run_check "$1" "${linux_arg[@]}"
  fi
}

run_check "$SCRIPT_DIR/smoke_lean_core.sh"
run_check "$SCRIPT_DIR/smoke_install_replacement.sh"
run_check "$SCRIPT_DIR/check_publication_hygiene.sh"
run_check "$SCRIPT_DIR/prepare_linux_lean_docker.sh"

export LEAN_NLATTR_SKIP_PREPARE=1
run_docker_check "$SCRIPT_DIR/run_kernel_object_docker.sh"
run_docker_check "$SCRIPT_DIR/run_qemu_boot_docker.sh"
run_docker_check "$SCRIPT_DIR/run_size_report_docker.sh"
run_docker_check "$SCRIPT_DIR/run_kernel_benchmark_docker.sh"
run_docker_check "$SCRIPT_DIR/run_netlink_stress_docker.sh"

echo
echo "PASS: Lean nlattr Docker acceptance"
