typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long usize;

#ifndef LEAN_NLATTR_STRESS_ITERS
#define LEAN_NLATTR_STRESS_ITERS 32
#endif

#define AF_NETLINK 16
#define AF_UNIX 1
#define AF_INET 2
#define AF_PACKET 17
#define SOCK_STREAM 1
#define SOCK_DGRAM 2
#define SOCK_RAW 3
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17
#define NETLINK_ROUTE 0
#define NETLINK_SOCK_DIAG 4
#define NETLINK_GENERIC 16
#define GENL_ID_CTRL 0x10
#define CTRL_CMD_GETFAMILY 3
#define CTRL_ATTR_FAMILY_ID 1
#define CTRL_ATTR_FAMILY_NAME 2
#define SOCK_DIAG_BY_FAMILY 20
#define RTM_GETLINK 18
#define RTM_GETADDR 22
#define RTM_GETROUTE 26
#define RTM_GETNEIGH 30
#define RTM_GETSTATS 94
#define IFLA_ADDRESS 1
#define IFLA_IFNAME 3
#define IFLA_EXT_MASK 29
#define IFLA_GSO_MAX_SIZE 41
#define IFLA_XDP 43
#define IFLA_NEW_IFINDEX 49
#define IFLA_PERM_ADDRESS 54
#define IFLA_STATS_LINK_64 1
#define IFLA_STATS_LINK_OFFLOAD_XSTATS 4
#define IFLA_STATS_GET_FILTERS 1
#define IFLA_OFFLOAD_XSTATS_HW_S_INFO 2
#define NLM_F_REQUEST 0x1
#define NLM_F_ACK 0x4
#define NLM_F_ROOT 0x100
#define NLM_F_MATCH 0x200
#define NLM_F_DUMP (NLM_F_ROOT | NLM_F_MATCH)
#define NLMSG_ERROR 0x2

#define NLA_HDRLEN 4
#define TCPF_ALL 0xffffffffu
#define UDIAG_SHOW_NAME 0x00000001u
#define UDIAG_SHOW_PEER 0x00000002u
#define UDIAG_SHOW_RQLEN 0x00000004u
#define UDIAG_SHOW_MEMINFO 0x00000008u
#define PDIAG_SHOW_INFO 0x00000001u
#define PDIAG_SHOW_MEMINFO 0x00000010u

#define SYS_write 64
#define SYS_close 57
#define SYS_exit 93
#define SYS_reboot 142
#define SYS_socket 198
#define SYS_socketpair 199
#define SYS_bind 200
#define SYS_listen 201
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

