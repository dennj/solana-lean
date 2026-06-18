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

if [[ "$ARCH" != "riscv" ]]; then
  echo "qemu_boot_smoke.sh currently supports ARCH=riscv only" >&2
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

cp "$SCRIPT_DIR/lean_nlattr_selftest.c" "$LINUX/lib/lean_nlattr_selftest.c"
MAKE_DOLLAR='$'
SELFTEST_OBJ_LINE="obj-${MAKE_DOLLAR}(CONFIG_NLATTR) += lean_nlattr_selftest.o"
if ! grep -Fq "$SELFTEST_OBJ_LINE" "$LINUX/lib/Makefile"; then
  printf '\n%s\n' "$SELFTEST_OBJ_LINE" >> "$LINUX/lib/Makefile"
fi

if [[ ! -f "$LINUX/.config" ]]; then
  make -C "$LINUX" ARCH="$ARCH" LLVM="$LLVM" defconfig
fi

if [[ -x "$LINUX/scripts/config" ]]; then
  "$LINUX/scripts/config" --file "$LINUX/.config" \
    -e BLK_DEV_INITRD \
    -e PRINTK \
    -e NET \
    -e GENERIC_NETLINK \
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
mkdir -p "$ROOTFS/bin" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/tmp"

mknod -m 600 "$ROOTFS/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$ROOTFS/dev/null" c 1 3 2>/dev/null || true

cat > "$WORK/init.c" <<'EOF'
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long usize;

#define AF_NETLINK 16
#define SOCK_RAW 3
#define NETLINK_ROUTE 0
#define NETLINK_GENERIC 16
#define GENL_ID_CTRL 0x10
#define CTRL_CMD_GETFAMILY 3
#define CTRL_ATTR_FAMILY_NAME 2
#define RTM_GETLINK 18
#define RTM_GETADDR 22
#define RTM_GETROUTE 26
#define RTM_GETNEIGH 30
#define NLM_F_REQUEST 0x1
#define NLM_F_ACK 0x4
#define NLM_F_ROOT 0x100
#define NLM_F_MATCH 0x200
#define NLM_F_DUMP (NLM_F_ROOT | NLM_F_MATCH)
#define NLMSG_ERROR 0x2

#define NLA_HDRLEN 4

#define SYS_write 64
#define SYS_close 57
#define SYS_exit 93
#define SYS_reboot 142
#define SYS_socket 198
#define SYS_bind 200
#define SYS_sendto 206
#define SYS_recvfrom 207

#define LINUX_REBOOT_MAGIC1 0xfee1dead
#define LINUX_REBOOT_MAGIC2 672274793
#define LINUX_REBOOT_CMD_POWER_OFF 0x4321fedc

struct sockaddr_nl {
	u16 nl_family;
	u16 nl_pad;
	u32 nl_pid;
	u32 nl_groups;
};

struct nlmsghdr {
	u32 nlmsg_len;
	u16 nlmsg_type;
	u16 nlmsg_flags;
	u32 nlmsg_seq;
	u32 nlmsg_pid;
};

struct ifinfomsg {
	u8 ifi_family;
	u8 __ifi_pad;
	u16 ifi_type;
	int ifi_index;
	u32 ifi_flags;
	u32 ifi_change;
};

struct ifaddrmsg {
	u8 ifa_family;
	u8 ifa_prefixlen;
	u8 ifa_flags;
	u8 ifa_scope;
	u32 ifa_index;
};

struct rtmsg {
	u8 rtm_family;
	u8 rtm_dst_len;
	u8 rtm_src_len;
	u8 rtm_tos;
	u8 rtm_table;
	u8 rtm_protocol;
	u8 rtm_scope;
	u8 rtm_type;
	u32 rtm_flags;
};

struct ndmsg {
	u8 ndm_family;
	u8 ndm_pad1;
	u16 ndm_pad2;
	int ndm_ifindex;
	u16 ndm_state;
	u8 ndm_flags;
	u8 ndm_type;
};

struct genlmsghdr {
	u8 cmd;
	u8 version;
	u16 reserved;
};

