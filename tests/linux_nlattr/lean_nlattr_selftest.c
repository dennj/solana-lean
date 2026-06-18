// SPDX-License-Identifier: GPL-2.0

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/limits.h>
#include <linux/skbuff.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/types.h>
#include <net/netlink.h>

enum {
	LEAN_SELFTEST_ATTR_STR = 1,
	LEAN_SELFTEST_ATTR_U32 = 2,
	LEAN_SELFTEST_ATTR_FLAG = 3,
	LEAN_SELFTEST_ATTR_BIN = 4,
	LEAN_SELFTEST_ATTR_MAX = 4,
};

enum {
	LEAN_SELFTEST_POLICY_U8 = 1,
	LEAN_SELFTEST_POLICY_S8 = 2,
	LEAN_SELFTEST_POLICY_BE16 = 3,
	LEAN_SELFTEST_POLICY_UINT = 4,
	LEAN_SELFTEST_POLICY_SINT = 5,
	LEAN_SELFTEST_POLICY_BINARY = 6,
	LEAN_SELFTEST_POLICY_VALIDATE = 7,
	LEAN_SELFTEST_POLICY_MAX = 7,
};

enum {
	LEAN_SELFTEST_EDGE_U32 = 1,
	LEAN_SELFTEST_EDGE_NESTED = 2,
	LEAN_SELFTEST_EDGE_REJECT = 3,
	LEAN_SELFTEST_EDGE_BITFIELD = 4,
	LEAN_SELFTEST_EDGE_STRING = 5,
	LEAN_SELFTEST_EDGE_NUL_STRING = 6,
	LEAN_SELFTEST_EDGE_CALLBACK = 7,
	LEAN_SELFTEST_EDGE_MAX = 7,
};

enum {
	LEAN_SELFTEST_NESTED_VALUE = 1,
	LEAN_SELFTEST_NESTED_MAX = 1,
};

enum {
	LEAN_SELFTEST_OUTER_NESTED = 1,
	LEAN_SELFTEST_OUTER_ARRAY = 2,
	LEAN_SELFTEST_OUTER_MAX = 2,
};

static int __init lean_nlattr_selftest_fail(const char *name)
{
	pr_err("lean-nlattr: selftest FAIL %s\n", name);
	return -EINVAL;
}

static void __init lean_nlattr_selftest_put_attr(u8 *buf, size_t *off,
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

static int __init lean_nlattr_selftest_validate_ok(const struct nlattr *nla,
						   struct netlink_ext_ack *extack)
{
	return nla_len(nla) == sizeof(u8) ? 0 : -EINVAL;
}

static int __init lean_nlattr_selftest_validate_eperm(const struct nlattr *nla,
						      struct netlink_ext_ack *extack)
{
	return -EPERM;
}

static int __init lean_nlattr_selftest_validate_stream(const char *name,
						       const struct nla_policy *policy,
						       int maxtype,
						       const void *stream,
						       int len,
						       unsigned int validate,
						       int expected)
{
	int ret;

	ret = __nla_validate((const struct nlattr *)stream, len, maxtype,
			     policy, validate, NULL);
	if (ret != expected) {
		pr_err("lean-nlattr: selftest expected %s=%d got %d\n",
		       name, expected, ret);
		return lean_nlattr_selftest_fail(name);
	}

	return 0;
}

static int __init lean_nlattr_selftest_validate_one(const char *name,
						    const struct nla_policy *policy,
						    int maxtype, u16 type,
						    const void *data, size_t len,
						    unsigned int validate,
						    int expected)
{
	char stream[128] __aligned(NLA_ALIGNTO);
	size_t off = 0;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, type, data, len);

	return lean_nlattr_selftest_validate_stream(name, policy, maxtype,
						    stream, (int)off, validate,
						    expected);
}