struct sockaddr_in {
	u16 sin_family;
	u16 sin_port;
	u32 sin_addr;
	u8 sin_zero[8];
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

struct if_stats_msg {
	u8 family;
	u8 pad1;
	u16 pad2;
	u32 ifindex;
	u32 filter_mask;
};

struct genlmsghdr {
	u8 cmd;
	u8 version;
	u16 reserved;
};

struct unix_diag_req {
	u8 sdiag_family;
	u8 sdiag_protocol;
	u16 pad;
	u32 udiag_states;
	u32 udiag_ino;
	u32 udiag_show;
	u32 udiag_cookie[2];
};

struct inet_diag_sockid {
	u16 idiag_sport;
	u16 idiag_dport;
	u32 idiag_src[4];
	u32 idiag_dst[4];
	u32 idiag_if;
	u32 idiag_cookie[2];
};

struct inet_diag_req_v2 {
	u8 sdiag_family;
	u8 sdiag_protocol;
	u8 idiag_ext;
	u8 pad;
	u32 idiag_states;
	struct inet_diag_sockid id;
};

struct packet_diag_req {
	u8 sdiag_family;
	u8 sdiag_protocol;
	u16 pad;
	u32 pdiag_ino;
	u32 pdiag_show;
	u32 pdiag_cookie[2];
};

struct nlattr {
	u16 nla_len;
	u16 nla_type;
};

struct live_diag_sockets {
	int unix_pair[2];
	long tcp_listener;
	long udp_socket;
	long packet_socket;
};

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

static void init_live_diag_sockets(struct live_diag_sockets *s)
{
	s->unix_pair[0] = -1;
	s->unix_pair[1] = -1;
	s->tcp_listener = -1;
	s->udp_socket = -1;
	s->packet_socket = -1;
}

static void close_live_diag_sockets(struct live_diag_sockets *s)
{
	if (s->unix_pair[0] >= 0)
		sys1(SYS_close, s->unix_pair[0]);
	if (s->unix_pair[1] >= 0)
		sys1(SYS_close, s->unix_pair[1]);
	if (s->tcp_listener >= 0)
		sys1(SYS_close, s->tcp_listener);
	if (s->udp_socket >= 0)
		sys1(SYS_close, s->udp_socket);
	if (s->packet_socket >= 0)
		sys1(SYS_close, s->packet_socket);
	init_live_diag_sockets(s);
}

static long bind_inet_any(long fd)
{
	struct sockaddr_in addr;

	zero_bytes(&addr, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = 0;
	addr.sin_addr = 0;

	return sys3(SYS_bind, fd, (long)&addr, sizeof(addr));
}

static long open_live_diag_sockets(struct live_diag_sockets *s)
{
	long ret;

	init_live_diag_sockets(s);

	ret = sys4(SYS_socketpair, AF_UNIX, SOCK_STREAM, 0,
		   (long)s->unix_pair);
	if (ret < 0)
		return ret;

	s->tcp_listener = sys3(SYS_socket, AF_INET, SOCK_STREAM, 0);
	if (s->tcp_listener < 0) {
		ret = s->tcp_listener;
		close_live_diag_sockets(s);
		return ret;
	}
	ret = bind_inet_any(s->tcp_listener);
	if (ret < 0) {
		close_live_diag_sockets(s);
		return ret;
	}
	ret = sys3(SYS_listen, s->tcp_listener, 1, 0);
	if (ret < 0) {
		close_live_diag_sockets(s);
		return ret;
	}

	s->udp_socket = sys3(SYS_socket, AF_INET, SOCK_DGRAM, 0);
	if (s->udp_socket < 0) {
		ret = s->udp_socket;
		close_live_diag_sockets(s);
		return ret;
	}
	ret = bind_inet_any(s->udp_socket);
	if (ret < 0) {
		close_live_diag_sockets(s);
		return ret;
	}

	s->packet_socket = sys3(SYS_socket, AF_PACKET, SOCK_DGRAM, 0);
	if (s->packet_socket < 0) {
		ret = s->packet_socket;
		close_live_diag_sockets(s);
		return ret;
	}

	return 0;
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

static long route_dump(u16 type, u32 body_len, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		u8 body[32];
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + body_len;
	req.nlh.nlmsg_type = type;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;

	return netlink_request(NETLINK_ROUTE, &req, req.nlh.nlmsg_len);
}

static long route_getlink_attr(u16 attr_type, const void *payload,
			       u32 payload_len, int ifindex, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct ifinfomsg ifi;
		struct nlattr attr;
		u8 value[64];
	} req;
	u32 attr_len = NLA_HDRLEN + payload_len;

	if (payload_len > sizeof(req.value))
		return -22;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + sizeof(struct ifinfomsg) +
			    align4(attr_len);
	req.nlh.nlmsg_type = RTM_GETLINK;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.ifi.ifi_index = ifindex;
	req.attr.nla_len = attr_len;
	req.attr.nla_type = attr_type;
	if (payload)
		copy_bytes(req.value, payload, payload_len);

	return netlink_request(NETLINK_ROUTE, &req, req.nlh.nlmsg_len);
}

static long route_getlink_ifname(const char *name, u32 payload_len, u32 seq)
{
	return route_getlink_attr(IFLA_IFNAME, name, payload_len, 0, seq);
}

static long route_getlink_ext_mask(u32 mask, u32 payload_len, u32 seq)
{
	return route_getlink_attr(IFLA_EXT_MASK, &mask, payload_len, 1, seq);
}

static long route_getlink_address(u32 payload_len, u32 seq)
{
	u8 value[64];
	u32 i;

	zero_bytes(value, sizeof(value));
	for (i = 0; i < payload_len && i < sizeof(value); i++)
		value[i] = (u8)i;

	return route_getlink_attr(IFLA_ADDRESS, value, payload_len, 1, seq);
}

static long route_getlink_u32_attr(u16 attr_type, u32 value, u32 seq)
{
	return route_getlink_attr(attr_type, &value, sizeof(value), 1, seq);
}

static long route_getlink_nested_attr(u16 attr_type, u32 payload_len, u32 seq)
{
	struct nlattr child;

	zero_bytes(&child, sizeof(child));
	child.nla_len = NLA_HDRLEN;
	child.nla_type = 1;

	return route_getlink_attr(attr_type, &child, payload_len, 1, seq);
}

static long route_getstats_offload_xstats(u32 nested_mask, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct if_stats_msg ifsm;
		struct nlattr filters;
		struct nlattr offload_xstats;
		u32 mask;
	} req;
	u32 inner_len = NLA_HDRLEN + sizeof(u32);
	u32 filters_len = NLA_HDRLEN + align4(inner_len);

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + sizeof(struct if_stats_msg) +
			    align4(filters_len);
	req.nlh.nlmsg_type = RTM_GETSTATS;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.ifsm.ifindex = 1;
	req.ifsm.filter_mask = (1u << (IFLA_STATS_LINK_64 - 1)) |
				(1u << (IFLA_STATS_LINK_OFFLOAD_XSTATS - 1));
	req.filters.nla_len = filters_len;
	req.filters.nla_type = IFLA_STATS_GET_FILTERS;
	req.offload_xstats.nla_len = inner_len;
	req.offload_xstats.nla_type = IFLA_STATS_LINK_OFFLOAD_XSTATS;
	req.mask = nested_mask;

	return netlink_request(NETLINK_ROUTE, &req, req.nlh.nlmsg_len);
}

static long route_getstats_link64(u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct if_stats_msg ifsm;
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(req);
	req.nlh.nlmsg_type = RTM_GETSTATS;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.ifsm.ifindex = 1;
	req.ifsm.filter_mask = 1u << (IFLA_STATS_LINK_64 - 1);

	return netlink_request(NETLINK_ROUTE, &req, req.nlh.nlmsg_len);
}

static long genl_getfamily_name(const char *name, u32 payload_len, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct genlmsghdr genl;
		struct nlattr family_name;
		char value[64];
	} req;
	u32 attr_len = NLA_HDRLEN + payload_len;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + sizeof(struct genlmsghdr) +
			    align4(attr_len);
	req.nlh.nlmsg_type = GENL_ID_CTRL;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.genl.cmd = CTRL_CMD_GETFAMILY;
	req.genl.version = 2;
	req.family_name.nla_len = attr_len;
	req.family_name.nla_type = CTRL_ATTR_FAMILY_NAME;
	copy_bytes(req.value, name, payload_len);

