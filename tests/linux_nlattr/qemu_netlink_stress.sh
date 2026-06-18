#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/linux" >&2
  exit 2
fi

LINUX="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${ARCH:-riscv}"
LLVM="${LLVM:-1}"
MAKE_JOBS="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
QEMU="${QEMU:-qemu-system-riscv64}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"
STRESS_ITERS="${LEAN_NLATTR_STRESS_ITERS:-32}"

if [[ "$ARCH" != "riscv" ]]; then
  echo "qemu_netlink_stress.sh currently supports ARCH=riscv only" >&2
  exit 2
fi

for tool in "$QEMU" cpio clang timeout; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ ! -d "$LINUX/lib" || ! -f "$LINUX/Makefile" ]]; then
  echo "$LINUX does not look like a Linux source tree" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

"$SCRIPT_DIR/install_replacement.sh" "$LINUX"

if [[ ! -f "$LINUX/.config" ]]; then
  make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" defconfig
fi

if [[ -x "$LINUX/scripts/config" ]]; then
  "$LINUX/scripts/config" --file "$LINUX/.config" \
    -e BLK_DEV_INITRD \
    -e PRINTK \
    -e NET \
    -e GENERIC_NETLINK \
    -e SOCK_DIAG \
    -e UNIX_DIAG \
    -e INET_DIAG \
    -e INET_TCP_DIAG \
    -e INET_UDP_DIAG \
    -e PACKET \
    -e PACKET_DIAG \
    -e INET \
    -e UNIX
fi

make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" olddefconfig
make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" -j"$MAKE_JOBS" Image

KERNEL_IMAGE="$LINUX/arch/riscv/boot/Image"
if [[ ! -f "$KERNEL_IMAGE" ]]; then
  echo "missing built kernel image: $KERNEL_IMAGE" >&2
  exit 1
fi

bash "$SCRIPT_DIR/audit_replacement.sh" "$LINUX" linked

ROOTFS="$WORK/initramfs"
mkdir -p "$ROOTFS/dev"
mknod -m 600 "$ROOTFS/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$ROOTFS/dev/null" c 1 3 2>/dev/null || true

clang --target=riscv64-unknown-linux-gnu -fuse-ld=lld \
  -march=rv64imac -mabi=lp64 \
  -nostdlib -static -ffreestanding -fno-builtin -O2 \
  "-DLEAN_NLATTR_STRESS_ITERS=$STRESS_ITERS" \
  -Wl,-e,_start -Wl,--build-id=none \
  "$SCRIPT_DIR/lean_nlattr_netlink_stress_init.c" -o "$ROOTFS/init"

INITRAMFS="$WORK/initramfs.cpio"
(cd "$ROOTFS" && find . -print0 | cpio --null -ov --format=newc) > "$INITRAMFS" 2>/dev/null

LOG="$WORK/qemu.log"
set +e
timeout "$QEMU_TIMEOUT" "$QEMU" \
  -machine virt \
  -cpu rv64 \
  -m 512M \
  -smp 2 \
  -nographic \
  -no-reboot \
  -kernel "$KERNEL_IMAGE" \
  -initrd "$INITRAMFS" \
  -append "console=ttyS0 earlycon=sbi loglevel=7 rdinit=/init panic=-1" \
  > "$LOG" 2>&1
QEMU_STATUS=$?
set -e

if grep -q 'LEAN_NLATTR_STRESS_FAIL' "$LOG"; then
  echo "FAIL: netlink stress workload returned an unexpected result" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

REQUIRED_STRESS_MARKERS=(
  'LEAN_NLATTR_STRESS_BEGIN' \
  'LEAN_NLATTR_STRESS_OK' \
  'LEAN_NLATTR_STRESS_DONE'
)

REQUIRED_STRESS_MARKERS+=(
  'lean-nlattr: coverage hook.skb_tailroom'
  'lean-nlattr: coverage hook.skb_put_raw'
)

for marker in "${REQUIRED_STRESS_MARKERS[@]}"; do
  if ! grep -q "$marker" "$LOG"; then
    echo "FAIL: missing stress marker: $marker" >&2
    tail -220 "$LOG" >&2
    exit 1
  fi
done

if grep -q 'Kernel panic' "$LOG"; then
  echo "FAIL: kernel panic during stress boot" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

if [[ "$QEMU_STATUS" -ne 0 && "$QEMU_STATUS" -ne 124 ]]; then
  echo "FAIL: QEMU exited with status $QEMU_STATUS" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

echo "PASS: netlink-stress nlattr netlink stress"
