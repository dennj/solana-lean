// SPDX-License-Identifier: GPL-2.0

#include <linux/atomic.h>
#include <linux/kernel.h>
#include <linux/netlink.h>
#include <linux/nospec.h>
#include <linux/sched.h>
#include <linux/types.h>
#include <net/netlink.h>

#define LEAN_NLATTR_KNOWN_VALIDATE_FLAGS 31u

#define LEAN_NLATTR_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)

LEAN_NLATTR_STATIC_ASSERT(sizeof(struct nlattr) == 4,
			  "Lean nlattr assumes a 4-byte struct nlattr header");
LEAN_NLATTR_STATIC_ASSERT(NLA_HDRLEN == 4,
			  "Lean nlattr assumes NLA_HDRLEN == 4");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nlattr, nla_len) == 0,
			  "Lean nlattr assumes nla_len at offset 0");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nlattr, nla_type) == 2,
			  "Lean nlattr assumes nla_type at offset 2");
LEAN_NLATTR_STATIC_ASSERT(NLA_F_NESTED == 0x8000,
			  "Lean nlattr assumes NLA_F_NESTED == 0x8000");
LEAN_NLATTR_STATIC_ASSERT((NLA_TYPE_MASK & 0xffff) == 0x3fff,
			  "Lean nlattr assumes a 14-bit NLA type mask");
LEAN_NLATTR_STATIC_ASSERT(sizeof(unsigned long) == sizeof(u64),
			  "Lean nlattr assumes a 64-bit unsigned long");
LEAN_NLATTR_STATIC_ASSERT(__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__,
			  "Lean nlattr byte stores assume a little-endian kernel");

LEAN_NLATTR_STATIC_ASSERT(NLA_UNSPEC == 0, "Lean NLA_UNSPEC mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_U8 == 1, "Lean NLA_U8 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_U16 == 2, "Lean NLA_U16 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_U32 == 3, "Lean NLA_U32 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_U64 == 4, "Lean NLA_U64 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_STRING == 5, "Lean NLA_STRING mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_FLAG == 6, "Lean NLA_FLAG mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_MSECS == 7, "Lean NLA_MSECS mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_NESTED == 8, "Lean NLA_NESTED mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_NESTED_ARRAY == 9,
			  "Lean NLA_NESTED_ARRAY mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_NUL_STRING == 10,
			  "Lean NLA_NUL_STRING mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_BINARY == 11, "Lean NLA_BINARY mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_S8 == 12, "Lean NLA_S8 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_S16 == 13, "Lean NLA_S16 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_S32 == 14, "Lean NLA_S32 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_S64 == 15, "Lean NLA_S64 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_BITFIELD32 == 16,
			  "Lean NLA_BITFIELD32 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_REJECT == 17, "Lean NLA_REJECT mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_BE16 == 18, "Lean NLA_BE16 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_BE32 == 19, "Lean NLA_BE32 mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_SINT == 20, "Lean NLA_SINT mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_UINT == 21, "Lean NLA_UINT mismatch");

LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_NONE == 0,
			  "Lean NLA_VALIDATE_NONE mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_RANGE == 1,
			  "Lean NLA_VALIDATE_RANGE mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_RANGE_WARN_TOO_LONG == 2,
			  "Lean NLA_VALIDATE_RANGE_WARN_TOO_LONG mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_MIN == 3,
			  "Lean NLA_VALIDATE_MIN mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_MAX == 4,
			  "Lean NLA_VALIDATE_MAX mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_MASK == 5,
			  "Lean NLA_VALIDATE_MASK mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_RANGE_PTR == 6,
			  "Lean NLA_VALIDATE_RANGE_PTR mismatch");
LEAN_NLATTR_STATIC_ASSERT(NLA_VALIDATE_FUNCTION == 7,
			  "Lean NLA_VALIDATE_FUNCTION mismatch");

LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_LIBERAL == 0,
			  "Lean NL_VALIDATE_LIBERAL mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_TRAILING == 1,
			  "Lean NL_VALIDATE_TRAILING mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_MAXTYPE == 2,
			  "Lean NL_VALIDATE_MAXTYPE mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_UNSPEC == 4,
			  "Lean NL_VALIDATE_UNSPEC mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_STRICT_ATTRS == 8,
			  "Lean NL_VALIDATE_STRICT_ATTRS mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_NESTED == 16,
			  "Lean NL_VALIDATE_NESTED mismatch");