	return netlink_request(NETLINK_GENERIC, &req, req.nlh.nlmsg_len);
}

static long genl_getfamily_id(u16 id, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct genlmsghdr genl;
		struct nlattr family_id;
		u16 value;
		u16 pad;
	} req;
	u32 payload_len = sizeof(id);
	u32 attr_len = NLA_HDRLEN + payload_len;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(struct nlmsghdr) + sizeof(struct genlmsghdr) +
			    align4(attr_len);
	req.nlh.nlmsg_type = GENL_ID_CTRL;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.genl.cmd = CTRL_CMD_GETFAMILY;
	req.genl.version = 2;
	req.family_id.nla_len = attr_len;
	req.family_id.nla_type = CTRL_ATTR_FAMILY_ID;
	req.value = id;

	return netlink_request(NETLINK_GENERIC, &req, req.nlh.nlmsg_len);
}

static long sock_diag_unix_dump(u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct unix_diag_req diag;
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(req);
	req.nlh.nlmsg_type = SOCK_DIAG_BY_FAMILY;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.diag.sdiag_family = AF_UNIX;
	req.diag.udiag_states = TCPF_ALL;
	req.diag.udiag_show = UDIAG_SHOW_NAME | UDIAG_SHOW_PEER |
			       UDIAG_SHOW_RQLEN | UDIAG_SHOW_MEMINFO;

	return netlink_request(NETLINK_SOCK_DIAG, &req, req.nlh.nlmsg_len);
}

static long sock_diag_inet_dump(u8 protocol, u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct inet_diag_req_v2 diag;
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(req);
	req.nlh.nlmsg_type = SOCK_DIAG_BY_FAMILY;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.diag.sdiag_family = AF_INET;
	req.diag.sdiag_protocol = protocol;
	req.diag.idiag_states = TCPF_ALL;

	return netlink_request(NETLINK_SOCK_DIAG, &req, req.nlh.nlmsg_len);
}

static long sock_diag_packet_dump(u32 seq)
{
	struct {
		struct nlmsghdr nlh;
		struct packet_diag_req diag;
	} req;

	zero_bytes(&req, sizeof(req));
	req.nlh.nlmsg_len = sizeof(req);
	req.nlh.nlmsg_type = SOCK_DIAG_BY_FAMILY;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = seq;
	req.nlh.nlmsg_pid = 0;
	req.diag.sdiag_family = AF_PACKET;
	req.diag.pdiag_show = PDIAG_SHOW_INFO | PDIAG_SHOW_MEMINFO;

	return netlink_request(NETLINK_SOCK_DIAG, &req, req.nlh.nlmsg_len);
}

static int expect_nonnegative(const char *name, long ret)
{
	if (ret >= 0)
		return 0;

	puts(name);
	puts("_FAIL ");
	putint(ret);
	puts("\n");
	return 1;
}

