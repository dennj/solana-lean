// SPDX-License-Identifier: GPL-2.0

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/ktime.h>
#include <linux/math64.h>
#include <linux/skbuff.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/types.h>
#include <net/netlink.h>

#include "lean_nlattr_benchmark_original.c"

#ifndef LEAN_NLATTR_BENCH_ITERS
#define LEAN_NLATTR_BENCH_ITERS 20000u
#endif

#ifndef LEAN_NLATTR_BENCH_ROUNDS
#define LEAN_NLATTR_BENCH_ROUNDS 7u
#endif

#if LEAN_NLATTR_BENCH_ROUNDS < 1
#error "LEAN_NLATTR_BENCH_ROUNDS must be at least 1"
#endif

void lean_nlattr_trace_counts_reset(void);
void lean_nlattr_trace_counts_enable(bool enabled);
void lean_nlattr_trace_counts_report(const char *label);

enum {
	LEAN_BENCH_ATTR_STR = 1,
	LEAN_BENCH_ATTR_U32 = 2,
	LEAN_BENCH_ATTR_FLAG = 3,
	LEAN_BENCH_ATTR_BIN = 4,
	LEAN_BENCH_ATTR_MAX = 4,
};

enum {
	LEAN_BENCH_POLICY_U8 = 1,
	LEAN_BENCH_POLICY_S8 = 2,
	LEAN_BENCH_POLICY_BE16 = 3,
	LEAN_BENCH_POLICY_UINT = 4,
	LEAN_BENCH_POLICY_SINT = 5,
	LEAN_BENCH_POLICY_BINARY = 6,
	LEAN_BENCH_POLICY_VALIDATE = 7,
	LEAN_BENCH_POLICY_MAX = 7,
};

enum {
	LEAN_BENCH_EDGE_U32 = 1,
	LEAN_BENCH_EDGE_NESTED = 2,
	LEAN_BENCH_EDGE_REJECT = 3,
	LEAN_BENCH_EDGE_BITFIELD = 4,
	LEAN_BENCH_EDGE_STRING = 5,
	LEAN_BENCH_EDGE_NUL_STRING = 6,
	LEAN_BENCH_EDGE_CALLBACK = 7,
	LEAN_BENCH_EDGE_MAX = 7,
};

enum {
	LEAN_BENCH_NESTED_VALUE = 1,
	LEAN_BENCH_NESTED_MAX = 1,
};

enum {
	LEAN_BENCH_OUTER_NESTED = 1,
	LEAN_BENCH_OUTER_ARRAY = 2,
	LEAN_BENCH_OUTER_MAX = 2,
};

typedef int (*lean_bench_parse_fn)(struct nlattr **tb, int maxtype,
				   const struct nlattr *head, int len,
				   const struct nla_policy *policy,
				   unsigned int validate,
				   struct netlink_ext_ack *extack);
typedef int (*lean_bench_validate_fn)(const struct nlattr *head, int len,
				      int maxtype,
				      const struct nla_policy *policy,
				      unsigned int validate,
				      struct netlink_ext_ack *extack);
typedef u64 (*lean_bench_helper_fn)(const struct nlattr *head, int len);

static u64 lean_nlattr_bench_sink;

static const char lean_nlattr_benchmark_long_string[] =
	"Lean nlattr helper payload 0123456789 abcdefghijklmnopqrstuvwxyz";

static int __init lean_nlattr_benchmark_fail(const char *name)
{
	pr_err("lean-nlattr: benchmark FAIL %s\n", name);
	return -EINVAL;
}

static void __init lean_nlattr_benchmark_put_attr(u8 *buf, size_t *off,
						  u16 type, const void *data,
						  size_t len)
{
	struct nlattr *nla = (struct nlattr *)(buf + *off);

	nla->nla_type = type;
	nla->nla_len = nla_attr_size(len);
	if (len)
		memcpy(nla_data(nla), data, len);
	memset((u8 *)nla + nla->nla_len, 0, nla_padlen(len));
	*off += nla_total_size(len);
}

static size_t __init lean_nlattr_benchmark_make_stream(u8 *stream,
						       size_t stream_len)
{
	const char str_payload[] = "lean";
	const u8 bin_payload[] = { 0xa1, 0xb2, 0xc3 };
	u32 word = 0x11223344;
	size_t off = 0;

	memset(stream, 0, stream_len);
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_STR,
				       str_payload, sizeof(str_payload));
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_U32,
				       &word, sizeof(word));
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_FLAG,
				       NULL, 0);
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_BIN,
				       bin_payload, sizeof(bin_payload));
	return off;
}

static size_t __init lean_nlattr_benchmark_make_helper_large_stream(
	u8 *stream, size_t stream_len)
{
	u8 bin_payload[64];
	size_t off = 0;
	u32 i;

	for (i = 0; i < ARRAY_SIZE(bin_payload); i++)
		bin_payload[i] = (u8)(0xa0u + i);

	memset(stream, 0, stream_len);
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_STR,
				       lean_nlattr_benchmark_long_string,
				       sizeof(lean_nlattr_benchmark_long_string));
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_ATTR_BIN,
				       bin_payload, sizeof(bin_payload));
	return off;
}

static const struct nla_policy lean_nlattr_benchmark_policy[LEAN_BENCH_ATTR_MAX + 1] = {
	[LEAN_BENCH_ATTR_STR] = {
		.type = NLA_NUL_STRING,
		.len = 8,
	},
	[LEAN_BENCH_ATTR_U32] = {
		.type = NLA_U32,
	},
	[LEAN_BENCH_ATTR_FLAG] = {
		.type = NLA_FLAG,
	},
	[LEAN_BENCH_ATTR_BIN] = {
		.type = NLA_BINARY,
		.len = 3,
	},
};

