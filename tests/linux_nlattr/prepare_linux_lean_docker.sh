#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE="${LEAN_NLATTR_DOCKER_IMAGE:-lean-nlattr-ci:latest}"
LEAN_VOLUME="${LEAN_NLATTR_LEAN_VOLUME:-lean-nlattr-lean}"
LEAN_JOBS="${LEAN_NLATTR_LEAN_BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
PRESET="${LEAN_NLATTR_LEAN_CMAKE_PRESET:-release}"
BUILD_DIR="/lean-work/src/build/$PRESET"
LINUX_LEAN="$BUILD_DIR/stage1/bin/lean"
REBUILD="${LEAN_NLATTR_REBUILD_LEAN:-0}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or is not on PATH" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker is not running" >&2
  exit 1
fi

echo ">> building Docker image $IMAGE"
docker build -t "$IMAGE" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

docker volume create "$LEAN_VOLUME" >/dev/null

echo ">> preparing Linux Lean toolchain in Docker volume $LEAN_VOLUME"
docker run --rm \
  -v "$ROOT:/repo:ro" \
  -v "$LEAN_VOLUME:/lean-work" \
  -e "LEAN_NLATTR_LEAN_BUILD_JOBS=$LEAN_JOBS" \
  -e "LEAN_NLATTR_LEAN_CMAKE_PRESET=$PRESET" \
  -e "LEAN_NLATTR_REBUILD_LEAN=$REBUILD" \
  "$IMAGE" \
  bash -lc '
    set -euo pipefail

    preset="${LEAN_NLATTR_LEAN_CMAKE_PRESET}"
    build_dir="/lean-work/src/build/$preset"
    lean="$build_dir/stage1/bin/lean"
    jobs="${LEAN_NLATTR_LEAN_BUILD_JOBS}"
    rebuild="${LEAN_NLATTR_REBUILD_LEAN}"

    mkdir -p /lean-work/src
    rsync -a --delete \
      --exclude=/build \
      --exclude=/.git \
      --exclude=/.DS_Store \
      /repo/ /lean-work/src/

    cd /lean-work/src

    if [[ "$rebuild" == "1" || ! -x "$lean" ]]; then
      rm -rf \
        "$build_dir/stage0" \
        "$build_dir/stage0-prefix" \
        "$build_dir/stage1" \
        "$build_dir/stage1-prefix"

      cmake --preset "$preset" \
        -DLLVM=ON \
        -DLLVM_CONFIG=/usr/bin/llvm-config-19 \
        -DCMAKE_C_COMPILER=/usr/bin/clang-19 \
        -DCMAKE_CXX_COMPILER=/usr/bin/clang++-19 \
        -DCMAKE_AR=/usr/bin/llvm-ar-19 \
        -DCMAKE_RANLIB=/usr/bin/llvm-ranlib-19 \
        -DSTAGE0_CMAKE_C_COMPILER=/usr/bin/clang-19 \
        -DSTAGE0_CMAKE_CXX_COMPILER=/usr/bin/clang++-19 \
        -DSTAGE0_CMAKE_AR=/usr/bin/llvm-ar-19 \
        -DSTAGE0_CMAKE_RANLIB=/usr/bin/llvm-ranlib-19 \
        -DSTAGE1_CMAKE_C_COMPILER=/usr/bin/clang-19 \
        -DSTAGE1_CMAKE_CXX_COMPILER=/usr/bin/clang++-19 \
        -DSTAGE1_CMAKE_AR=/usr/bin/llvm-ar-19 \
        -DSTAGE1_CMAKE_RANLIB=/usr/bin/llvm-ranlib-19
      cmake --build "$build_dir" --target stage1 --parallel "$jobs"
    fi

    "$lean" --version
    "$lean" --help | grep -q -- "--target=triple"
  '

echo "Linux Lean is available inside Docker at $LINUX_LEAN"