LEAN_NLATTR_STATIC_ASSERT(NL_VALIDATE_STRICT == LEAN_NLATTR_KNOWN_VALIDATE_FLAGS,
			  "Lean NL_VALIDATE_STRICT mask mismatch");

LEAN_NLATTR_STATIC_ASSERT(sizeof(struct nla_policy) == 16,
			  "Lean nla_policy raw helper assumes 16-byte policy rows");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, type) == 0,
			  "Lean nla_policy type offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, validation_type) == 1,
			  "Lean nla_policy validation_type offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, len) == 2,
			  "Lean nla_policy len offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, strict_start_type) == 8,
			  "Lean nla_policy union offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, mask) == 8,
			  "Lean nla_policy mask offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, bitfield32_valid) == 8,
			  "Lean nla_policy bitfield32_valid offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, nested_policy) == 8,
			  "Lean nla_policy nested_policy offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, range) == 8,
			  "Lean nla_policy range offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, range_signed) == 8,
			  "Lean nla_policy range_signed offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, min) == 8,
			  "Lean nla_policy min offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, max) == 10,
			  "Lean nla_policy max offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, validate) == 8,
			  "Lean nla_policy validate callback offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct nla_policy, reject_message) == 8,
			  "Lean nla_policy reject_message offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(sizeof(struct netlink_range_validation) == 16,
			  "Lean unsigned range-pointer layout mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct netlink_range_validation, min) == 0,
			  "Lean unsigned range min offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct netlink_range_validation, max) == 8,
			  "Lean unsigned range max offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(sizeof(struct netlink_range_validation_signed) == 16,
			  "Lean signed range-pointer layout mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct netlink_range_validation_signed, min) == 0,
			  "Lean signed range min offset mismatch");
LEAN_NLATTR_STATIC_ASSERT(offsetof(struct netlink_range_validation_signed, max) == 8,
			  "Lean signed range max offset mismatch");

#ifndef LEAN_NLATTR_HEAP_BYTES
#define LEAN_NLATTR_HEAP_BYTES (64u * 1024u)
#endif

#ifdef LEAN_NLATTR_TRACE_COVERAGE
#define lean_nlattr_coverage_once(name) \
	pr_info_once("lean-nlattr: coverage hook." name "\n")
#else
#define lean_nlattr_coverage_once(name) do { } while (0)
#endif

#ifdef LEAN_NLATTR_TRACE_COUNTS
static bool lean_nlattr_count_enabled;
static atomic64_t lean_nlattr_count_policy_validate_fn;