static int __init lean_nlattr_selftest_extack_stream(const char *name,
						     const struct nla_policy *policy,
						     int maxtype,
						     const void *stream,
						     int len,
						     unsigned int validate,
						     int expected,
						     const char *message,
						     const struct nlattr *bad_attr,
						     const struct nla_policy *bad_policy)
{
	struct netlink_ext_ack extack = {};
	int ret;

	ret = __nla_validate((const struct nlattr *)stream, len, maxtype,
			     policy, validate, &extack);
	if (ret != expected) {
		pr_err("lean-nlattr: selftest expected %s=%d got %d\n",
		       name, expected, ret);
		return lean_nlattr_selftest_fail(name);
	}

	if (!extack._msg || strcmp(extack._msg, message)) {
		pr_err("lean-nlattr: selftest expected %s message %s got %s\n",
		       name, message, extack._msg ? extack._msg : "<null>");
		return lean_nlattr_selftest_fail(name);
	}
	if (extack.bad_attr != bad_attr) {
		pr_err("lean-nlattr: selftest expected %s bad_attr %px got %px\n",
		       name, (const void *)bad_attr,
		       (const void *)extack.bad_attr);
		return lean_nlattr_selftest_fail(name);
	}
	if (extack.policy != bad_policy) {
		pr_err("lean-nlattr: selftest expected %s policy %px got %px\n",
		       name, (const void *)bad_policy,
		       (const void *)extack.policy);
		return lean_nlattr_selftest_fail(name);
	}

	return 0;
}

static int __init lean_nlattr_selftest_extack_one(const char *name,
						  const struct nla_policy *policy,
						  int maxtype, u16 type,
						  const void *data, size_t len,
						  unsigned int validate,
						  int expected,
						  const char *message,
						  bool expect_policy)
{
	char stream[128] __aligned(NLA_ALIGNTO);
	const struct nlattr *attr;
	const struct nla_policy *bad_policy = NULL;
	size_t off = 0;
	u16 policy_type;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, type, data, len);

	attr = (const struct nlattr *)stream;
	policy_type = type & NLA_TYPE_MASK;
	if (expect_policy)
		bad_policy = &policy[policy_type];

	return lean_nlattr_selftest_extack_stream(name, policy, maxtype,
						  stream, (int)off, validate,
						  expected, message, attr,
						  bad_policy);
}

static int __init lean_nlattr_selftest_no_extack_one(const char *name,
						     const struct nla_policy *policy,
						     int maxtype, u16 type,
						     const void *data, size_t len,
						     unsigned int validate,
						     int expected)
{
	char stream[128] __aligned(NLA_ALIGNTO);
	struct netlink_ext_ack extack = {};
	size_t off = 0;
	int ret;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, type, data, len);

	ret = __nla_validate((const struct nlattr *)stream, (int)off, maxtype,
			     policy, validate, &extack);
	if (ret != expected) {
		pr_err("lean-nlattr: selftest expected %s=%d got %d\n",
		       name, expected, ret);
		return lean_nlattr_selftest_fail(name);
	}
	if (extack._msg || extack.bad_attr || extack.policy) {
		pr_err("lean-nlattr: selftest expected %s empty extack\n",
		       name);
		return lean_nlattr_selftest_fail(name);
	}

	return 0;
}