static int expect_negative(const char *name, long ret)
{
	if (ret < 0)
		return 0;

	puts(name);
	puts("_UNEXPECTED_OK ");
	putint(ret);
	puts("\n");
	return 1;
}

static int run_round(u32 round)
{
	const char nlctrl[] = "nlctrl";
	const char missing[] = "lean-nlattr-missing-family";
	int failed = 0;
	u32 seq = 1000 + round * 32;

	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK",
		route_dump(RTM_GETLINK, sizeof(struct ifinfomsg), seq + 1));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETADDR",
		route_dump(RTM_GETADDR, sizeof(struct ifaddrmsg), seq + 2));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETROUTE",
		route_dump(RTM_GETROUTE, sizeof(struct rtmsg), seq + 3));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETNEIGH",
		route_dump(RTM_GETNEIGH, sizeof(struct ndmsg), seq + 4));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_IFNAME",
		route_getlink_ifname("lo", 3, seq + 5));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_EXT_MASK",
		route_getlink_ext_mask(0, sizeof(u32), seq + 6));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_BAD_EXT_MASK",
		route_getlink_ext_mask(0, 2, seq + 7));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_ADDRESS",
		route_getlink_address(6, seq + 8));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_BAD_ADDRESS",
		route_getlink_address(33, seq + 9));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_GSO_MAX_SIZE",
		route_getlink_u32_attr(IFLA_GSO_MAX_SIZE, 4096, seq + 10));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_BAD_GSO_MAX_SIZE",
		route_getlink_u32_attr(IFLA_GSO_MAX_SIZE, 1, seq + 11));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_NEW_IFINDEX",
		route_getlink_u32_attr(IFLA_NEW_IFINDEX, 1, seq + 12));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_BAD_NEW_IFINDEX",
		route_getlink_u32_attr(IFLA_NEW_IFINDEX, 0, seq + 13));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETLINK_XDP_NESTED",
		route_getlink_nested_attr(IFLA_XDP, NLA_HDRLEN, seq + 14));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_BAD_XDP_NESTED",
		route_getlink_nested_attr(IFLA_XDP, 2, seq + 15));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETLINK_PERM_ADDRESS",
		route_getlink_attr(IFLA_PERM_ADDRESS, 0, 0, 1, seq + 16));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_RTM_GETSTATS_LINK64",
		route_getstats_link64(seq + 17));
	failed |= expect_negative("LEAN_NLATTR_STRESS_RTM_GETSTATS_BAD_FILTERS",
		route_getstats_offload_xstats(0x80000000u, seq + 18));

	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_GENL_NAME",
		genl_getfamily_name(nlctrl, (u32)cstrlen(nlctrl) + 1, seq + 19));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_GENL_ID",
		genl_getfamily_id(GENL_ID_CTRL, seq + 20));

	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_SOCK_DIAG_UNIX",
		sock_diag_unix_dump(seq + 21));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_SOCK_DIAG_TCP",
		sock_diag_inet_dump(IPPROTO_TCP, seq + 22));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_SOCK_DIAG_UDP",
		sock_diag_inet_dump(IPPROTO_UDP, seq + 23));
	failed |= expect_nonnegative("LEAN_NLATTR_STRESS_SOCK_DIAG_PACKET",
		sock_diag_packet_dump(seq + 24));

	failed |= expect_negative("LEAN_NLATTR_STRESS_GENL_MISSING",
		genl_getfamily_name(missing, (u32)cstrlen(missing) + 1, seq + 25));
	failed |= expect_negative("LEAN_NLATTR_STRESS_GENL_BAD_NUL",
		genl_getfamily_name(nlctrl, (u32)cstrlen(nlctrl), seq + 26));

	return failed;
}

__attribute__((noreturn)) void _start(void)
{
	struct live_diag_sockets sockets;
	int failed = 0;
	u32 i;
	long setup;

	puts("LEAN_NLATTR_STRESS_BEGIN\n");
	setup = open_live_diag_sockets(&sockets);
	if (setup < 0) {
		puts("LEAN_NLATTR_STRESS_SOCKET_SETUP_FAIL ");
		putint(setup);
		puts("\n");
		failed = 1;
	} else {
		for (i = 0; i < LEAN_NLATTR_STRESS_ITERS; i++)
			failed |= run_round(i);
	}
	close_live_diag_sockets(&sockets);

	if (failed)
		puts("LEAN_NLATTR_STRESS_FAIL\n");
	else
		puts("LEAN_NLATTR_STRESS_OK\n");
	puts("LEAN_NLATTR_STRESS_DONE\n");

	sys4(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
	     LINUX_REBOOT_CMD_POWER_OFF, 0);
	sys1(SYS_exit, 0);
	for (;;)
		sys1(SYS_exit, 0);
}