static int __init lean_nlattr_benchmark_validate_ok(const struct nlattr *nla,
						    struct netlink_ext_ack *extack)
{
	return nla_len(nla) == sizeof(u8) ? 0 : -EINVAL;
}

static int __init lean_nlattr_benchmark_validate_eperm(const struct nlattr *nla,
						       struct netlink_ext_ack *extack)
{
	return -EPERM;
}

static int __init lean_nlattr_benchmark_compare_extack(
	const char *name, const struct netlink_ext_ack *c_extack,
	const struct netlink_ext_ack *lean_extack)
{
	if (!!c_extack->_msg != !!lean_extack->_msg ||
	    (c_extack->_msg && strcmp(c_extack->_msg, lean_extack->_msg))) {
		pr_err("lean-nlattr: benchmark extack message mismatch %s c=%s lean=%s\n",
		       name, c_extack->_msg ? c_extack->_msg : "<null>",
		       lean_extack->_msg ? lean_extack->_msg : "<null>");
		return lean_nlattr_benchmark_fail(name);
	}
	if (c_extack->bad_attr != lean_extack->bad_attr) {
		pr_err("lean-nlattr: benchmark extack bad_attr mismatch %s c=%px lean=%px\n",
		       name, (const void *)c_extack->bad_attr,
		       (const void *)lean_extack->bad_attr);
		return lean_nlattr_benchmark_fail(name);
	}
	if (c_extack->policy != lean_extack->policy) {
		pr_err("lean-nlattr: benchmark extack policy mismatch %s c=%px lean=%px\n",
		       name, (const void *)c_extack->policy,
		       (const void *)lean_extack->policy);
		return lean_nlattr_benchmark_fail(name);
	}

	return 0;
}

static int __init lean_nlattr_benchmark_compare_validate_stream(
	const char *name, const struct nla_policy *policy, int maxtype,
	const void *stream, int len, unsigned int validate)
{
	struct netlink_ext_ack extack_c = {};
	struct netlink_ext_ack extack_l = {};
	int ret_c, ret_l;

	ret_c = lean_original___nla_validate((const struct nlattr *)stream,
					     len, maxtype, policy, validate,
					     &extack_c);
	ret_l = __nla_validate((const struct nlattr *)stream, len, maxtype,
			       policy, validate, &extack_l);
	if (ret_c != ret_l) {
		pr_err("lean-nlattr: benchmark validate mismatch %s c=%d lean=%d\n",
		       name, ret_c, ret_l);
		return lean_nlattr_benchmark_fail(name);
	}

	return lean_nlattr_benchmark_compare_extack(name, &extack_c, &extack_l);
}

static int __init lean_nlattr_benchmark_compare_validate_one(
	const char *name, const struct nla_policy *policy, int maxtype,
	u16 type, const void *data, size_t len, unsigned int validate)
{
	u8 stream[128] __aligned(NLA_ALIGNTO);
	size_t off = 0;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_benchmark_put_attr(stream, &off, type, data, len);

	return lean_nlattr_benchmark_compare_validate_stream(name, policy, maxtype,
							    stream, (int)off,
							    validate);
}