#define lean_nlattr_count(name) \
	do { \
		if (unlikely(lean_nlattr_count_enabled)) \
			atomic64_inc(&lean_nlattr_count_ ## name); \
	} while (0)

static void lean_nlattr_trace_counts_clear(void)
{
	atomic64_set(&lean_nlattr_count_policy_validate_fn, 0);
}
#else
#define lean_nlattr_count(name) do { } while (0)
#endif

void lean_nlattr_trace_counts_reset(void);
void lean_nlattr_trace_counts_enable(bool enabled);
void lean_nlattr_trace_counts_report(const char *label);

#ifdef LEAN_NLATTR_ENABLE_RUNTIME_HOOKS
void lean_freestanding_log(const char *msg, unsigned long long len);
void lean_freestanding_panic(const char *what, unsigned long long a,
			     unsigned long long b);

unsigned char __lean_heap_start[LEAN_NLATTR_HEAP_BYTES] __aligned(16);

void lean_freestanding_log(const char *msg, unsigned long long len)
{
	pr_info("lean-nlattr: %.*s\n", (int)len, msg);
}

void lean_freestanding_panic(const char *what, unsigned long long a,
			     unsigned long long b)
{
	panic("lean-nlattr: freestanding runtime panic: %s (%llu, %llu)",
	      what, a, b);
}
#endif

void lean_nlattr_trace_counts_reset(void)
{
#ifdef LEAN_NLATTR_TRACE_COUNTS
	lean_nlattr_count_enabled = false;
	lean_nlattr_trace_counts_clear();
#endif
}

void lean_nlattr_trace_counts_enable(bool enabled)
{
#ifdef LEAN_NLATTR_TRACE_COUNTS
	lean_nlattr_count_enabled = enabled;
#endif
}

void lean_nlattr_trace_counts_report(const char *label)
{
#ifdef LEAN_NLATTR_TRACE_COUNTS
	pr_info("lean-nlattr: counts %s policy_validate_fn=%lld\n",
		label,
		atomic64_read(&lean_nlattr_count_policy_validate_fn));
#else
	pr_info("lean-nlattr: counts %s disabled\n", label);
#endif
}


u64 lean_nlattr_policy_validate_fn_raw(u64 policy, u64 ty, u64 attr,
				       u64 extack);
u64 lean_nlattr_array_index_nospec(u64 index, u64 size);
u64 lean_nlattr_report_recursion_depth(u64 extack);
u64 lean_nlattr_report_unknown_attr(u64 attr, u64 extack);
u64 lean_nlattr_warn_trailing_bytes(u64 unit);
u64 lean_nlattr_report_trailing_bytes(u64 extack);
u64 lean_nlattr_warn_invalid_attr_len(u64 ty);
u64 lean_nlattr_report_invalid_attr_len_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_invalid_attr_len_policy(u64 attr, u64 policy, u64 ty,
					       u64 extack);
u64 lean_nlattr_report_nested_missing_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_nested_missing_policy(u64 attr, u64 policy, u64 ty,
					     u64 extack);
u64 lean_nlattr_report_nested_unexpected_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_nested_unexpected_policy(u64 attr, u64 policy, u64 ty,
						u64 extack);
u64 lean_nlattr_report_reject_message(u64 attr, u64 policy, u64 ty,
				      u64 extack);
u64 lean_nlattr_report_failed_policy_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_failed_policy_policy(u64 attr, u64 policy, u64 ty,
					    u64 extack);
u64 lean_nlattr_report_unsupported_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_reserved_bit(u64 attr, u64 extack);
u64 lean_nlattr_report_binary_range_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_binary_range_policy(u64 attr, u64 policy, u64 ty,
					   u64 extack);
u64 lean_nlattr_report_integer_range_attr(u64 attr, u64 extack);
u64 lean_nlattr_report_integer_range_policy(u64 attr, u64 policy, u64 ty,
					    u64 extack);
u64 lean_nlattr_strdup_alloc(u64 len, u64 flags);
u64 lean_nlattr_skb_tailroom(u64 skb);
u64 lean_nlattr_skb_needs_64bit_padding(u64 skb);
u64 lean_nlattr_skb_align_64bit(u64 skb, u64 padattr);
u64 lean_nlattr_skb_put_raw(u64 skb, u64 len);


static const struct nla_policy *lean_policy_at(u64 policy, u64 ty)
{
	return &((const struct nla_policy *)(uintptr_t)policy)[ty];
}

u64 lean_nlattr_array_index_nospec(u64 index, u64 size)
{
	lean_nlattr_coverage_once("array_index_nospec");

	return array_index_nospec((unsigned long)index, (unsigned long)size);
}

static struct netlink_ext_ack *lean_ack(u64 extack)
{
	return (struct netlink_ext_ack *)(uintptr_t)extack;
}

static const struct nlattr *lean_attr(u64 attr)
{
	return (const struct nlattr *)(uintptr_t)attr;
}

u64 lean_nlattr_report_recursion_depth(u64 extack)
{
	NL_SET_ERR_MSG(lean_ack(extack),
		       "allowed policy recursion depth exceeded");
	return 0;
}

u64 lean_nlattr_report_unknown_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "Unknown attribute type");
	return 0;
}

u64 lean_nlattr_warn_trailing_bytes(u64 unit)
{
	(void)unit;
	pr_warn_ratelimited("netlink: bytes leftover after parsing attributes in process `%s'.\n",
			    current->comm);
	return 0;
}

u64 lean_nlattr_report_trailing_bytes(u64 extack)
{
	NL_SET_ERR_MSG(lean_ack(extack),
		       "bytes leftover after parsing attributes");
	return 0;
}

u64 lean_nlattr_warn_invalid_attr_len(u64 ty)
{
	pr_warn_ratelimited("netlink: '%s': attribute type %llu has an invalid length.\n",
			    current->comm, (unsigned long long)ty);
	return 0;
}