static int __init lean_nlattr_selftest_helpers(void)
{
	static const struct nla_policy policy[LEAN_SELFTEST_ATTR_MAX + 1] = {
		[LEAN_SELFTEST_ATTR_STR] = {
			.type = NLA_NUL_STRING,
			.len = 8,
		},
		[LEAN_SELFTEST_ATTR_U32] = {
			.type = NLA_U32,
		},
		[LEAN_SELFTEST_ATTR_FLAG] = {
			.type = NLA_FLAG,
		},
		[LEAN_SELFTEST_ATTR_BIN] = {
			.type = NLA_BINARY,
			.len = 3,
		},
	};
	const char str_payload[] = "lean";
	const u8 bin_payload[] = { 0xa1, 0xb2, 0xc3 };
	u32 word = 0x11223344;
	struct nlattr *tb[LEAN_SELFTEST_ATTR_MAX + 1];
	char stream[128] __aligned(NLA_ALIGNTO);
	char small[8];
	char *dup;
	u32 copied = 0;
	size_t off = 0;
	int ret;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_ATTR_STR,
				      str_payload, sizeof(str_payload));
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_ATTR_U32,
				      &word, sizeof(word));
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_ATTR_FLAG,
				      NULL, 0);
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_ATTR_BIN,
				      bin_payload, sizeof(bin_payload));

	ret = __nla_parse(tb, LEAN_SELFTEST_ATTR_MAX,
			  (const struct nlattr *)stream, (int)off, policy,
			  NL_VALIDATE_STRICT, NULL);
	if (ret)
		return lean_nlattr_selftest_fail("__nla_parse");

	ret = __nla_validate((const struct nlattr *)stream, (int)off,
			     LEAN_SELFTEST_ATTR_MAX, policy,
			     NL_VALIDATE_STRICT, NULL);
	if (ret)
		return lean_nlattr_selftest_fail("__nla_validate");

	if (!tb[LEAN_SELFTEST_ATTR_STR] || !tb[LEAN_SELFTEST_ATTR_U32] ||
	    !tb[LEAN_SELFTEST_ATTR_FLAG] || !tb[LEAN_SELFTEST_ATTR_BIN])
		return lean_nlattr_selftest_fail("parse-table");

	if (nla_find((const struct nlattr *)stream, (int)off,
		     LEAN_SELFTEST_ATTR_U32) != tb[LEAN_SELFTEST_ATTR_U32])
		return lean_nlattr_selftest_fail("nla_find");

	memset(small, 0x5a, sizeof(small));
	ret = nla_strscpy(small, tb[LEAN_SELFTEST_ATTR_STR], sizeof(small));
	if (ret != 4 || strcmp(small, "lean"))
		return lean_nlattr_selftest_fail("nla_strscpy");

	if (nla_strcmp(tb[LEAN_SELFTEST_ATTR_STR], "lean"))
		return lean_nlattr_selftest_fail("nla_strcmp");

	dup = nla_strdup(tb[LEAN_SELFTEST_ATTR_STR], GFP_KERNEL);
	if (!dup)
		return lean_nlattr_selftest_fail("nla_strdup-alloc");
	ret = strcmp(dup, "lean");
	kfree(dup);
	if (ret)
		return lean_nlattr_selftest_fail("nla_strdup");

	if (nla_memcmp(tb[LEAN_SELFTEST_ATTR_U32], &word, sizeof(word)))
		return lean_nlattr_selftest_fail("nla_memcmp");

	ret = nla_memcpy(&copied, tb[LEAN_SELFTEST_ATTR_U32], sizeof(copied));
	if (ret != sizeof(copied) || copied != word)
		return lean_nlattr_selftest_fail("nla_memcpy");

	if (nla_policy_len(policy, ARRAY_SIZE(policy)) <= 0)
		return lean_nlattr_selftest_fail("nla_policy_len");

	return 0;
}