struct nlattr {
	u16 nla_len;
	u16 nla_type;
};

static long sys0(long n)
{
	register long a7 asm("a7") = n;
	register long a0 asm("a0");
	asm volatile ("ecall" : "=r"(a0) : "r"(a7) : "memory");
	return a0;
}

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

static long sys6(long n, long x0, long x1, long x2, long x3, long x4, long x5)
{
	register long a7 asm("a7") = n;
	register long a0 asm("a0") = x0;
	register long a1 asm("a1") = x1;
	register long a2 asm("a2") = x2;
	register long a3 asm("a3") = x3;
	register long a4 asm("a4") = x4;
	register long a5 asm("a5") = x5;
	asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a7) : "memory");
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

static u32 align4(u32 n)
{
	return (n + 3u) & ~3u;
}

static void zero_bytes(void *ptr, usize count)
{
	u8 *p = ptr;
	usize i;

	for (i = 0; i < count; i++)
		p[i] = 0;
}

static void copy_bytes(void *dst, const void *src, usize count)
{
	u8 *d = dst;
	const u8 *s = src;
	usize i;

	for (i = 0; i < count; i++)
		d[i] = s[i];
}

static void putint(long v)
{
	char buf[32];
	int i = 30;
	unsigned long n;

	buf[31] = '\0';
	if (v < 0) {
		puts("-");
		n = (unsigned long)-v;
	} else {
		n = (unsigned long)v;
	}

	do {
		buf[i--] = (char)('0' + (n % 10));
		n /= 10;
	} while (n);
	puts(&buf[i + 1]);
}

static long netlink_recv_status(long fd)
{
	char buf[4096];
	long ret;

	ret = sys6(SYS_recvfrom, fd, (long)buf, sizeof(buf), 0, 0, 0);
	if (ret < 0)
		return ret;

	if (ret >= (long)(sizeof(struct nlmsghdr) + sizeof(int))) {
		struct nlmsghdr *nlh = (struct nlmsghdr *)buf;

		if (nlh->nlmsg_type == NLMSG_ERROR)
			return *(int *)(buf + sizeof(struct nlmsghdr));
	}

	return ret;
}

static long netlink_request(int protocol, const void *msg, u32 len)
{
	struct sockaddr_nl addr = { AF_NETLINK, 0, 0, 0 };
	long fd;
	long ret;

	fd = sys3(SYS_socket, AF_NETLINK, SOCK_RAW, protocol);
	if (fd < 0)
		return fd;

	ret = sys3(SYS_bind, fd, (long)&addr, sizeof(addr));
	if (ret < 0) {
		sys1(SYS_close, fd);
		return ret;
	}

	ret = sys6(SYS_sendto, fd, (long)msg, len, 0, (long)&addr, sizeof(addr));
	if (ret < 0) {
		sys1(SYS_close, fd);
		return ret;
	}

	ret = netlink_recv_status(fd);
	sys1(SYS_close, fd);
	return ret;
}