u64 lean_nlattr_report_invalid_attr_len_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "invalid attribute length");
	return 0;
}

u64 lean_nlattr_report_invalid_attr_len_policy(u64 attr, u64 policy, u64 ty,
					       u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"invalid attribute length");
	return 0;
}

u64 lean_nlattr_report_nested_missing_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "NLA_F_NESTED is missing");
	return 0;
}

u64 lean_nlattr_report_nested_missing_policy(u64 attr, u64 policy, u64 ty,
					     u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"NLA_F_NESTED is missing");
	return 0;
}

u64 lean_nlattr_report_nested_unexpected_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "NLA_F_NESTED not expected");
	return 0;
}

u64 lean_nlattr_report_nested_unexpected_policy(u64 attr, u64 policy, u64 ty,
						u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"NLA_F_NESTED not expected");
	return 0;
}

u64 lean_nlattr_report_reject_message(u64 attr, u64 policy, u64 ty, u64 extack)
{
	struct netlink_ext_ack *ack = lean_ack(extack);

	NL_SET_BAD_ATTR(ack, lean_attr(attr));
	ack->_msg = lean_policy_at(policy, ty)->reject_message;
	return 0;
}

u64 lean_nlattr_report_failed_policy_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "Attribute failed policy validation");
	return 0;
}

u64 lean_nlattr_report_failed_policy_policy(u64 attr, u64 policy, u64 ty,
					    u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"Attribute failed policy validation");
	return 0;
}

u64 lean_nlattr_report_unsupported_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "Unsupported attribute");
	return 0;
}

u64 lean_nlattr_report_reserved_bit(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "reserved bit set");
	return 0;
}

u64 lean_nlattr_report_binary_range_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "binary attribute size out of range");
	return 0;
}

u64 lean_nlattr_report_binary_range_policy(u64 attr, u64 policy, u64 ty,
					   u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"binary attribute size out of range");
	return 0;
}

u64 lean_nlattr_report_integer_range_attr(u64 attr, u64 extack)
{
	NL_SET_ERR_MSG_ATTR(lean_ack(extack), lean_attr(attr),
			    "integer out of range");
	return 0;
}

u64 lean_nlattr_report_integer_range_policy(u64 attr, u64 policy, u64 ty,
					    u64 extack)
{
	NL_SET_ERR_MSG_ATTR_POL(lean_ack(extack), lean_attr(attr),
				lean_policy_at(policy, ty),
				"integer out of range");
	return 0;
}




u64 lean_nlattr_policy_validate_fn_raw(u64 policy, u64 ty, u64 attr, u64 extack)
{
	const struct nla_policy *pt = lean_policy_at(policy, ty);

	lean_nlattr_coverage_once("policy_validate_fn");
	lean_nlattr_count(policy_validate_fn);

	return (u64)(s64)pt->validate(
		(const struct nlattr *)(uintptr_t)attr,
		(struct netlink_ext_ack *)(uintptr_t)extack);
}


u64 lean_nlattr_strdup_alloc(u64 len, u64 flags)
{
	lean_nlattr_coverage_once("strdup_alloc");

	return (u64)(uintptr_t)kmalloc((size_t)len + 1, (gfp_t)flags);
}

u64 lean_nlattr_skb_tailroom(u64 skb)
{
	lean_nlattr_coverage_once("skb_tailroom");
	return skb_tailroom((const struct sk_buff *)(uintptr_t)skb);
}

u64 lean_nlattr_skb_needs_64bit_padding(u64 skb)
{
	lean_nlattr_coverage_once("skb_needs_64bit_padding");
	return nla_need_padding_for_64bit((struct sk_buff *)(uintptr_t)skb);
}

u64 lean_nlattr_skb_align_64bit(u64 skb, u64 padattr)
{
	lean_nlattr_coverage_once("skb_align_64bit");
	nla_align_64bit((struct sk_buff *)(uintptr_t)skb, (int)padattr);
	return 0;
}

u64 lean_nlattr_skb_put_raw(u64 skb, u64 len)
{
	lean_nlattr_coverage_once("skb_put_raw");

	return (u64)(uintptr_t)skb_put((struct sk_buff *)(uintptr_t)skb,
				       (unsigned int)len);
}