static int __init lean_nlattr_selftest_policy_values(void)
{
	const struct netlink_range_validation uint_range = {
		.min = 65000,
		.max = 70000,
	};
	const struct netlink_range_validation_signed sint_range = {
		.min = -10,
		.max = -1,
	};
	struct nla_policy policy[LEAN_SELFTEST_POLICY_MAX + 1] = {
		[LEAN_SELFTEST_POLICY_U8] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_RANGE,
			.min = 5,
			.max = 9,
		},
		[LEAN_SELFTEST_POLICY_S8] = {
			.type = NLA_S8,
			.validation_type = NLA_VALIDATE_RANGE,
			.min = -10,
			.max = -1,
		},
		[LEAN_SELFTEST_POLICY_BE16] = {
			.type = NLA_BE16,
			.validation_type = NLA_VALIDATE_MAX,
			.max = 0x1300,
		},
		[LEAN_SELFTEST_POLICY_UINT] = {
			.type = NLA_UINT,
			.validation_type = NLA_VALIDATE_RANGE_PTR,
			.range = &uint_range,
		},
		[LEAN_SELFTEST_POLICY_SINT] = {
			.type = NLA_SINT,
			.validation_type = NLA_VALIDATE_RANGE_PTR,
			.range_signed = &sint_range,
		},
		[LEAN_SELFTEST_POLICY_BINARY] = {
			.type = NLA_BINARY,
			.validation_type = NLA_VALIDATE_RANGE_WARN_TOO_LONG,
			.min = 4,
			.max = 4,
		},
		[LEAN_SELFTEST_POLICY_VALIDATE] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_FUNCTION,
			.validate = lean_nlattr_selftest_validate_ok,
		},
	};
	const struct nla_policy mask_policy[LEAN_SELFTEST_POLICY_MAX + 1] = {
		[LEAN_SELFTEST_POLICY_U8] = {
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

	ret = lean_nlattr_selftest_validate_one("u8-range-ok", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_U8,
						&u8_ok, sizeof(u8_ok),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("u8-range-bad", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_U8,
						&u8_bad, sizeof(u8_bad),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("u8-mask-ok", mask_policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_U8,
						&u8_ok, sizeof(u8_ok),
						0, 0);
	if (ret)
		return ret;
	u8_bad = 0x80;
	ret = lean_nlattr_selftest_validate_one("u8-mask-bad", mask_policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_U8,
						&u8_bad, sizeof(u8_bad),
						0, -EINVAL);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("s8-range-ok", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_S8,
						&s8_ok, sizeof(s8_ok),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("s8-range-bad", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_S8,
						&s8_bad, sizeof(s8_bad),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("be16-max-ok", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_BE16,
						be16_ok, sizeof(be16_ok),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("be16-max-bad", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_BE16,
						be16_bad, sizeof(be16_bad),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("uint-range-ptr-ok", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_UINT,
						&uint_ok, sizeof(uint_ok),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("uint-range-ptr-bad", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_UINT,
						&uint_bad, sizeof(uint_bad),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("sint-range-ptr-ok", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_SINT,
						&sint_ok, sizeof(sint_ok),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("sint-range-ptr-bad", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_SINT,
						&sint_bad, sizeof(sint_bad),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("binary-warn-long", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_BINARY,
						binary_long, sizeof(binary_long),
						0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("binary-warn-long-strict",
						policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_BINARY,
						binary_long, sizeof(binary_long),
						NL_VALIDATE_STRICT_ATTRS,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("binary-warn-short", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_BINARY,
						binary_short, sizeof(binary_short),
						0, -ERANGE);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("validate-fn", policy,
						LEAN_SELFTEST_POLICY_MAX,
						LEAN_SELFTEST_POLICY_VALIDATE,
						&u8_ok, sizeof(u8_ok),
						0, 0);
	if (ret)
		return ret;

	pr_info("lean-nlattr: selftest PASS policy-values\n");
	return 0;
}

static int __init lean_nlattr_selftest_nested(void)
{
	const struct nla_policy nested_policy[LEAN_SELFTEST_NESTED_MAX + 1] = {
		[LEAN_SELFTEST_NESTED_VALUE] = {
			.type = NLA_U32,
		},
	};
	const struct nla_policy outer_policy[LEAN_SELFTEST_OUTER_MAX + 1] = {
		[LEAN_SELFTEST_OUTER_NESTED] =
			NLA_POLICY_NESTED(nested_policy),
		[LEAN_SELFTEST_OUTER_ARRAY] =
			NLA_POLICY_NESTED_ARRAY(nested_policy),
	};
	u32 word = 0x01020304;
	u16 too_short = 0x0102;
	char nested_payload[64] __aligned(NLA_ALIGNTO);
	char nested_bad_payload[64] __aligned(NLA_ALIGNTO);
	char array_payload[96] __aligned(NLA_ALIGNTO);
	char outer_stream[160] __aligned(NLA_ALIGNTO);
	size_t nested_off = 0;
	size_t nested_bad_off = 0;
	size_t array_off = 0;
	size_t outer_off = 0;
	int ret;

	memset(nested_payload, 0, sizeof(nested_payload));
	memset(nested_bad_payload, 0, sizeof(nested_bad_payload));
	memset(array_payload, 0, sizeof(array_payload));
	memset(outer_stream, 0, sizeof(outer_stream));

	lean_nlattr_selftest_put_attr(nested_payload, &nested_off,
				      LEAN_SELFTEST_NESTED_VALUE, &word,
				      sizeof(word));
	lean_nlattr_selftest_put_attr(outer_stream, &outer_off,
				      LEAN_SELFTEST_OUTER_NESTED | NLA_F_NESTED,
				      nested_payload, nested_off);
	ret = __nla_validate((const struct nlattr *)outer_stream, (int)outer_off,
			     LEAN_SELFTEST_OUTER_MAX, outer_policy,
			     NL_VALIDATE_STRICT, NULL);
	if (ret)
		return lean_nlattr_selftest_fail("nested-policy-ok");

	lean_nlattr_selftest_put_attr(nested_bad_payload, &nested_bad_off,
				      LEAN_SELFTEST_NESTED_VALUE, &too_short,
				      sizeof(too_short));
	outer_off = 0;
	memset(outer_stream, 0, sizeof(outer_stream));
	lean_nlattr_selftest_put_attr(outer_stream, &outer_off,
				      LEAN_SELFTEST_OUTER_NESTED | NLA_F_NESTED,
				      nested_bad_payload, nested_bad_off);
	ret = __nla_validate((const struct nlattr *)outer_stream, (int)outer_off,
			     LEAN_SELFTEST_OUTER_MAX, outer_policy,
			     NL_VALIDATE_STRICT, NULL);
	if (ret != -EINVAL)
		return lean_nlattr_selftest_fail("nested-policy-bad");

	lean_nlattr_selftest_put_attr(array_payload, &array_off, 1,
				      nested_payload, nested_off);
	outer_off = 0;
	memset(outer_stream, 0, sizeof(outer_stream));
	lean_nlattr_selftest_put_attr(outer_stream, &outer_off,
				      LEAN_SELFTEST_OUTER_ARRAY | NLA_F_NESTED,
				      array_payload, array_off);
	ret = __nla_validate((const struct nlattr *)outer_stream, (int)outer_off,
			     LEAN_SELFTEST_OUTER_MAX, outer_policy,
			     NL_VALIDATE_STRICT, NULL);
	if (ret)
		return lean_nlattr_selftest_fail("nested-array-ok");

	pr_info("lean-nlattr: selftest PASS nested\n");
	return 0;
}

static int __init lean_nlattr_selftest_edges(void)
{
	const struct nla_policy edge_policy[LEAN_SELFTEST_EDGE_MAX + 1] = {
		[LEAN_SELFTEST_EDGE_U32] = {
			.type = NLA_U32,
		},
		[LEAN_SELFTEST_EDGE_NESTED] = {
			.type = NLA_NESTED,
		},
		[LEAN_SELFTEST_EDGE_REJECT] = {
			.type = NLA_REJECT,
		},
		[LEAN_SELFTEST_EDGE_BITFIELD] =
			NLA_POLICY_BITFIELD32(0x0f),
		[LEAN_SELFTEST_EDGE_STRING] = {
			.type = NLA_STRING,
			.len = 3,
		},
		[LEAN_SELFTEST_EDGE_NUL_STRING] = {
			.type = NLA_NUL_STRING,
			.len = 8,
		},
		[LEAN_SELFTEST_EDGE_CALLBACK] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_FUNCTION,
			.validate = lean_nlattr_selftest_validate_eperm,
		},
	};
	const struct nla_policy strict_start_policy[LEAN_SELFTEST_EDGE_U32 + 1] = {
		[0] = {
			.strict_start_type = LEAN_SELFTEST_EDGE_U32,
		},
		[LEAN_SELFTEST_EDGE_U32] = {
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
	char stream[128] __aligned(NLA_ALIGNTO);
	size_t off = 0;
	int ret;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_EDGE_U32,
				      &word, sizeof(word));
	ret = lean_nlattr_selftest_validate_stream("tail-liberal", edge_policy,
						   LEAN_SELFTEST_EDGE_MAX,
						   stream, (int)off + 1, 0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_stream("tail-strict", edge_policy,
						   LEAN_SELFTEST_EDGE_MAX,
						   stream, (int)off + 1,
						   NL_VALIDATE_TRAILING,
						   -EINVAL);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("maxtype-liberal", edge_policy,
						LEAN_SELFTEST_EDGE_U32,
						LEAN_SELFTEST_EDGE_U32 + 1,
						NULL, 0, 0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("maxtype-strict", edge_policy,
						LEAN_SELFTEST_EDGE_U32,
						LEAN_SELFTEST_EDGE_U32 + 1,
						NULL, 0, NL_VALIDATE_MAXTYPE,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("type-zero-strict", edge_policy,
						LEAN_SELFTEST_EDGE_MAX, 0,
						NULL, 0, NL_VALIDATE_MAXTYPE,
						-EINVAL);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("strict-start", strict_start_policy,
						LEAN_SELFTEST_EDGE_U32,
						LEAN_SELFTEST_EDGE_U32,
						&wide, sizeof(wide), 0,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("nested-flag-missing", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_NESTED,
						NULL, 0, NL_VALIDATE_NESTED,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("nested-flag-unexpected",
						edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_U32 |
							NLA_F_NESTED,
						&word, sizeof(word),
						NL_VALIDATE_NESTED, -EINVAL);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_validate_one("reject", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_REJECT,
						NULL, 0, 0, -EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("bitfield-ok", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_BITFIELD,
						&bitfield_ok,
						sizeof(bitfield_ok), 0, 0);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("bitfield-bad", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_BITFIELD,
						&bitfield_bad,
						sizeof(bitfield_bad), 0,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("string-too-long", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_STRING,
						string_too_long,
						sizeof(string_too_long) - 1,
						0, -ERANGE);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("nul-string-missing", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_NUL_STRING,
						nul_missing,
						sizeof(nul_missing), 0,
						-EINVAL);
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_validate_one("callback-eperm", edge_policy,
						LEAN_SELFTEST_EDGE_MAX,
						LEAN_SELFTEST_EDGE_CALLBACK,
						&byte, sizeof(byte), 0,
						-EPERM);
	if (ret)
		return ret;

	pr_info("lean-nlattr: selftest PASS edges\n");
	return 0;
}

static int __init lean_nlattr_selftest_extack(void)
{
	const struct netlink_range_validation uint_range = {
		.min = 65000,
		.max = 70000,
	};
	const struct nla_policy policy[LEAN_SELFTEST_POLICY_MAX + 1] = {
		[LEAN_SELFTEST_POLICY_U8] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_RANGE,
			.min = 5,
			.max = 9,
		},
		[LEAN_SELFTEST_POLICY_UINT] = {
			.type = NLA_UINT,
			.validation_type = NLA_VALIDATE_RANGE_PTR,
			.range = &uint_range,
		},
		[LEAN_SELFTEST_POLICY_BINARY] = {
			.type = NLA_BINARY,
			.validation_type = NLA_VALIDATE_RANGE_WARN_TOO_LONG,
			.min = 4,
			.max = 4,
		},
	};
	const struct nla_policy mask_policy[LEAN_SELFTEST_POLICY_MAX + 1] = {
		[LEAN_SELFTEST_POLICY_U8] = {
			.type = NLA_U8,
			.validation_type = NLA_VALIDATE_MASK,
			.mask = 0x0f,
		},
	};
	const struct nla_policy edge_policy[LEAN_SELFTEST_EDGE_MAX + 1] = {
		[LEAN_SELFTEST_EDGE_U32] = {
			.type = NLA_U32,
		},
		[LEAN_SELFTEST_EDGE_NESTED] = {
			.type = NLA_NESTED,
		},
		[LEAN_SELFTEST_EDGE_REJECT] = {
			.type = NLA_REJECT,
			.reject_message = "reject me",
		},
		[LEAN_SELFTEST_EDGE_BITFIELD] =
			NLA_POLICY_BITFIELD32(0x0f),
	};
	struct nla_bitfield32 bitfield_bad = {
		.value = 0x10,
		.selector = 0x10,
	};
	char stream[128] __aligned(NLA_ALIGNTO);
	size_t off = 0;
	u64 uint_bad = 80000;
	u32 word = 0x01020304;
	u8 u8_bad = 11;
	u8 u8_mask_bad = 0x80;
	u8 binary_long[] = { 1, 2, 3, 4, 5 };
	u8 binary_short[] = { 1, 2, 3 };
	int ret;

	ret = lean_nlattr_selftest_extack_one("extack-maxtype-strict",
					      edge_policy,
					      LEAN_SELFTEST_EDGE_U32,
					      LEAN_SELFTEST_EDGE_U32 + 1,
					      NULL, 0,
					      NL_VALIDATE_MAXTYPE, -EINVAL,
					      "Unknown attribute type",
					      false);
	if (ret)
		return ret;

	memset(stream, 0, sizeof(stream));
	lean_nlattr_selftest_put_attr(stream, &off, LEAN_SELFTEST_EDGE_U32,
				      &word, sizeof(word));
	ret = lean_nlattr_selftest_extack_stream("extack-tail-strict",
						 edge_policy,
						 LEAN_SELFTEST_EDGE_MAX,
						 stream, (int)off + 1,
						 NL_VALIDATE_TRAILING,
						 -EINVAL,
						 "bytes leftover after parsing attributes",
						 NULL, NULL);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-nested-missing",
					      edge_policy,
					      LEAN_SELFTEST_EDGE_MAX,
					      LEAN_SELFTEST_EDGE_NESTED,
					      NULL, 0, NL_VALIDATE_NESTED,
					      -EINVAL,
					      "NLA_F_NESTED is missing",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-nested-unexpected",
					      edge_policy,
					      LEAN_SELFTEST_EDGE_MAX,
					      LEAN_SELFTEST_EDGE_U32 |
						      NLA_F_NESTED,
					      &word, sizeof(word),
					      NL_VALIDATE_NESTED, -EINVAL,
					      "NLA_F_NESTED not expected",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-reject-message",
					      edge_policy,
					      LEAN_SELFTEST_EDGE_MAX,
					      LEAN_SELFTEST_EDGE_REJECT,
					      NULL, 0, 0, -EINVAL,
					      "reject me", false);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-bitfield",
					      edge_policy,
					      LEAN_SELFTEST_EDGE_MAX,
					      LEAN_SELFTEST_EDGE_BITFIELD,
					      &bitfield_bad,
					      sizeof(bitfield_bad), 0,
					      -EINVAL,
					      "Attribute failed policy validation",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-u8-mask", mask_policy,
					      LEAN_SELFTEST_POLICY_MAX,
					      LEAN_SELFTEST_POLICY_U8,
					      &u8_mask_bad,
					      sizeof(u8_mask_bad), 0,
					      -EINVAL, "reserved bit set",
					      false);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-u8-range", policy,
					      LEAN_SELFTEST_POLICY_MAX,
					      LEAN_SELFTEST_POLICY_U8,
					      &u8_bad, sizeof(u8_bad), 0,
					      -ERANGE, "integer out of range",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-uint-range-ptr",
					      policy,
					      LEAN_SELFTEST_POLICY_MAX,
					      LEAN_SELFTEST_POLICY_UINT,
					      &uint_bad, sizeof(uint_bad), 0,
					      -ERANGE, "integer out of range",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-binary-short",
					      policy,
					      LEAN_SELFTEST_POLICY_MAX,
					      LEAN_SELFTEST_POLICY_BINARY,
					      binary_short,
					      sizeof(binary_short), 0,
					      -ERANGE,
					      "binary attribute size out of range",
					      true);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_no_extack_one("extack-binary-long",
						 policy,
						 LEAN_SELFTEST_POLICY_MAX,
						 LEAN_SELFTEST_POLICY_BINARY,
						 binary_long,
						 sizeof(binary_long), 0, 0);
	if (ret)
		return ret;

	ret = lean_nlattr_selftest_extack_one("extack-binary-long-strict",
					      policy,
					      LEAN_SELFTEST_POLICY_MAX,
					      LEAN_SELFTEST_POLICY_BINARY,
					      binary_long,
					      sizeof(binary_long),
					      NL_VALIDATE_STRICT_ATTRS,
					      -EINVAL,
					      "invalid attribute length",
					      true);
	if (ret)
		return ret;

	pr_info("lean-nlattr: selftest PASS extack\n");
	return 0;
}

static int __init lean_nlattr_selftest_ranges(void)
{
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
	struct netlink_range_validation unsigned_range;
	struct netlink_range_validation_signed signed_range;

	nla_get_range_unsigned(&unsigned_policy, &unsigned_range);
	if (unsigned_range.min != 7 || unsigned_range.max != U32_MAX)
		return lean_nlattr_selftest_fail("nla_get_range_unsigned");

	nla_get_range_signed(&signed_policy, &signed_range);
	if (signed_range.min != S8_MIN || signed_range.max != 5)
		return lean_nlattr_selftest_fail("nla_get_range_signed");

	return 0;
}

static int __init lean_nlattr_selftest_builders(void)
{
	u64 wide = 0x0102030405060708ULL;
	u32 word = 0xaabbccdd;
	const char bytes[] = "xyz";
	struct sk_buff *skb;
	int ret = 0;

	skb = alloc_skb(512, GFP_KERNEL);
	if (!skb)
		return lean_nlattr_selftest_fail("alloc_skb");

	if (nla_put(skb, 10, sizeof(word), &word))
		ret = lean_nlattr_selftest_fail("nla_put");
	else if (nla_put_64bit(skb, 11, sizeof(wide), &wide, 255))
		ret = lean_nlattr_selftest_fail("nla_put_64bit");
	else if (nla_put_nohdr(skb, sizeof(bytes), bytes))
		ret = lean_nlattr_selftest_fail("nla_put_nohdr");
	else if (nla_append(skb, sizeof(bytes), bytes))
		ret = lean_nlattr_selftest_fail("nla_append");
	else if (!nla_reserve(skb, 12, sizeof(word)))
		ret = lean_nlattr_selftest_fail("nla_reserve");
	else if (!nla_reserve_64bit(skb, 13, sizeof(wide), 254))
		ret = lean_nlattr_selftest_fail("nla_reserve_64bit");
	else if (!nla_reserve_nohdr(skb, sizeof(bytes)))
		ret = lean_nlattr_selftest_fail("nla_reserve_nohdr");

	kfree_skb(skb);
	return ret;
}

static int __init lean_nlattr_selftest_init(void)
{
	int ret;

	pr_info("lean-nlattr: selftest BEGIN\n");

	ret = lean_nlattr_selftest_helpers();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_policy_values();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_nested();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_edges();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_extack();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_ranges();
	if (ret)
		return ret;
	ret = lean_nlattr_selftest_builders();
	if (ret)
		return ret;

	pr_info("lean-nlattr: selftest PASS helpers\n");
	return 0;
}
late_initcall(lean_nlattr_selftest_init);