static int __init lean_nlattr_benchmark_check_policy_values(void)
{
	const struct netlink_range_validation uint_range = {
		.min = 65000,
		.max = 70000,
	};
	const struct netlink_range_validation_signed sint_range = {
		.min = -10,
		.max = -1,
	};
	struct nla_policy policy[LEAN_BENCH_POLICY_MAX + 1] = {
		[LEAN_BENCH_POLICY_U8] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_RANGE,
			.min = 5,
			.max = 9,
		},
		[LEAN_BENCH_POLICY_S8] = {
			.type = NLA_S8,
			.validation_type = NLA_VALIDATE_RANGE,
			.min = -10,
			.max = -1,
		},
		[LEAN_BENCH_POLICY_BE16] = {
			.type = NLA_BE16,
			.validation_type = NLA_VALIDATE_MAX,
			.max = 0x1300,
		},
		[LEAN_BENCH_POLICY_UINT] = {
			.type = NLA_UINT,
			.validation_type = NLA_VALIDATE_RANGE_PTR,
			.range = &uint_range,
		},
		[LEAN_BENCH_POLICY_SINT] = {
			.type = NLA_SINT,
			.validation_type = NLA_VALIDATE_RANGE_PTR,
			.range_signed = &sint_range,
		},
		[LEAN_BENCH_POLICY_BINARY] = {
			.type = NLA_BINARY,
			.validation_type = NLA_VALIDATE_RANGE_WARN_TOO_LONG,
			.min = 4,
			.max = 4,
		},
		[LEAN_BENCH_POLICY_VALIDATE] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_FUNCTION,
			.validate = lean_nlattr_benchmark_validate_ok,
		},
	};
	const struct nla_policy mask_policy[LEAN_BENCH_POLICY_MAX + 1] = {
		[LEAN_BENCH_POLICY_U8] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_MASK,
			.mask = 0x0f,
		},
	};
	u8 u8_ok = 7;
	u8 u8_bad = 11;
	s8 s8_ok = -5;
	s8 s8_bad = 3;
	u8 be16_ok[] = { 0x12, 0x00 };
	u8 be16_bad[] = { 0x14, 0x00 };
	u64 uint_ok = 66000;
	u64 uint_bad = 80000;
	s32 sint_ok = -5;
	s32 sint_bad = 5;
	u8 binary_long[] = { 1, 2, 3, 4, 5 };
	u8 binary_short[] = { 1, 2, 3 };
	int ret;

	ret = lean_nlattr_benchmark_compare_validate_one("u8-range-ok", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_U8,
							 &u8_ok, sizeof(u8_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("u8-range-bad", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_U8,
							 &u8_bad, sizeof(u8_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("u8-mask-ok", mask_policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_U8,
							 &u8_ok, sizeof(u8_ok),
							 0);
	if (ret)
		return ret;
	u8_bad = 0x80;
	ret = lean_nlattr_benchmark_compare_validate_one("u8-mask-bad",
							 mask_policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_U8,
							 &u8_bad, sizeof(u8_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("s8-range-ok", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_S8,
							 &s8_ok, sizeof(s8_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("s8-range-bad", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_S8,
							 &s8_bad, sizeof(s8_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("be16-max-ok", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_BE16,
							 be16_ok, sizeof(be16_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("be16-max-bad", policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_BE16,
							 be16_bad, sizeof(be16_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("uint-range-ptr-ok",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_UINT,
							 &uint_ok, sizeof(uint_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("uint-range-ptr-bad",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_UINT,
							 &uint_bad, sizeof(uint_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("sint-range-ptr-ok",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_SINT,
							 &sint_ok, sizeof(sint_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("sint-range-ptr-bad",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_SINT,
							 &sint_bad, sizeof(sint_bad),
							 0);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("binary-warn-long",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_BINARY,
							 binary_long,
							 sizeof(binary_long),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("binary-warn-strict",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_BINARY,
							 binary_long,
							 sizeof(binary_long),
							 NL_VALIDATE_STRICT_ATTRS);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("binary-warn-short",
							 policy,
							 LEAN_BENCH_POLICY_MAX,
							 LEAN_BENCH_POLICY_BINARY,
							 binary_short,
							 sizeof(binary_short),
							 0);
	if (ret)
		return ret;

	return lean_nlattr_benchmark_compare_validate_one("validate-fn", policy,
							  LEAN_BENCH_POLICY_MAX,
							  LEAN_BENCH_POLICY_VALIDATE,
							  &u8_ok, sizeof(u8_ok),
							  0);
}

static int __init lean_nlattr_benchmark_check_edges(void)
{
	const struct nla_policy edge_policy[LEAN_BENCH_EDGE_MAX + 1] = {
		[LEAN_BENCH_EDGE_U32] = {
			.type = NLA_U32,
		},
		[LEAN_BENCH_EDGE_NESTED] = {
			.type = NLA_NESTED,
		},
		[LEAN_BENCH_EDGE_REJECT] = {
			.type = NLA_REJECT,
			.reject_message = "reject me",
		},
		[LEAN_BENCH_EDGE_BITFIELD] =
			NLA_POLICY_BITFIELD32(0x0f),
		[LEAN_BENCH_EDGE_STRING] = {
			.type = NLA_STRING,
			.len = 3,
		},
		[LEAN_BENCH_EDGE_NUL_STRING] = {
			.type = NLA_NUL_STRING,
			.len = 8,
		},
		[LEAN_BENCH_EDGE_CALLBACK] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_FUNCTION,
			.validate = lean_nlattr_benchmark_validate_eperm,
		},
	};
	const struct nla_policy strict_start_policy[LEAN_BENCH_EDGE_U32 + 1] = {
		[0] = {
			.strict_start_type = LEAN_BENCH_EDGE_U32,
		},
		[LEAN_BENCH_EDGE_U32] = {
			.type = NLA_U32,
		},
	};
	struct nla_bitfield32 bitfield_ok = {
		.value = 0x03,
		.selector = 0x03,
	};
	struct nla_bitfield32 bitfield_bad = {
		.value = 0x10,
		.selector = 0x10,
	};
	u64 wide = 0x0102030405060708ULL;
	u32 word = 0x01020304;
	u8 byte = 1;
	const char string_too_long[] = "abcd";
	const char nul_missing[] = { 'l', 'e', 'a', 'n' };
	u8 stream[128] __aligned(NLA_ALIGNTO);
	size_t off = 0;
	int ret;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_benchmark_put_attr(stream, &off, LEAN_BENCH_EDGE_U32,
				       &word, sizeof(word));
	ret = lean_nlattr_benchmark_compare_validate_stream("tail-liberal",
							    edge_policy,
							    LEAN_BENCH_EDGE_MAX,
							    stream, (int)off + 1,
							    0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_stream("tail-strict",
							    edge_policy,
							    LEAN_BENCH_EDGE_MAX,
							    stream, (int)off + 1,
							    NL_VALIDATE_TRAILING);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("maxtype-liberal",
							 edge_policy,
							 LEAN_BENCH_EDGE_U32,
							 LEAN_BENCH_EDGE_U32 + 1,
							 NULL, 0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("maxtype-strict",
							 edge_policy,
							 LEAN_BENCH_EDGE_U32,
							 LEAN_BENCH_EDGE_U32 + 1,
							 NULL, 0,
							 NL_VALIDATE_MAXTYPE);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("type-zero-strict",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 0, NULL, 0,
							 NL_VALIDATE_MAXTYPE);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("strict-start",
							 strict_start_policy,
							 LEAN_BENCH_EDGE_U32,
							 LEAN_BENCH_EDGE_U32,
							 &wide, sizeof(wide),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("nested-flag-missing",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_NESTED,
							 NULL, 0,
							 NL_VALIDATE_NESTED);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("nested-flag-unexpected",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_U32 |
								NLA_F_NESTED,
							 &word, sizeof(word),
							 NL_VALIDATE_NESTED);
	if (ret)
		return ret;

	ret = lean_nlattr_benchmark_compare_validate_one("reject", edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_REJECT,
							 NULL, 0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("bitfield-ok",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_BITFIELD,
							 &bitfield_ok,
							 sizeof(bitfield_ok),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("bitfield-bad",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_BITFIELD,
							 &bitfield_bad,
							 sizeof(bitfield_bad),
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("string-too-long",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_STRING,
							 string_too_long,
							 sizeof(string_too_long) - 1,
							 0);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_compare_validate_one("nul-string-missing",
							 edge_policy,
							 LEAN_BENCH_EDGE_MAX,
							 LEAN_BENCH_EDGE_NUL_STRING,
							 nul_missing,
							 sizeof(nul_missing),
							 0);
	if (ret)
		return ret;

	return lean_nlattr_benchmark_compare_validate_one("callback-eperm",
							  edge_policy,
							  LEAN_BENCH_EDGE_MAX,
							  LEAN_BENCH_EDGE_CALLBACK,
							  &byte, sizeof(byte),
							  0);
}

static int __init lean_nlattr_benchmark_check_nested(void)
{
	const struct nla_policy nested_policy[LEAN_BENCH_NESTED_MAX + 1] = {
		[LEAN_BENCH_NESTED_VALUE] = {
			.type = NLA_U32,
		},
	};
	const struct nla_policy outer_policy[LEAN_BENCH_OUTER_MAX + 1] = {
		[LEAN_BENCH_OUTER_NESTED] =
			NLA_POLICY_NESTED(nested_policy),
		[LEAN_BENCH_OUTER_ARRAY] =
			NLA_POLICY_NESTED_ARRAY(nested_policy),
	};
	u32 word = 0x01020304;
	u16 too_short = 0x0102;
	u8 nested_payload[64] __aligned(NLA_ALIGNTO);
	u8 nested_bad_payload[64] __aligned(NLA_ALIGNTO);
	u8 array_payload[96] __aligned(NLA_ALIGNTO);
	u8 outer_stream[160] __aligned(NLA_ALIGNTO);
	size_t nested_off = 0;
	size_t nested_bad_off = 0;
	size_t array_off = 0;
	size_t outer_off = 0;
	int ret;

	memset(nested_payload, 0, sizeof(nested_payload));
	memset(nested_bad_payload, 0, sizeof(nested_bad_payload));
	memset(array_payload, 0, sizeof(array_payload));
	memset(outer_stream, 0, sizeof(outer_stream));

	lean_nlattr_benchmark_put_attr(nested_payload, &nested_off,
				       LEAN_BENCH_NESTED_VALUE, &word,
				       sizeof(word));
	lean_nlattr_benchmark_put_attr(outer_stream, &outer_off,
				       LEAN_BENCH_OUTER_NESTED | NLA_F_NESTED,
				       nested_payload, nested_off);
	ret = lean_nlattr_benchmark_compare_validate_stream("nested-policy-ok",
							    outer_policy,
							    LEAN_BENCH_OUTER_MAX,
							    outer_stream,
							    (int)outer_off,
							    NL_VALIDATE_STRICT);
	if (ret)
		return ret;

	lean_nlattr_benchmark_put_attr(nested_bad_payload, &nested_bad_off,
				       LEAN_BENCH_NESTED_VALUE, &too_short,
				       sizeof(too_short));
	outer_off = 0;
	memset(outer_stream, 0, sizeof(outer_stream));
	lean_nlattr_benchmark_put_attr(outer_stream, &outer_off,
				       LEAN_BENCH_OUTER_NESTED | NLA_F_NESTED,
				       nested_bad_payload, nested_bad_off);
	ret = lean_nlattr_benchmark_compare_validate_stream("nested-policy-bad",
							    outer_policy,
							    LEAN_BENCH_OUTER_MAX,
							    outer_stream,
							    (int)outer_off,
							    NL_VALIDATE_STRICT);
	if (ret)
		return ret;

	lean_nlattr_benchmark_put_attr(array_payload, &array_off, 1,
				       nested_payload, nested_off);
	outer_off = 0;
	memset(outer_stream, 0, sizeof(outer_stream));
	lean_nlattr_benchmark_put_attr(outer_stream, &outer_off,
				       LEAN_BENCH_OUTER_ARRAY | NLA_F_NESTED,
				       array_payload, array_off);
	return lean_nlattr_benchmark_compare_validate_stream("nested-array-ok",
							    outer_policy,
							    LEAN_BENCH_OUTER_MAX,
							    outer_stream,
							    (int)outer_off,
							    NL_VALIDATE_STRICT);
}

static int __init lean_nlattr_benchmark_check_helpers(const struct nlattr *head,
						      int len)
{
	struct nlattr *tb_c[LEAN_BENCH_ATTR_MAX + 1];
	struct nlattr *tb_l[LEAN_BENCH_ATTR_MAX + 1];
	struct netlink_range_validation range_c, range_l;
	struct netlink_range_validation_signed srange_c, srange_l;
	struct nla_policy unsigned_policy = {
		.type = NLA_U32,
		.validation_type = NLA_VALIDATE_MIN,
		.min = 7,
	};
	struct nla_policy signed_policy = {
		.type = NLA_S8,
		.validation_type = NLA_VALIDATE_MAX,
		.max = 5,
	};
	char cbuf[8], lbuf[8];
	char *cdup, *ldup;
	u32 cword = 0, lword = 0;
	int ret_c, ret_l;

	ret_c = lean_original___nla_parse(tb_c, LEAN_BENCH_ATTR_MAX, head, len,
					  lean_nlattr_benchmark_policy,
					  NL_VALIDATE_STRICT, NULL);
	ret_l = __nla_parse(tb_l, LEAN_BENCH_ATTR_MAX, head, len,
			    lean_nlattr_benchmark_policy, NL_VALIDATE_STRICT,
			    NULL);
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("parse-ret");
	if (!tb_c[LEAN_BENCH_ATTR_U32] || !tb_l[LEAN_BENCH_ATTR_U32])
		return lean_nlattr_benchmark_fail("parse-table");

	ret_c = lean_original___nla_validate(head, len, LEAN_BENCH_ATTR_MAX,
					     lean_nlattr_benchmark_policy,
					     NL_VALIDATE_STRICT, NULL);
	ret_l = __nla_validate(head, len, LEAN_BENCH_ATTR_MAX,
			       lean_nlattr_benchmark_policy,
			       NL_VALIDATE_STRICT, NULL);
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("validate-ret");

	if (lean_original_nla_find(head, len, LEAN_BENCH_ATTR_BIN) !=
	    tb_c[LEAN_BENCH_ATTR_BIN])
		return lean_nlattr_benchmark_fail("c-find");
	if (nla_find(head, len, LEAN_BENCH_ATTR_BIN) != tb_l[LEAN_BENCH_ATTR_BIN])
		return lean_nlattr_benchmark_fail("lean-find");

	ret_c = lean_original_nla_strscpy(cbuf, tb_c[LEAN_BENCH_ATTR_STR],
					  sizeof(cbuf));
	ret_l = nla_strscpy(lbuf, tb_l[LEAN_BENCH_ATTR_STR], sizeof(lbuf));
	if (ret_c != ret_l || strcmp(cbuf, lbuf))
		return lean_nlattr_benchmark_fail("strscpy");

	ret_c = lean_original_nla_strcmp(tb_c[LEAN_BENCH_ATTR_STR], "lean");
	ret_l = nla_strcmp(tb_l[LEAN_BENCH_ATTR_STR], "lean");
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("strcmp");

	cdup = lean_original_nla_strdup(tb_c[LEAN_BENCH_ATTR_STR], GFP_KERNEL);
	ldup = nla_strdup(tb_l[LEAN_BENCH_ATTR_STR], GFP_KERNEL);
	if (!cdup || !ldup || strcmp(cdup, ldup)) {
		kfree(cdup);
		kfree(ldup);
		return lean_nlattr_benchmark_fail("strdup");
	}
	kfree(cdup);
	kfree(ldup);

	ret_c = lean_original_nla_memcmp(tb_c[LEAN_BENCH_ATTR_U32],
					 nla_data(tb_c[LEAN_BENCH_ATTR_U32]),
					 sizeof(cword));
	ret_l = nla_memcmp(tb_l[LEAN_BENCH_ATTR_U32],
			   nla_data(tb_l[LEAN_BENCH_ATTR_U32]), sizeof(lword));
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("memcmp");

	ret_c = lean_original_nla_memcpy(&cword, tb_c[LEAN_BENCH_ATTR_U32],
					 sizeof(cword));
	ret_l = nla_memcpy(&lword, tb_l[LEAN_BENCH_ATTR_U32], sizeof(lword));
	if (ret_c != ret_l || cword != lword)
		return lean_nlattr_benchmark_fail("memcpy");

	ret_c = lean_original_nla_policy_len(lean_nlattr_benchmark_policy,
					     ARRAY_SIZE(lean_nlattr_benchmark_policy));
	ret_l = nla_policy_len(lean_nlattr_benchmark_policy,
			       ARRAY_SIZE(lean_nlattr_benchmark_policy));
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("policy-len");

	lean_original_nla_get_range_unsigned(&unsigned_policy, &range_c);
	nla_get_range_unsigned(&unsigned_policy, &range_l);
	if (memcmp(&range_c, &range_l, sizeof(range_c)))
		return lean_nlattr_benchmark_fail("range-unsigned");

	lean_original_nla_get_range_signed(&signed_policy, &srange_c);
	nla_get_range_signed(&signed_policy, &srange_l);
	if (memcmp(&srange_c, &srange_l, sizeof(srange_c)))
		return lean_nlattr_benchmark_fail("range-signed");

	return 0;
}

static int __init lean_nlattr_benchmark_check_helpers_large(
	const struct nlattr *head, int len)
{
	const struct nlattr *str_c, *str_l, *bin_c, *bin_l;
	char cbuf[96], lbuf[96];
	u8 ccopy[64], lcopy[64];
	int ret_c, ret_l;

	str_c = lean_original_nla_find(head, len, LEAN_BENCH_ATTR_STR);
	str_l = nla_find(head, len, LEAN_BENCH_ATTR_STR);
	bin_c = lean_original_nla_find(head, len, LEAN_BENCH_ATTR_BIN);
	bin_l = nla_find(head, len, LEAN_BENCH_ATTR_BIN);
	if (!str_c || !str_l || !bin_c || !bin_l)
		return lean_nlattr_benchmark_fail("helpers-large-find");

	memset(cbuf, 0, sizeof(cbuf));
	memset(lbuf, 0, sizeof(lbuf));
	ret_c = lean_original_nla_strscpy(cbuf, str_c, sizeof(cbuf));
	ret_l = nla_strscpy(lbuf, str_l, sizeof(lbuf));
	if (ret_c != ret_l || memcmp(cbuf, lbuf, sizeof(cbuf)))
		return lean_nlattr_benchmark_fail("helpers-large-strscpy");

	ret_c = lean_original_nla_strcmp(str_c,
					 lean_nlattr_benchmark_long_string);
	ret_l = nla_strcmp(str_l, lean_nlattr_benchmark_long_string);
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("helpers-large-strcmp");

	memset(ccopy, 0, sizeof(ccopy));
	memset(lcopy, 0, sizeof(lcopy));
	ret_c = lean_original_nla_memcpy(ccopy, bin_c, sizeof(ccopy));
	ret_l = nla_memcpy(lcopy, bin_l, sizeof(lcopy));
	if (ret_c != ret_l || memcmp(ccopy, lcopy, sizeof(ccopy)))
		return lean_nlattr_benchmark_fail("helpers-large-memcpy");

	ret_c = lean_original_nla_memcmp(bin_c, ccopy, sizeof(ccopy));
	ret_l = nla_memcmp(bin_l, lcopy, sizeof(lcopy));
	if (ret_c != ret_l)
		return lean_nlattr_benchmark_fail("helpers-large-memcmp");

	return 0;
}

static u64 __init lean_nlattr_benchmark_parse(lean_bench_parse_fn fn,
					      const struct nlattr *head,
					      int len)
{
	struct nlattr *tb[LEAN_BENCH_ATTR_MAX + 1];
	u64 start = ktime_get_ns();
	u32 i;
	int ret;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		ret = fn(tb, LEAN_BENCH_ATTR_MAX, head, len,
			 lean_nlattr_benchmark_policy, NL_VALIDATE_STRICT,
			 NULL);
		lean_nlattr_bench_sink += (u64)ret + (uintptr_t)tb[LEAN_BENCH_ATTR_U32];
	}

	return ktime_get_ns() - start;
}

static u64 __init lean_nlattr_benchmark_validate(lean_bench_validate_fn fn,
						 const struct nlattr *head,
						 int len)
{
	u64 start = ktime_get_ns();
	u32 i;
	int ret;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		ret = fn(head, len, LEAN_BENCH_ATTR_MAX,
			 lean_nlattr_benchmark_policy, NL_VALIDATE_STRICT,
			 NULL);
		lean_nlattr_bench_sink += (u64)ret;
	}

	return ktime_get_ns() - start;
}

static u64 __init lean_nlattr_benchmark_helpers_c(const struct nlattr *head,
						  int len)
{
	char buf[8];
	u32 word;
	u64 start = ktime_get_ns();
	u32 i;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		const struct nlattr *u32_attr =
			lean_original_nla_find(head, len, LEAN_BENCH_ATTR_U32);
		const struct nlattr *str_attr =
			lean_original_nla_find(head, len, LEAN_BENCH_ATTR_STR);

		lean_nlattr_bench_sink += (uintptr_t)u32_attr;
		lean_nlattr_bench_sink += lean_original_nla_strscpy(buf, str_attr,
								    sizeof(buf));
		lean_nlattr_bench_sink += lean_original_nla_strcmp(str_attr, "lean");
		lean_nlattr_bench_sink += lean_original_nla_memcpy(&word, u32_attr,
								   sizeof(word));
		lean_nlattr_bench_sink += lean_original_nla_memcmp(u32_attr, &word,
								   sizeof(word));
		lean_nlattr_bench_sink +=
			lean_original_nla_policy_len(lean_nlattr_benchmark_policy,
						     ARRAY_SIZE(lean_nlattr_benchmark_policy));
	}

	return ktime_get_ns() - start;
}

static u64 __init lean_nlattr_benchmark_helpers_lean(const struct nlattr *head,
						     int len)
{
	char buf[8];
	u32 word;
	u64 start = ktime_get_ns();
	u32 i;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		const struct nlattr *u32_attr =
			nla_find(head, len, LEAN_BENCH_ATTR_U32);
		const struct nlattr *str_attr =
			nla_find(head, len, LEAN_BENCH_ATTR_STR);

		lean_nlattr_bench_sink += (uintptr_t)u32_attr;
		lean_nlattr_bench_sink += nla_strscpy(buf, str_attr, sizeof(buf));
		lean_nlattr_bench_sink += nla_strcmp(str_attr, "lean");
		lean_nlattr_bench_sink += nla_memcpy(&word, u32_attr, sizeof(word));
		lean_nlattr_bench_sink += nla_memcmp(u32_attr, &word, sizeof(word));
		lean_nlattr_bench_sink +=
			nla_policy_len(lean_nlattr_benchmark_policy,
				       ARRAY_SIZE(lean_nlattr_benchmark_policy));
	}

	return ktime_get_ns() - start;
}

static u64 __init lean_nlattr_benchmark_helpers_large_c(
	const struct nlattr *head, int len)
{
	char buf[96];
	u8 copy[64];
	u64 start = ktime_get_ns();
	u32 i;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		const struct nlattr *bin_attr =
			lean_original_nla_find(head, len, LEAN_BENCH_ATTR_BIN);
		const struct nlattr *str_attr =
			lean_original_nla_find(head, len, LEAN_BENCH_ATTR_STR);

		lean_nlattr_bench_sink += (uintptr_t)bin_attr;
		lean_nlattr_bench_sink += lean_original_nla_strscpy(buf, str_attr,
								    sizeof(buf));
		lean_nlattr_bench_sink += lean_original_nla_strcmp(str_attr,
			lean_nlattr_benchmark_long_string);
		lean_nlattr_bench_sink += lean_original_nla_memcpy(copy, bin_attr,
								   sizeof(copy));
		lean_nlattr_bench_sink += lean_original_nla_memcmp(bin_attr, copy,
								   sizeof(copy));
	}

	return ktime_get_ns() - start;
}

static u64 __init lean_nlattr_benchmark_helpers_large_lean(
	const struct nlattr *head, int len)
{
	char buf[96];
	u8 copy[64];
	u64 start = ktime_get_ns();
	u32 i;

	for (i = 0; i < LEAN_NLATTR_BENCH_ITERS; i++) {
		const struct nlattr *bin_attr =
			nla_find(head, len, LEAN_BENCH_ATTR_BIN);
		const struct nlattr *str_attr =
			nla_find(head, len, LEAN_BENCH_ATTR_STR);

		lean_nlattr_bench_sink += (uintptr_t)bin_attr;
		lean_nlattr_bench_sink += nla_strscpy(buf, str_attr, sizeof(buf));
		lean_nlattr_bench_sink += nla_strcmp(str_attr,
			lean_nlattr_benchmark_long_string);
		lean_nlattr_bench_sink += nla_memcpy(copy, bin_attr, sizeof(copy));
		lean_nlattr_bench_sink += nla_memcmp(bin_attr, copy,
						     sizeof(copy));
	}

	return ktime_get_ns() - start;
}

static void __init lean_nlattr_benchmark_report(const char *name, u64 c_ns,
						u64 lean_ns)
{
	u64 c_per = div64_u64(c_ns, LEAN_NLATTR_BENCH_ITERS);
	u64 lean_per = div64_u64(lean_ns, LEAN_NLATTR_BENCH_ITERS);
	u64 pct = c_ns ? div64_u64(lean_ns * 100, c_ns) : 0;

	pr_info("lean-nlattr: benchmark %s iterations=%u rounds=%u c_best_ns=%llu lean_best_ns=%llu c_best_ns_per=%llu lean_best_ns_per=%llu lean_best_pct=%llu\n",
		name, LEAN_NLATTR_BENCH_ITERS, LEAN_NLATTR_BENCH_ROUNDS,
		c_ns, lean_ns, c_per, lean_per, pct);
}

static void __init lean_nlattr_benchmark_report_median(const char *name,
						       u64 c_ns, u64 lean_ns)
{
	u64 c_per = div64_u64(c_ns, LEAN_NLATTR_BENCH_ITERS);
	u64 lean_per = div64_u64(lean_ns, LEAN_NLATTR_BENCH_ITERS);
	u64 pct = c_ns ? div64_u64(lean_ns * 100, c_ns) : 0;

	pr_info("lean-nlattr: benchmark-median %s iterations=%u rounds=%u c_median_ns=%llu lean_median_ns=%llu c_median_ns_per=%llu lean_median_ns_per=%llu lean_median_pct=%llu\n",
		name, LEAN_NLATTR_BENCH_ITERS, LEAN_NLATTR_BENCH_ROUNDS,
		c_ns, lean_ns, c_per, lean_per, pct);
}

static void __init lean_nlattr_benchmark_report_round(const char *name,
						      u32 round,
						      const char *first,
						      u64 c_ns, u64 lean_ns)
{
	u64 pct = c_ns ? div64_u64(lean_ns * 100, c_ns) : 0;

	pr_info("lean-nlattr: benchmark-round %s round=%u first=%s c_ns=%llu lean_ns=%llu lean_pct=%llu\n",
		name, round, first, c_ns, lean_ns, pct);
}

static u64 __init lean_nlattr_benchmark_min_sample(const u64 *samples, u32 n)
{
	u64 best = ~0ULL;
	u32 i;

	for (i = 0; i < n; i++) {
		if (samples[i] < best)
			best = samples[i];
	}

	return best;
}

static u64 __init lean_nlattr_benchmark_median_sample(u64 *samples, u32 n)
{
	u32 i, j;

	for (i = 1; i < n; i++) {
		u64 value = samples[i];

		for (j = i; j > 0 && samples[j - 1] > value; j--)
			samples[j] = samples[j - 1];
		samples[j] = value;
	}

	return samples[n / 2];
}

static void __init lean_nlattr_benchmark_report_samples(const char *name,
							u64 *c_samples,
							u64 *lean_samples,
							u32 rounds)
{
	lean_nlattr_benchmark_report(name,
				     lean_nlattr_benchmark_min_sample(c_samples,
								      rounds),
				     lean_nlattr_benchmark_min_sample(lean_samples,
								      rounds));
	lean_nlattr_benchmark_report_median(name,
					    lean_nlattr_benchmark_median_sample(
						    c_samples, rounds),
					    lean_nlattr_benchmark_median_sample(
						    lean_samples, rounds));
}

static void __init lean_nlattr_benchmark_compare_parse(
	const struct nlattr *head, int len)
{
	u64 c_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u64 lean_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u32 round;

	for (round = 0; round < LEAN_NLATTR_BENCH_ROUNDS; round++) {
		if (round & 1) {
			lean_samples[round] =
				lean_nlattr_benchmark_parse(__nla_parse, head,
							    len);
			c_samples[round] =
				lean_nlattr_benchmark_parse(
					lean_original___nla_parse, head, len);
			lean_nlattr_benchmark_report_round(
				"parse", round, "lean", c_samples[round],
				lean_samples[round]);
		} else {
			c_samples[round] =
				lean_nlattr_benchmark_parse(
					lean_original___nla_parse, head, len);
			lean_samples[round] =
				lean_nlattr_benchmark_parse(__nla_parse, head,
							    len);
			lean_nlattr_benchmark_report_round(
				"parse", round, "c", c_samples[round],
				lean_samples[round]);
		}
	}

	lean_nlattr_benchmark_report_samples("parse", c_samples, lean_samples,
					     LEAN_NLATTR_BENCH_ROUNDS);
}

static void __init lean_nlattr_benchmark_compare_validate(
	const struct nlattr *head, int len)
{
	u64 c_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u64 lean_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u32 round;

	for (round = 0; round < LEAN_NLATTR_BENCH_ROUNDS; round++) {
		if (round & 1) {
			lean_samples[round] =
				lean_nlattr_benchmark_validate(__nla_validate,
							       head, len);
			c_samples[round] =
				lean_nlattr_benchmark_validate(
					lean_original___nla_validate, head, len);
			lean_nlattr_benchmark_report_round(
				"validate", round, "lean", c_samples[round],
				lean_samples[round]);
		} else {
			c_samples[round] =
				lean_nlattr_benchmark_validate(
					lean_original___nla_validate, head, len);
			lean_samples[round] =
				lean_nlattr_benchmark_validate(__nla_validate,
							       head, len);
			lean_nlattr_benchmark_report_round(
				"validate", round, "c", c_samples[round],
				lean_samples[round]);
		}
	}

	lean_nlattr_benchmark_report_samples("validate", c_samples,
					     lean_samples,
					     LEAN_NLATTR_BENCH_ROUNDS);
}

static void __init lean_nlattr_benchmark_compare_helpers(
	const char *name, lean_bench_helper_fn c_fn, lean_bench_helper_fn lean_fn,
	const struct nlattr *head, int len)
{
	u64 c_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u64 lean_samples[LEAN_NLATTR_BENCH_ROUNDS];
	u32 round;

	for (round = 0; round < LEAN_NLATTR_BENCH_ROUNDS; round++) {
		if (round & 1) {
			lean_samples[round] = lean_fn(head, len);
			c_samples[round] = c_fn(head, len);
			lean_nlattr_benchmark_report_round(
				name, round, "lean", c_samples[round],
				lean_samples[round]);
		} else {
			c_samples[round] = c_fn(head, len);
			lean_samples[round] = lean_fn(head, len);
			lean_nlattr_benchmark_report_round(
				name, round, "c", c_samples[round],
				lean_samples[round]);
		}
	}

	lean_nlattr_benchmark_report_samples(name, c_samples, lean_samples,
					     LEAN_NLATTR_BENCH_ROUNDS);
}

static void __init lean_nlattr_benchmark_count_one(const struct nlattr *head,
						   int len)
{
	struct nlattr *tb[LEAN_BENCH_ATTR_MAX + 1];
	const struct nlattr *u32_attr;
	const struct nlattr *str_attr;
	char buf[8];
	u32 word;

	lean_nlattr_trace_counts_reset();
	lean_nlattr_trace_counts_enable(true);
	__nla_parse(tb, LEAN_BENCH_ATTR_MAX, head, len,
		    lean_nlattr_benchmark_policy, NL_VALIDATE_STRICT, NULL);
	lean_nlattr_trace_counts_enable(false);
	lean_nlattr_trace_counts_report("parse-one");

	lean_nlattr_trace_counts_reset();
	lean_nlattr_trace_counts_enable(true);
	__nla_validate(head, len, LEAN_BENCH_ATTR_MAX,
		       lean_nlattr_benchmark_policy, NL_VALIDATE_STRICT, NULL);
	lean_nlattr_trace_counts_enable(false);
	lean_nlattr_trace_counts_report("validate-one");

	lean_nlattr_trace_counts_reset();
	lean_nlattr_trace_counts_enable(true);
	u32_attr = nla_find(head, len, LEAN_BENCH_ATTR_U32);
	str_attr = nla_find(head, len, LEAN_BENCH_ATTR_STR);
	lean_nlattr_bench_sink += (uintptr_t)u32_attr;
	lean_nlattr_bench_sink += nla_strscpy(buf, str_attr, sizeof(buf));
	lean_nlattr_bench_sink += nla_strcmp(str_attr, "lean");
	lean_nlattr_bench_sink += nla_memcpy(&word, u32_attr, sizeof(word));
	lean_nlattr_bench_sink += nla_memcmp(u32_attr, &word, sizeof(word));
	lean_nlattr_bench_sink +=
		nla_policy_len(lean_nlattr_benchmark_policy,
			       ARRAY_SIZE(lean_nlattr_benchmark_policy));
	lean_nlattr_trace_counts_enable(false);
	lean_nlattr_trace_counts_report("helpers-one");
	lean_nlattr_trace_counts_reset();
}

static int __init lean_nlattr_benchmark_init(void)
{
	u8 stream[128] __aligned(NLA_ALIGNTO);
	size_t len = lean_nlattr_benchmark_make_stream(stream, sizeof(stream));
	const struct nlattr *head = (const struct nlattr *)stream;
	u8 helper_large_stream[256] __aligned(NLA_ALIGNTO);
	size_t helper_large_len =
		lean_nlattr_benchmark_make_helper_large_stream(
			helper_large_stream, sizeof(helper_large_stream));
	const struct nlattr *helper_large_head =
		(const struct nlattr *)helper_large_stream;
	int ret;

	ret = lean_nlattr_benchmark_check_helpers(head, (int)len);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_check_helpers_large(helper_large_head,
							(int)helper_large_len);
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_check_policy_values();
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_check_edges();
	if (ret)
		return ret;
	ret = lean_nlattr_benchmark_check_nested();
	if (ret)
		return ret;

	pr_info("lean-nlattr: benchmark-note iterations=%u rounds=%u order=alternating summary=best,median scope=qemu-microbenchmark\n",
		LEAN_NLATTR_BENCH_ITERS, LEAN_NLATTR_BENCH_ROUNDS);
	pr_info("lean-nlattr: benchmark-note helpers=lean-exports counts=effect-hook-scope\n");

	lean_nlattr_benchmark_count_one(head, (int)len);

	lean_nlattr_benchmark_compare_parse(head, (int)len);
	lean_nlattr_benchmark_compare_validate(head, (int)len);
	lean_nlattr_benchmark_compare_helpers("helpers",
					      lean_nlattr_benchmark_helpers_c,
					      lean_nlattr_benchmark_helpers_lean,
					      head, (int)len);
	lean_nlattr_benchmark_compare_helpers(
		"helpers-large", lean_nlattr_benchmark_helpers_large_c,
		lean_nlattr_benchmark_helpers_large_lean, helper_large_head,
		(int)helper_large_len);

	pr_info("lean-nlattr: benchmark PASS sink=%llu\n", lean_nlattr_bench_sink);
	return 0;
}
late_initcall(lean_nlattr_benchmark_init);
