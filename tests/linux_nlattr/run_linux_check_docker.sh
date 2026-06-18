#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 kernel_object|qemu_boot|size_report|kernel_benchmark|netlink_stress [/path/to/linux]" >&2
  exit 2
fi

CHECK="$1"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE="${LEAN_NLATTR_DOCKER_IMAGE:-lean-nlattr-ci:latest}"
LINUX_VOLUME="${LEAN_NLATTR_LINUX_VOLUME:-lean-nlattr-linux}"
LINUX_GIT_URL="${LEAN_NLATTR_LINUX_GIT_URL:-https://github.com/torvalds/linux.git}"
LEAN_VOLUME="${LEAN_NLATTR_LEAN_VOLUME:-lean-nlattr-lean}"
LEAN_PRESET="${LEAN_NLATTR_LEAN_CMAKE_PRESET:-release}"
ARCH="${ARCH:-riscv}"
LLVM="${LLVM:-1}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"
STRESS_ITERS="${LEAN_NLATTR_STRESS_ITERS:-32}"

case "$CHECK" in
  kernel_object)
    INNER="./kernel_object_smoke.sh"
    OUT_PREFIX="kernel-object"
    ;;
  qemu_boot)
    INNER="./qemu_boot_smoke.sh"
    OUT_PREFIX="qemu-boot"
    ;;
  size_report)
    INNER="./size_report.sh"
    OUT_PREFIX="size-report"
    ;;
  kernel_benchmark)
    INNER="./kernel_benchmark.sh"
    OUT_PREFIX="kernel-benchmark"
    ;;
  netlink_stress)
    INNER="./qemu_netlink_stress.sh"
    OUT_PREFIX="netlink-stress"
    ;;
  *)
    echo "unknown check: $CHECK" >&2
    exit 2
    ;;
esac

if [[ $# -gt 1 ]]; then
  echo "usage: $0 $CHECK [/path/to/linux]" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or is not on PATH" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker is not running" >&2
  exit 1
fi

if [[ "${LEAN_NLATTR_SKIP_PREPARE:-0}" != "1" ]]; then
  "$SCRIPT_DIR/prepare_linux_lean_docker.sh"
fi

linux_mount=()
if [[ $# -eq 1 ]]; then
  LINUX_HOST="$(cd "$1" && pwd)"
  linux_mount=(-v "$LINUX_HOST:/linux")
else
  docker volume create "$LINUX_VOLUME" >/dev/null
  linux_mount=(-v "$LINUX_VOLUME:/linux")

  echo ">> ensuring Linux checkout exists in Docker volume $LINUX_VOLUME"
  docker run --rm "${linux_mount[@]}" -e LINUX_GIT_URL="$LINUX_GIT_URL" "$IMAGE" \
    bash -lc '
      set -euo pipefail
      if [ ! -f /linux/Makefile ]; then
        if [ "$(find /linux -mindepth 1 -maxdepth 1 | wc -l)" -ne 0 ]; then
          echo "/linux is not empty but does not look like a Linux tree" >&2
          exit 1
        fi
        git clone --depth 1 --filter=blob:none "$LINUX_GIT_URL" /linux
      fi
    '
fi

if ! docker volume inspect "$LEAN_VOLUME" >/dev/null 2>&1; then
  echo "missing Docker volume $LEAN_VOLUME; run prepare_linux_lean_docker.sh first" >&2
  exit 1
fi

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lean-nlattr-${OUT_PREFIX}.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT

LEAN_NLATTR_LEAN="${LEAN_NLATTR_LEAN:-/lean-work/src/build/$LEAN_PRESET/stage1/bin/lean}"
LEAN_NLATTR_CLANG="${LEAN_NLATTR_CLANG:-clang-19}"
LEAN_NLATTR_LD="${LEAN_NLATTR_LD:-ld.lld-19}"
LEAN_NLATTR_LLVM_LINK="${LEAN_NLATTR_LLVM_LINK:-llvm-link-19}"

docker_env=(
  -e "ARCH=$ARCH"
  -e "LLVM=$LLVM"
  -e "QEMU_TIMEOUT=$QEMU_TIMEOUT"
  -e "LEAN_NLATTR_STRESS_ITERS=$STRESS_ITERS"
  -e "LEAN_NLATTR_LEAN=$LEAN_NLATTR_LEAN"
  -e "LEAN_NLATTR_CLANG=$LEAN_NLATTR_CLANG"
  -e "LEAN_NLATTR_LD=$LEAN_NLATTR_LD"
  -e "LEAN_NLATTR_LLVM_LINK=$LEAN_NLATTR_LLVM_LINK"
)

if [[ "$CHECK" == "size_report" ]]; then
  docker_env+=(-e "LEAN_NLATTR_SIZE_REPORT=/check-out/size_report.txt")
fi
if [[ -n "${MAKE_JOBS:-}" ]]; then
  docker_env+=(-e "MAKE_JOBS=$MAKE_JOBS")
fi
for env_name in LEAN_NLATTR_TRIPLE LEAN_NLATTR_HEAP_BYTES LEAN_NLATTR_BENCH_ITERS LEAN_NLATTR_BENCH_ROUNDS; do
  if [[ -n "${!env_name:-}" ]]; then
    docker_env+=(-e "$env_name=${!env_name}")
  fi
done

echo ">> running $CHECK in Docker"
docker run --rm \
  -v "$ROOT:/repo:ro" \
  -v "$OUT_DIR:/check-out" \
  -v "$LEAN_VOLUME:/lean-work:ro" \
  "${linux_mount[@]}" \
  "${docker_env[@]}" \
  -w /repo/tests/linux_nlattr \
  "$IMAGE" \
  "$INNER" /linux

if [[ "$CHECK" == "size_report" ]]; then
  REPORT="${LEAN_NLATTR_SIZE_REPORT_FILE:-$ROOT/build/lean_nlattr/size_report.txt}"
  REPORT_DIR="$(dirname "$REPORT")"
  REPORT_BASE="$(basename "$REPORT")"
  mkdir -p "$REPORT_DIR"
  REPORT="$(cd "$REPORT_DIR" && pwd)/$REPORT_BASE"
  cp "$OUT_DIR/size_report.txt" "$REPORT"
  echo ">> report saved to $REPORT"
fi
