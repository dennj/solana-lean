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
BENCH_ITERS="${LEAN_NLATTR_BENCH_ITERS:-20000}"
BENCH_ROUNDS="${LEAN_NLATTR_BENCH_ROUNDS:-7}"

if [[ "$ARCH" != "riscv" ]]; then
  echo "kernel_benchmark.sh currently supports ARCH=riscv only" >&2
  exit 2
fi

case "$BENCH_ITERS" in
  ''|*[!0-9]*)
    echo "LEAN_NLATTR_BENCH_ITERS must be a positive integer" >&2
    exit 2
    ;;
esac
case "$BENCH_ROUNDS" in
  ''|*[!0-9]*)
    echo "LEAN_NLATTR_BENCH_ROUNDS must be a positive integer" >&2
    exit 2
    ;;
esac
if [[ "$BENCH_ITERS" -lt 1 || "$BENCH_ROUNDS" -lt 1 ]]; then
  echo "LEAN_NLATTR_BENCH_ITERS and LEAN_NLATTR_BENCH_ROUNDS must be positive" >&2
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

generate_original_include() {
  local source="$1" out="$2"

  perl -0pe '
    s/^[\t ]*EXPORT_SYMBOL(?:_GPL)?\([^;]+;\n//mg;
    s/\b__nla_validate\b/lean_original___nla_validate/g;
    s/\bnla_get_range_unsigned\b/lean_original_nla_get_range_unsigned/g;
    s/\bnla_get_range_signed\b/lean_original_nla_get_range_signed/g;
    s/\bnla_policy_len\b/lean_original_nla_policy_len/g;
    s/\b__nla_parse\b/lean_original___nla_parse/g;
    s/\bnla_find\b/lean_original_nla_find/g;
    s/\bnla_strscpy\b/lean_original_nla_strscpy/g;
    s/\bnla_strdup\b/lean_original_nla_strdup/g;
    s/\bnla_memcpy\b/lean_original_nla_memcpy/g;
    s/\bnla_memcmp\b/lean_original_nla_memcmp/g;
    s/\bnla_strcmp\b/lean_original_nla_strcmp/g;
    s/\b__nla_reserve_64bit\b/lean_original___nla_reserve_64bit/g;
    s/\b__nla_reserve_nohdr\b/lean_original___nla_reserve_nohdr/g;
    s/\b__nla_reserve\b/lean_original___nla_reserve/g;
    s/\bnla_reserve_64bit\b/lean_original_nla_reserve_64bit/g;
    s/\bnla_reserve_nohdr\b/lean_original_nla_reserve_nohdr/g;
    s/\bnla_reserve\b/lean_original_nla_reserve/g;
    s/\b__nla_put_64bit\b/lean_original___nla_put_64bit/g;
    s/\b__nla_put_nohdr\b/lean_original___nla_put_nohdr/g;
    s/\b__nla_put\b/lean_original___nla_put/g;
    s/\bnla_put_64bit\b/lean_original_nla_put_64bit/g;
    s/\bnla_put_nohdr\b/lean_original_nla_put_nohdr/g;
    s/\bnla_put\b/lean_original_nla_put/g;
    s/\bnla_append\b/lean_original_nla_append/g;
    s/^void (lean_original_nla_get_range_unsigned\()/static __maybe_unused void $1/mg;
    s/^void (lean_original_nla_get_range_signed\()/static __maybe_unused void $1/mg;
    s/^int (lean_original___nla_validate\()/static __maybe_unused int $1/mg;
    s/^int\n(lean_original_nla_policy_len\()/static __maybe_unused int\n$1/mg;
    s/^int (lean_original___nla_parse\()/static __maybe_unused int $1/mg;
    s/^struct nlattr \*(lean_original_nla_find\()/static __maybe_unused struct nlattr *$1/mg;
    s/^ssize_t (lean_original_nla_strscpy\()/static __maybe_unused ssize_t $1/mg;
    s/^char \*(lean_original_nla_strdup\()/static __maybe_unused char *$1/mg;
    s/^int (lean_original_nla_memcpy\()/static __maybe_unused int $1/mg;
    s/^int (lean_original_nla_memcmp\()/static __maybe_unused int $1/mg;
    s/^int (lean_original_nla_strcmp\()/static __maybe_unused int $1/mg;
    s/^struct nlattr \*(lean_original___nla_reserve\()/static __maybe_unused struct nlattr *$1/mg;
    s/^struct nlattr \*(lean_original___nla_reserve_64bit\()/static __maybe_unused struct nlattr *$1/mg;
    s/^void \*(lean_original___nla_reserve_nohdr\()/static __maybe_unused void *$1/mg;
    s/^struct nlattr \*(lean_original_nla_reserve\()/static __maybe_unused struct nlattr *$1/mg;
    s/^struct nlattr \*(lean_original_nla_reserve_64bit\()/static __maybe_unused struct nlattr *$1/mg;
    s/^void \*(lean_original_nla_reserve_nohdr\()/static __maybe_unused void *$1/mg;
    s/^void (lean_original___nla_put\()/static __maybe_unused void $1/mg;
    s/^void (lean_original___nla_put_64bit\()/static __maybe_unused void $1/mg;
    s/^void (lean_original___nla_put_nohdr\()/static __maybe_unused void $1/mg;
    s/^int (lean_original_nla_put\()/static __maybe_unused int $1/mg;
    s/^int (lean_original_nla_put_64bit\()/static __maybe_unused int $1/mg;
    s/^int (lean_original_nla_put_nohdr\()/static __maybe_unused int $1/mg;
    s/^int (lean_original_nla_append\()/static __maybe_unused int $1/mg;
  ' "$source" > "$out"
}

remove_prefix_lines() {
  local prefix="$1" file="$2" tmp

  if grep -Fq "$prefix" "$file"; then
    tmp="$(mktemp)"
    awk -v prefix="$prefix" 'index($0, prefix) != 1 { print }' "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
}

source_is_not_upstream() {
  grep -Eq 'lean_public___nla_validate|lean_nlattr_core|Lean nlattr replacement' "$1"
}

recover_original_source() {
  if git -C "$LINUX" cat-file -e HEAD:lib/nlattr.c 2>/dev/null; then
    git -C "$LINUX" show HEAD:lib/nlattr.c > "$ORIGINAL_SOURCE"
    return 0
  fi

  echo "cannot recover upstream lib/nlattr.c for benchmark" >&2
  exit 1
}

ORIGINAL_SOURCE="$LINUX/lib/nlattr_c_original.c"
if [[ ! -f "$ORIGINAL_SOURCE" ]]; then
  if source_is_not_upstream "$LINUX/lib/nlattr.c"; then
    recover_original_source
  else
    cp "$LINUX/lib/nlattr.c" "$ORIGINAL_SOURCE"
  fi
elif source_is_not_upstream "$ORIGINAL_SOURCE"; then
  recover_original_source
fi

generate_original_include "$ORIGINAL_SOURCE" "$WORK/lean_nlattr_benchmark_original.c"
"$SCRIPT_DIR/install_replacement.sh" "$LINUX"

cp "$SCRIPT_DIR/lean_nlattr_benchmark.c" "$LINUX/lib/lean_nlattr_benchmark.c"
cp "$WORK/lean_nlattr_benchmark_original.c" "$LINUX/lib/lean_nlattr_benchmark_original.c"
MAKE_DOLLAR='$'
BENCHMARK_OBJ_LINE="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_benchmark.o"
BENCHMARK_HOOK_CFLAGS_LINE='CFLAGS_lean_nlattr_hook.o += -DLEAN_NLATTR_TRACE_COUNTS'
BENCHMARK_ITERS_CFLAGS_PREFIX='CFLAGS_lean_nlattr_benchmark.o += -DLEAN_NLATTR_BENCH_ITERS='
BENCHMARK_ROUNDS_CFLAGS_PREFIX='CFLAGS_lean_nlattr_benchmark.o += -DLEAN_NLATTR_BENCH_ROUNDS='
BENCHMARK_ITERS_CFLAGS_LINE="${BENCHMARK_ITERS_CFLAGS_PREFIX}${BENCH_ITERS}"
BENCHMARK_ROUNDS_CFLAGS_LINE="${BENCHMARK_ROUNDS_CFLAGS_PREFIX}${BENCH_ROUNDS}"
if ! grep -Fq "$BENCHMARK_OBJ_LINE" "$LINUX/lib/Makefile"; then
  printf '\n%s\n' "$BENCHMARK_OBJ_LINE" >> "$LINUX/lib/Makefile"
fi
if ! grep -Fq "$BENCHMARK_HOOK_CFLAGS_LINE" "$LINUX/lib/Makefile"; then
  printf '%s\n' "$BENCHMARK_HOOK_CFLAGS_LINE" >> "$LINUX/lib/Makefile"
fi
remove_prefix_lines "$BENCHMARK_ITERS_CFLAGS_PREFIX" "$LINUX/lib/Makefile"
remove_prefix_lines "$BENCHMARK_ROUNDS_CFLAGS_PREFIX" "$LINUX/lib/Makefile"
printf '%s\n' "$BENCHMARK_ITERS_CFLAGS_LINE" >> "$LINUX/lib/Makefile"
printf '%s\n' "$BENCHMARK_ROUNDS_CFLAGS_LINE" >> "$LINUX/lib/Makefile"

if [[ ! -f "$LINUX/.config" ]]; then
  make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" defconfig
fi

if [[ -x "$LINUX/scripts/config" ]]; then
  "$LINUX/scripts/config" --file "$LINUX/.config" \
    -e BLK_DEV_INITRD \
    -e PRINTK \
    -e NET \
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

ROOTFS="$WORK/initramfs"
mkdir -p "$ROOTFS/dev"
mknod -m 600 "$ROOTFS/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$ROOTFS/dev/null" c 1 3 2>/dev/null || true

cat > "$WORK/init.c" <<'EOF'
typedef unsigned long usize;

#define SYS_write 64
#define SYS_exit 93
#define SYS_reboot 142

#define LINUX_REBOOT_MAGIC1 0xfee1dead
#define LINUX_REBOOT_MAGIC2 672274793
#define LINUX_REBOOT_CMD_POWER_OFF 0x4321fedc

static long sys1(long n, long x0)
{
	register long a7 asm("a7") = n;
	register long a0 asm("a0") = x0;
	asm volatile ("ecall" : "+r"(a0) : "r"(a7) : "memory");
	return a0;
}

static long sys3(long n, long x0, long x1, long x2)
{
	register long a7 asm("a7") = n;
	register long a0 asm("a0") = x0;
	register long a1 asm("a1") = x1;
	register long a2 asm("a2") = x2;
	asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a7) : "memory");
	return a0;
}

static long sys4(long n, long x0, long x1, long x2, long x3)
{
	register long a7 asm("a7") = n;
	register long a0 asm("a0") = x0;
	register long a1 asm("a1") = x1;
	register long a2 asm("a2") = x2;
	register long a3 asm("a3") = x3;
	asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a3), "r"(a7) : "memory");
	return a0;
}

static usize cstrlen(const char *s)
{
	usize n = 0;
	while (s[n])
		n++;
	return n;
}

static void puts(const char *s)
{
	sys3(SYS_write, 1, (long)s, (long)cstrlen(s));
}

__attribute__((noreturn)) void _start(void)
{
	puts("LEAN_NLATTR_BENCH_INIT_DONE\n");
	sys4(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
	     LINUX_REBOOT_CMD_POWER_OFF, 0);
	sys1(SYS_exit, 0);
	for (;;)
		sys1(SYS_exit, 0);
}
EOF

clang --target=riscv64-unknown-linux-gnu -fuse-ld=lld \
  -march=rv64imac -mabi=lp64 \
  -nostdlib -static -ffreestanding -fno-builtin -O2 \
  -Wl,-e,_start -Wl,--build-id=none "$WORK/init.c" -o "$ROOTFS/init"

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

if grep -a -q 'lean-nlattr: benchmark FAIL' "$LOG"; then
  echo "FAIL: kernel nlattr benchmark failed semantic check" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

for marker in \
  'lean-nlattr: benchmark parse ' \
  'lean-nlattr: benchmark validate ' \
  'lean-nlattr: benchmark helpers ' \
  'lean-nlattr: benchmark helpers-large ' \
  'lean-nlattr: benchmark PASS'; do
  if ! grep -a -q "$marker" "$LOG"; then
    echo "FAIL: missing benchmark marker: $marker" >&2
    tail -220 "$LOG" >&2
    exit 1
  fi
done

for marker in \
  'lean-nlattr: counts parse-one ' \
  'lean-nlattr: counts validate-one ' \
  'lean-nlattr: counts helpers-one '; do
  if ! grep -a -q "$marker" "$LOG"; then
    echo "FAIL: missing benchmark count marker: $marker" >&2
    tail -220 "$LOG" >&2
    exit 1
  fi
done

if grep -a -q 'Kernel panic' "$LOG"; then
  echo "FAIL: kernel panic during benchmark boot" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

if ! grep -a -q 'LEAN_NLATTR_BENCH_INIT_DONE' "$LOG"; then
  echo "FAIL: benchmark boot did not reach init completion marker; status=$QEMU_STATUS" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

if [[ "$QEMU_STATUS" -ne 0 && "$QEMU_STATUS" -ne 124 ]]; then
  echo "FAIL: QEMU exited with status $QEMU_STATUS" >&2
  tail -220 "$LOG" >&2
  exit 1
fi

grep -aE 'lean-nlattr: (counts|benchmark)' "$LOG"
echo "PASS: kernel-benchmark nlattr kernel benchmark"