static long route_dump(u16 type, u32 body_len)
{
	struct {
		struct nlmsghdr nlh;
		u8 body[32];
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + body_len;
	req.nlh.nlmsg_type = type;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = type;
	req.nlh.nlmsg_pid = 0;

	return netlink_request(NETLINK_ROUTE, &req, req.nlh.nlmsg_len);
}

static long genl_getfamily_nlctrl(void)
{
	const char name[] = "nlctrl";
	struct {
		struct nlmsghdr nlh;
		struct genlmsghdr genl;
		struct nlattr family_name;
		char value[8];
	} req;
	u32 payload_len = sizeof(name);
	u32 attr_len = NLA_HDRLEN + payload_len;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + sizeof(struct genlmsghdr) +
			    align4(attr_len);
	req.nlh.nlmsg_type = GENL_ID_CTRL;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = 100;
	req.nlh.nlmsg_pid = 0;
	req.genl.cmd = CTRL_CMD_GETFAMILY;
	req.genl.version = 2;
	req.family_name.nla_len = attr_len;
	req.family_name.nla_type = CTRL_ATTR_FAMILY_NAME;
	copy_bytes(req.value, name, payload_len);

	return netlink_request(NETLINK_GENERIC, &req, req.nlh.nlmsg_len);
}

static int report_workload(const char *name, long ret)
{
	puts(name);
	if (ret < 0) {
		puts("_FAIL ");
		putint(ret);
		puts("\n");
		return 1;
	}
	puts("_OK ");
	putint(ret);
	puts("\n");
	return 0;
}

__attribute__((noreturn)) void _start(void)
{
	long ret;
	int failed = 0;

	puts("LEAN_NLATTR_BOOT_BEGIN\n");
	puts("LEAN_NLATTR_NETLINK_BEGIN\n");
	ret = route_dump(RTM_GETLINK, sizeof(struct ifinfomsg));
	failed |= report_workload("LEAN_NLATTR_RTM_GETLINK", ret);
	ret = route_dump(RTM_GETADDR, sizeof(struct ifaddrmsg));
	failed |= report_workload("LEAN_NLATTR_RTM_GETADDR", ret);
	ret = route_dump(RTM_GETROUTE, sizeof(struct rtmsg));
	failed |= report_workload("LEAN_NLATTR_RTM_GETROUTE", ret);
	ret = route_dump(RTM_GETNEIGH, sizeof(struct ndmsg));
	failed |= report_workload("LEAN_NLATTR_RTM_GETNEIGH", ret);
	ret = genl_getfamily_nlctrl();
	failed |= report_workload("LEAN_NLATTR_GENL_GETFAMILY", ret);
	puts("LEAN_NLATTR_NETLINK_DONE\n");
	if (failed)
		puts("LEAN_NLATTR_WORKLOAD_FAIL\n");
	else
		puts("LEAN_NLATTR_WORKLOAD_OK\n");
	puts("LEAN_NLATTR_BOOT_DONE\n");

	sys4(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
	     LINUX_REBOOT_CMD_POWER_OFF, 0);
	sys1(SYS_exit, 0);
	for (;;)
		sys0(SYS_exit);
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

if grep -q 'LEAN_NLATTR_WORKLOAD_FAIL' "$LOG"; then
  echo "FAIL: QEMU nlattr workload returned an error" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if grep -q 'lean-nlattr: selftest FAIL' "$LOG"; then
  echo "FAIL: kernel nlattr selftest failed" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if ! grep -q 'lean-nlattr: selftest PASS helpers' "$LOG"; then
  echo "FAIL: kernel nlattr selftest did not run" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if ! grep -q 'lean-nlattr: selftest PASS policy-values' "$LOG"; then
  echo "FAIL: kernel nlattr policy-value selftest did not run" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if ! grep -q 'lean-nlattr: selftest PASS nested' "$LOG"; then
  echo "FAIL: kernel nlattr nested-policy selftest did not run" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if ! grep -q 'lean-nlattr: selftest PASS edges' "$LOG"; then
  echo "FAIL: kernel nlattr edge-case selftest did not run" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

REQUIRED_COVERAGE_MARKERS=(
  'hook.policy_validate_fn'
)
for marker in "${REQUIRED_COVERAGE_MARKERS[@]}"; do
  if ! grep -q "lean-nlattr: coverage $marker" "$LOG"; then
    echo "FAIL: missing nlattr coverage marker: $marker" >&2
    tail -200 "$LOG" >&2
    exit 1
  fi
done

if grep -q 'Kernel panic' "$LOG"; then
  echo "FAIL: kernel panic during QEMU boot" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if ! grep -q 'LEAN_NLATTR_BOOT_DONE' "$LOG"; then
  echo "FAIL: QEMU boot did not reach init completion marker; status=$QEMU_STATUS" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

if [[ "$QEMU_STATUS" -ne 0 && "$QEMU_STATUS" -ne 124 ]]; then
  echo "FAIL: QEMU exited with status $QEMU_STATUS" >&2
  tail -200 "$LOG" >&2
  exit 1
fi

echo "PASS: Lean nlattr replacement kernel boots"
