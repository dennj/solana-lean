#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lean/lean.h>

#define LEAN_KIND_UNSUPPORTED 0
#define LEAN_KIND_ACCEPT      1
#define LEAN_KIND_FLAG        2
#define LEAN_KIND_EXACT       3
#define LEAN_KIND_MIN         4
#define LEAN_KIND_RANGE       5
#define LEAN_KIND_REJECT      6
#define LEAN_KIND_STRING      7
#define LEAN_KIND_NUL_STRING  8
#define LEAN_KIND_BITFIELD32  9
#define LEAN_KIND_INT32_OR64  10
#define LEAN_KIND_NESTED      11
#define LEAN_KIND_NESTED_POLICY 12
#define LEAN_KIND_NESTED_ARRAY_POLICY 13

#define LEAN_VALUE_NONE              0
#define LEAN_VALUE_UNSIGNED8         1
#define LEAN_VALUE_UNSIGNED16        2
#define LEAN_VALUE_UNSIGNED32        3
#define LEAN_VALUE_UNSIGNED64        4
#define LEAN_VALUE_UNSIGNED32_OR64   5
#define LEAN_VALUE_MSECS             6
#define LEAN_VALUE_BIG_UNSIGNED16    7
#define LEAN_VALUE_BIG_UNSIGNED32    8
#define LEAN_VALUE_SIGNED8           9
#define LEAN_VALUE_SIGNED16          10
#define LEAN_VALUE_SIGNED32          11
#define LEAN_VALUE_SIGNED64          12
#define LEAN_VALUE_SIGNED32_OR64     13
#define LEAN_VALUE_BINARY_LEN        14

#define HOST_NLA_UNSPEC      0
#define HOST_NLA_U8          1
#define HOST_NLA_U16         2
#define HOST_NLA_U32         3
#define HOST_NLA_U64         4
#define HOST_NLA_STRING      5
#define HOST_NLA_FLAG        6
#define HOST_NLA_MSECS       7
#define HOST_NLA_NESTED      8
#define HOST_NLA_NESTED_ARRAY 9
#define HOST_NLA_NUL_STRING  10
#define HOST_NLA_BINARY      11
#define HOST_NLA_S8          12
#define HOST_NLA_S16         13
#define HOST_NLA_S32         14
#define HOST_NLA_S64         15
#define HOST_NLA_BITFIELD32  16
#define HOST_NLA_REJECT      17
#define HOST_NLA_BE16        18
#define HOST_NLA_BE32        19
#define HOST_NLA_SINT        20
#define HOST_NLA_UINT        21

#define HOST_NLA_F_NESTED 0x8000u

#define HOST_POLICY_VALIDATE_NONE                0
#define HOST_POLICY_VALIDATE_RANGE               1
#define HOST_POLICY_VALIDATE_RANGE_WARN_TOO_LONG 2
#define HOST_POLICY_VALIDATE_MIN                 3
#define HOST_POLICY_VALIDATE_MAX                 4
#define HOST_POLICY_VALIDATE_MASK                5
#define HOST_POLICY_VALIDATE_RANGE_PTR           6
#define HOST_POLICY_VALIDATE_FUNCTION            7

#define HOST_ERRNO_FLAG (1ULL << 32)
#define HOST_CMP_NEGATIVE (1ULL << 32)

#define HOST_VALIDATE_TRAILING     1
#define HOST_VALIDATE_MAXTYPE      2
#define HOST_VALIDATE_UNSPEC       4
#define HOST_VALIDATE_STRICT_ATTRS 8
#define HOST_VALIDATE_NESTED       16
#define HOST_BUILDER_NOHDR         1
#define HOST_BUILDER_64BIT_PAD     2
#define HOST_EMSGSIZE              90

struct host_nlattr {
	uint16_t nla_len;
	uint16_t nla_type;
	unsigned char payload[];
} __attribute__((packed));

struct host_policy {
	uint64_t type;
	uint64_t len;
	uint64_t min;
	uint64_t max;
	uint64_t range_ptr;
	uint64_t kind;
	uint64_t min_len;
	uint64_t max_len;
	uint64_t exact_len;
	uint64_t mask;
	uint64_t payload_len;
	uint64_t validation_type;
	uint64_t value_kind;
	uint64_t value_min;
	uint64_t value_max;
	uint64_t validate_result;
	uint64_t nested_policy;
	uint64_t nested_maxtype;
	uint64_t is_unspec;
	uint64_t strict_start;
	uint64_t strict_len;
};

struct host_raw_nla_policy {
	uint8_t type;
	uint8_t validation_type;
	uint16_t len;
	uint32_t pad;
	union {
		uint16_t strict_start_type;
		uint32_t mask;
		const void *ptr;
		struct {
			uint16_t lo16;
			uint16_t hi16;
		};
	} u;
};

typedef char host_raw_nla_policy_size_check[
	sizeof(struct host_raw_nla_policy) == 16 ? 1 : -1];

struct materialized_policy_node {
	void *ptr;
	struct materialized_policy_node *next;
};

extern uint64_t lean_nlattr_validate_parse_core(uint64_t head, uint64_t len,
	uint64_t maxtype, uint64_t policy, uint64_t strict_start,
	uint64_t validate, uint64_t extack, uint64_t tb);
extern uint64_t lean_nlattr_find_core(uint64_t head, uint64_t len,
	uint64_t attrtype);
extern uint64_t lean_nlattr_memcmp_core(uint64_t nla, uint64_t data,
	uint64_t size);
extern uint64_t lean_nlattr_memcpy_core(uint64_t dest, uint64_t src,
	uint64_t count);
extern uint64_t lean_nlattr_strscpy_core(uint64_t dst, uint64_t nla,
	uint64_t dstsize);
extern uint64_t lean_nlattr_strcmp_core(uint64_t nla, uint64_t str);
extern uint64_t lean_nlattr_policy_len_core(uint64_t policy, uint64_t count);
extern uint64_t lean_nlattr_str_payload_len_core(uint64_t nla);
extern uint64_t lean_nlattr_range_unsigned_supported_core(uint64_t type);
extern uint64_t lean_nlattr_range_unsigned_min_core(uint64_t type,
	uint64_t validation, uint64_t policy_min, uint64_t range_min);
extern uint64_t lean_nlattr_range_unsigned_max_core(uint64_t type,
	uint64_t validation, uint64_t policy_max, uint64_t range_max);
extern uint64_t lean_nlattr_range_signed_supported_core(uint64_t type);
extern uint64_t lean_nlattr_range_signed_min_core(uint64_t type,
	uint64_t validation, uint64_t policy_min, uint64_t range_min);
extern uint64_t lean_nlattr_range_signed_max_core(uint64_t type,
	uint64_t validation, uint64_t policy_max, uint64_t range_max);
extern uint64_t lean_nlattr_builder_required_core(uint64_t attrlen,
	uint64_t flags);
extern uint64_t lean_nlattr_builder_attr_size_core(uint64_t attrlen);
extern uint64_t lean_nlattr_builder_padlen_core(uint64_t attrlen);
extern uint64_t lean_nlattr_builder_status_core(uint64_t tailroom,
	uint64_t attrlen, uint64_t flags);
extern lean_object *initialize_NlAttrCore(uint8_t builtin);

uint64_t lean_nlattr_strdup_alloc(uint64_t len, uint64_t flags)
{
	(void)flags;
	return (uint64_t)(uintptr_t)malloc((size_t)len + 1);
}

static const struct host_policy *policy_at(uint64_t policy, uint64_t ty)
{
	return &((const struct host_policy *)(uintptr_t)policy)[ty];
}

static const struct host_raw_nla_policy *raw_policy_at(uint64_t policy,
	uint64_t ty)
{
	return &((const struct host_raw_nla_policy *)(uintptr_t)policy)[ty];
}

static uint64_t host_materialized_validate_parse_core(uint64_t head,
	uint64_t len, uint64_t maxtype, uint64_t policy, uint64_t validate,
	uint64_t extack, uint64_t tb);
static uint64_t host_policy_len_core(uint64_t policy, uint64_t count);

static uint64_t host_validate_parse_core(uint64_t head, uint64_t len,
	uint64_t maxtype, uint64_t policy, uint64_t validate, uint64_t extack,
	uint64_t tb)
{
	return host_materialized_validate_parse_core(head, len, maxtype,
		policy, validate, extack, tb);
}

static uint64_t host_type_from_value_kind(uint64_t value_kind)
{
	switch (value_kind) {
	case LEAN_VALUE_UNSIGNED8:
		return HOST_NLA_U8;
	case LEAN_VALUE_UNSIGNED16:
		return HOST_NLA_U16;
	case LEAN_VALUE_UNSIGNED32:
		return HOST_NLA_U32;
	case LEAN_VALUE_UNSIGNED64:
		return HOST_NLA_U64;
	case LEAN_VALUE_UNSIGNED32_OR64:
		return HOST_NLA_UINT;
	case LEAN_VALUE_MSECS:
		return HOST_NLA_MSECS;
	case LEAN_VALUE_BIG_UNSIGNED16:
		return HOST_NLA_BE16;
	case LEAN_VALUE_BIG_UNSIGNED32:
		return HOST_NLA_BE32;
	case LEAN_VALUE_SIGNED8:
		return HOST_NLA_S8;
	case LEAN_VALUE_SIGNED16:
		return HOST_NLA_S16;
	case LEAN_VALUE_SIGNED32:
		return HOST_NLA_S32;
	case LEAN_VALUE_SIGNED64:
		return HOST_NLA_S64;
	case LEAN_VALUE_SIGNED32_OR64:
		return HOST_NLA_SINT;
	case LEAN_VALUE_BINARY_LEN:
		return HOST_NLA_BINARY;
	default:
		return HOST_NLA_UNSPEC;
	}
}

static uint64_t host_policy_type(const struct host_policy *pt)
{
	if (pt->type)
		return pt->type;
	if (pt->value_kind)
		return host_type_from_value_kind(pt->value_kind);

	switch (pt->kind) {
	case LEAN_KIND_FLAG:
		return HOST_NLA_FLAG;
	case LEAN_KIND_STRING:
		return HOST_NLA_STRING;
	case LEAN_KIND_NUL_STRING:
		return HOST_NLA_NUL_STRING;
	case LEAN_KIND_BITFIELD32:
		return HOST_NLA_BITFIELD32;
	case LEAN_KIND_INT32_OR64:
		return HOST_NLA_UINT;
	case LEAN_KIND_NESTED:
	case LEAN_KIND_NESTED_POLICY:
		return HOST_NLA_NESTED;
	case LEAN_KIND_NESTED_ARRAY_POLICY:
		return HOST_NLA_NESTED_ARRAY;
	case LEAN_KIND_REJECT:
		return HOST_NLA_REJECT;
	case LEAN_KIND_EXACT:
	case LEAN_KIND_MIN:
	case LEAN_KIND_RANGE:
		return HOST_NLA_UNSPEC;
	default:
		return pt->is_unspec ? HOST_NLA_UNSPEC : HOST_NLA_UNSPEC;
	}
}

uint64_t lean_nlattr_policy_type(uint64_t policy, uint64_t ty)
{
	return host_policy_type(policy_at(policy, ty));
}

uint64_t lean_nlattr_policy_len_field(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);

	if (pt->len)
		return pt->len;
	if (pt->exact_len)
		return pt->exact_len;
	if (pt->kind == LEAN_KIND_STRING || pt->kind == LEAN_KIND_NUL_STRING)
		return pt->max_len;
	return 0;
}

uint64_t lean_nlattr_policy_min_field(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);

	if (pt->min)
		return pt->min;
	if (pt->value_min)
		return pt->value_min;
	return pt->min_len;
}

uint64_t lean_nlattr_policy_max_field(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);

	if (pt->max)
		return pt->max;
	if (pt->value_max)
		return pt->value_max;
	return pt->max_len;
}

uint64_t lean_nlattr_policy_range_ptr(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);

	if (pt->range_ptr)
		return pt->range_ptr;
	if (pt->validation_type == HOST_POLICY_VALIDATE_RANGE_PTR &&
	    (pt->value_min || pt->value_max))
		return 1;
	return 0;
}

uint64_t lean_nlattr_policy_info(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);
	uint64_t has_range_ptr = lean_nlattr_policy_range_ptr(policy, ty) ? 1 : 0;
	uint64_t has_nested = pt->nested_policy ? 1 : 0;

	return lean_nlattr_policy_type(policy, ty) |
		(pt->validation_type << 8) |
		(lean_nlattr_policy_len_field(policy, ty) << 16) |
		(has_range_ptr << 32) |
		(has_nested << 33);
}

uint64_t lean_nlattr_policy_bounds(uint64_t policy, uint64_t ty)
{
	const struct host_policy *pt = policy_at(policy, ty);
	uint64_t min = (uint32_t)(int32_t)lean_nlattr_policy_min_field(policy, ty);
	uint64_t max = (uint32_t)(int32_t)lean_nlattr_policy_max_field(policy, ty);

	if (pt->validation_type == HOST_POLICY_VALIDATE_RANGE_PTR) {
		min = 0;
		max = 0;
	}

	return min | (max << 32);
}

uint64_t lean_nlattr_policy_kind(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->kind;
}

uint64_t lean_nlattr_policy_min_len(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->min_len;
}

uint64_t lean_nlattr_policy_max_len(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->max_len;
}

uint64_t lean_nlattr_policy_exact_len(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->exact_len;
}

uint64_t lean_nlattr_policy_mask(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->mask;
}

uint64_t lean_nlattr_policy_payload_len(uint64_t policy, uint64_t ix)
{
	return policy_at(policy, ix)->payload_len;
}

uint64_t lean_nlattr_policy_validation_type(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->validation_type;
}

uint64_t lean_nlattr_policy_value_kind(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->value_kind;
}

uint64_t lean_nlattr_policy_value_min(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->value_min;
}

uint64_t lean_nlattr_policy_value_max(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->value_max;
}

uint64_t lean_nlattr_policy_validate_fn_raw(uint64_t policy, uint64_t ty,
	uint64_t attr, uint64_t extack)
{
	const struct host_raw_nla_policy *pt = raw_policy_at(policy, ty);
	const uint64_t *result = (const uint64_t *)pt->u.ptr;

	(void)attr;
	(void)extack;
	if (!result)
		return 0;
	return (uint64_t)(int64_t)-(int64_t)*result;
}

uint64_t lean_nlattr_policy_is_unspec(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->is_unspec;
}

uint64_t lean_nlattr_policy_strict_start(uint64_t policy)
{
	return policy_at(policy, 0)->strict_start;
}

uint64_t lean_nlattr_policy_strict_len(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->strict_len;
}

uint64_t lean_nlattr_policy_nested_policy(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->nested_policy;
}

uint64_t lean_nlattr_policy_nested_maxtype(uint64_t policy, uint64_t ty)
{
	return policy_at(policy, ty)->nested_maxtype;
}

static void track_materialized(void *ptr, struct materialized_policy_node **head)
{
	struct materialized_policy_node *node = malloc(sizeof(*node));

	if (!ptr || !node)
		abort();
	node->ptr = ptr;
	node->next = *head;
	*head = node;
}

static void free_materialized(struct materialized_policy_node *head)
{
	while (head) {
		struct materialized_policy_node *next = head->next;

		free(head->ptr);
		free(head);
		head = next;
	}
}

static struct host_raw_nla_policy *materialize_policy(
	const struct host_policy *policy, uint64_t count,
	const struct host_policy *root_policy, struct host_raw_nla_policy *root_raw,
	struct materialized_policy_node **nodes)
{
	struct host_raw_nla_policy *raw;
	uint64_t i;

	raw = calloc((size_t)count, sizeof(*raw));
	track_materialized(raw, nodes);
	if (!root_policy) {
		root_policy = policy;
		root_raw = raw;
	}

	for (i = 0; i < count; i++) {
		const struct host_policy *pt = &policy[i];
		uint64_t ptype = host_policy_type(pt);

		raw[i].type = (uint8_t)ptype;
		raw[i].validation_type = (uint8_t)pt->validation_type;
		if (pt->nested_maxtype)
			raw[i].len = (uint16_t)pt->nested_maxtype;
		else
			raw[i].len = (uint16_t)lean_nlattr_policy_len_field(
				(uint64_t)(uintptr_t)policy, i);

		if (i == 0 && pt->strict_start)
			raw[i].u.strict_start_type = (uint16_t)pt->strict_start;

		if (pt->nested_policy) {
			const struct host_policy *nested =
				(const struct host_policy *)(uintptr_t)pt->nested_policy;

			if (nested == root_policy) {
				raw[i].u.ptr = root_raw;
			} else {
				raw[i].u.ptr = materialize_policy(nested,
					pt->nested_maxtype + 1, root_policy, root_raw,
					nodes);
			}
		} else if (pt->validation_type == HOST_POLICY_VALIDATE_RANGE_PTR) {
			if (pt->range_ptr)
				raw[i].u.ptr = (const void *)(uintptr_t)pt->range_ptr;
			else if (pt->value_min || pt->value_max)
				raw[i].u.ptr = &pt->value_min;
		} else if (pt->validation_type == HOST_POLICY_VALIDATE_FUNCTION) {
			raw[i].u.ptr = &pt->validate_result;
		} else if (pt->validation_type == HOST_POLICY_VALIDATE_MASK ||
			   ptype == HOST_NLA_BITFIELD32) {
			raw[i].u.mask = (uint32_t)pt->mask;
		} else if (i != 0 || !pt->strict_start) {
			raw[i].u.lo16 = (uint16_t)lean_nlattr_policy_min_field(
				(uint64_t)(uintptr_t)policy, i);
			raw[i].u.hi16 = (uint16_t)lean_nlattr_policy_max_field(
				(uint64_t)(uintptr_t)policy, i);
		}
	}

	return raw;
}

static uint64_t host_materialized_validate_parse_core(uint64_t head,
	uint64_t len, uint64_t maxtype, uint64_t policy, uint64_t validate,
	uint64_t extack, uint64_t tb)
{
	struct materialized_policy_node *nodes = NULL;
	struct host_raw_nla_policy *raw = NULL;
	const struct host_policy *host_policy =
		(const struct host_policy *)(uintptr_t)policy;
	uint64_t strict_start = 0;
	uint64_t ret;

	if (policy) {
		strict_start = host_policy[0].strict_start;
		raw = materialize_policy(host_policy, maxtype + 1, NULL, NULL,
			&nodes);
	}

	ret = lean_nlattr_validate_parse_core(head, len, maxtype,
		(uint64_t)(uintptr_t)raw, strict_start, validate, extack, tb);
	free_materialized(nodes);
	return ret;
}

static uint64_t host_policy_len_core(uint64_t policy, uint64_t count)
{
	struct materialized_policy_node *nodes = NULL;
	const struct host_policy *host_policy =
		(const struct host_policy *)(uintptr_t)policy;
	struct host_raw_nla_policy *raw;
	uint64_t ret;

	raw = materialize_policy(host_policy, count, NULL, NULL, &nodes);
	ret = lean_nlattr_policy_len_core((uint64_t)(uintptr_t)raw, count);
	free_materialized(nodes);
	return ret;
}

uint64_t lean_nlattr_array_index_nospec(uint64_t index, uint64_t size)
{
	if (index >= size)
		return 0;
	return index;
}

uint64_t lean_nlattr_report_recursion_depth(uint64_t extack)
{
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_unknown_attr(uint64_t attr, uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_warn_trailing_bytes(uint64_t unit)
{
	(void)unit;
	return 0;
}

uint64_t lean_nlattr_report_trailing_bytes(uint64_t extack)
{
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_warn_invalid_attr_len(uint64_t ty)
{
	(void)ty;
	return 0;
}

uint64_t lean_nlattr_report_invalid_attr_len_attr(uint64_t attr,
	uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_invalid_attr_len_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_nested_missing_attr(uint64_t attr,
	uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_nested_missing_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_nested_unexpected_attr(uint64_t attr,
	uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_nested_unexpected_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_reject_message(uint64_t attr, uint64_t policy,
	uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_failed_policy_attr(uint64_t attr,
	uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_failed_policy_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_unsupported_attr(uint64_t attr, uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_reserved_bit(uint64_t attr, uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_binary_range_attr(uint64_t attr, uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_binary_range_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_integer_range_attr(uint64_t attr, uint64_t extack)
{
	(void)attr;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_report_integer_range_policy(uint64_t attr,
	uint64_t policy, uint64_t ty, uint64_t extack)
{
	(void)attr;
	(void)policy;
	(void)ty;
	(void)extack;
	return 0;
}

uint64_t lean_nlattr_set_tb(uint64_t tb, uint64_t ty, uint64_t attr)
{
	uintptr_t *table = (uintptr_t *)(uintptr_t)tb;
	table[ty] = (uintptr_t)attr;
	return 0;
}

static int expect(const char *name, uint64_t got, uint64_t want)
{
	if (got != want) {
		fprintf(stderr, "%s: got %llu want %llu\n", name,
			(unsigned long long)got, (unsigned long long)want);
		return 1;
	}
	return 0;
}

static size_t build_nested_chain(unsigned char *buf, unsigned int levels)
{
	size_t len = 4;
	unsigned int i;

	buf[0] = 4;
	buf[1] = 0;
	buf[2] = 1;
	buf[3] = 0;

	for (i = 0; i < levels; i++) {
		memmove(buf + 4, buf, len);
		len += 4;
		buf[0] = len & 0xff;
		buf[1] = (len >> 8) & 0xff;
		buf[2] = 1;
		buf[3] = 0;
	}

	return len;
}

int main(void)
{
	lean_object *init_result;
	unsigned char valid[] = {
		5, 0, 1, 0, 7, 0, 0, 0,
		8, 0, 2, 0, 'a', 'b', 'c', 'd',
	};
	unsigned char final_unpadded[] = { 5, 0, 1, 0, 7 };
	unsigned char cmp_attr[] = {
		8, 0, 1, 0, 'a', 'b', 'c', 'd',
	};
	unsigned char strcmp_attr[] = {
		9, 0, 1, 0, 'a', 'b', 'c', 0, 0, 0, 0, 0,
	};
	unsigned char cmp_equal[] = { 'a', 'b', 'c', 'd' };
	unsigned char cmp_greater[] = { 'a', 'b', 'c', 'c' };
	unsigned char cmp_less[] = { 'a', 'b', 'c', 'e' };
	unsigned char memcpy_short[6];
	unsigned char memcpy_padded[6];
	unsigned char strscpy_fit[6];
	unsigned char strscpy_trunc[3];
	unsigned char strscpy_zero[2];
	unsigned char short_len[] = { 3, 0, 1, 0 };
	unsigned char overrun[] = { 8, 0, 1, 0, 1 };
	unsigned char type_zero[] = {
		5, 0, 0, 0, 7, 0, 0, 0,
		5, 0, 1, 0, 9,
	};
	unsigned char string_ok[] = { 8, 0, 1, 0, 'a', 'b', 'c', 0 };
	unsigned char string_bad[] = { 8, 0, 1, 0, 'a', 'b', 'c', 'd' };
	unsigned char nul_string_bad[] = { 7, 0, 1, 0, 'a', 'b', 'c' };
	unsigned char bitfield_ok[] = {
		12, 0, 1, 0,
		2, 0, 0, 0,
		2, 0, 0, 0,
	};
	unsigned char bitfield_bad[] = {
		12, 0, 1, 0,
		4, 0, 0, 0,
		2, 0, 0, 0,
	};
	unsigned char int_word_ok[] = { 8, 0, 1, 0, 1, 2, 3, 4 };
	unsigned char int_word_bad[] = { 9, 0, 1, 0, 1, 2, 3, 4, 5 };
	unsigned char fixed_wide[] = { 9, 0, 1, 0, 1, 2, 3, 4, 5 };
	unsigned char u8_value_ok[] = { 5, 0, 1, 0, 7, 0, 0, 0 };
	unsigned char u8_value_bad[] = { 5, 0, 1, 0, 10, 0, 0, 0 };
	unsigned char u8_mask_bad[] = { 5, 0, 1, 0, 0x80, 0, 0, 0 };
	unsigned char s8_neg_ok[] = { 5, 0, 1, 0, 0xfb, 0, 0, 0 };
	unsigned char s8_pos_bad[] = { 5, 0, 1, 0, 7, 0, 0, 0 };
	unsigned char be16_ok[] = { 6, 0, 1, 0, 0x12, 0x34, 0, 0 };
	unsigned char be16_bad[] = { 6, 0, 1, 0, 0x13, 0x01, 0, 0 };
	unsigned char uint64_ok[] = {
		12, 0, 1, 0,
		42, 0, 0, 0,
		0, 0, 0, 0,
	};
	unsigned char uint64_bad[] = {
		12, 0, 1, 0,
		101, 0, 0, 0,
		0, 0, 0, 0,
	};
	unsigned char uint64_fullrange_ok[] = {
		12, 0, 1, 0,
		0xa0, 0x09, 0x01, 0,
		0, 0, 0, 0,
	};
	unsigned char uint64_fullrange_bad[] = {
		12, 0, 1, 0,
		0x40, 0x19, 0x01, 0,
		0, 0, 0, 0,
	};
	unsigned char sint32_neg_ok[] = {
		8, 0, 1, 0,
		0xfb, 0xff, 0xff, 0xff,
	};
	unsigned char sint32_pos_bad[] = {
		8, 0, 1, 0,
		7, 0, 0, 0,
	};
	unsigned char binary_warn_long[] = {
		10, 0, 1, 0,
		1, 2, 3, 4, 5, 6, 0, 0,
	};
	unsigned char binary_warn_short[] = { 7, 0, 1, 0, 1, 2, 3, 0 };
	unsigned char nested_ok[] = {
		12, 0, 1, 0,
		8, 0, 1, 0, 1, 2, 3, 4,
	};
	unsigned char nested_flag_ok[] = {
		12, 0, 1, 128,
		8, 0, 1, 0, 1, 2, 3, 4,
	};
	unsigned char nested_bad[] = {
		11, 0, 1, 0,
		7, 0, 1, 0, 1, 2, 3,
	};
	unsigned char nested_array_ok[] = {
		16, 0, 1, 0,
		12, 0, 99, 0,
		8, 0, 1, 0, 1, 2, 3, 4,
	};
	unsigned char nested_array_bad[] = {
		15, 0, 1, 0,
		11, 0, 99, 0,
		7, 0, 1, 0, 1, 2, 3,
	};
	unsigned char nested_array_empty_entry[] = {
		8, 0, 1, 0,
		4, 0, 99, 0,
	};
	unsigned char nested_array_tail[] = {
		9, 0, 1, 0,
		4, 0, 99, 0, 0,
	};
	struct host_policy policy[3];
	struct host_policy nested_policy[2];
	unsigned char deep_nested[64];
	uintptr_t tb[3];
	size_t deep_nested_len;
	uint64_t ret;
	int failed = 0;

	init_result = initialize_NlAttrCore(0);
	if (lean_io_result_is_error(init_result)) {
		fprintf(stderr, "failed to initialize NlAttrCore\n");
		return 1;
	}
	lean_dec_ref(init_result);

	deep_nested_len = build_nested_chain(deep_nested, 10);

	memset(policy, 0, sizeof(policy));
	policy[1].type = HOST_NLA_U8;
	policy[1].kind = LEAN_KIND_EXACT;
	policy[1].exact_len = 1;
	policy[1].payload_len = 1;
	policy[2].type = HOST_NLA_U32;
	policy[2].kind = LEAN_KIND_RANGE;
	policy[2].min_len = 1;
	policy[2].max_len = 256;
	policy[2].payload_len = 4;

	memset(tb, 0, sizeof(tb));
	ret = host_validate_parse_core((uintptr_t)valid, sizeof(valid), 2,
		(uintptr_t)policy, 0, 0, (uintptr_t)tb);
	failed |= expect("valid", ret, 0);
	failed |= expect("tb1", tb[1], (uintptr_t)valid);
	failed |= expect("tb2", tb[2], (uintptr_t)(valid + 8));
	failed |= expect("find1",
		lean_nlattr_find_core((uintptr_t)valid, sizeof(valid), 1),
		(uintptr_t)valid);
	failed |= expect("find2",
		lean_nlattr_find_core((uintptr_t)valid, sizeof(valid), 2),
		(uintptr_t)(valid + 8));
	failed |= expect("find3",
		lean_nlattr_find_core((uintptr_t)valid, sizeof(valid), 3), 0);
	failed |= expect("memcmp_equal",
		lean_nlattr_memcmp_core((uintptr_t)cmp_attr,
			(uintptr_t)cmp_equal, sizeof(cmp_equal)), 0);
	failed |= expect("memcmp_greater",
		lean_nlattr_memcmp_core((uintptr_t)cmp_attr,
			(uintptr_t)cmp_greater, sizeof(cmp_greater)), 1);
	failed |= expect("memcmp_less",
		lean_nlattr_memcmp_core((uintptr_t)cmp_attr,
			(uintptr_t)cmp_less, sizeof(cmp_less)),
		HOST_CMP_NEGATIVE | 1);
	failed |= expect("memcmp_short_data",
		lean_nlattr_memcmp_core((uintptr_t)cmp_attr,
			(uintptr_t)cmp_equal, 3), 1);
	failed |= expect("memcmp_long_data",
		lean_nlattr_memcmp_core((uintptr_t)cmp_attr,
			(uintptr_t)cmp_equal, 5), HOST_CMP_NEGATIVE | 1);
	memset(memcpy_short, 0xaa, sizeof(memcpy_short));
	failed |= expect("memcpy_short_ret",
		lean_nlattr_memcpy_core((uintptr_t)memcpy_short,
			(uintptr_t)cmp_attr, 3), 3);
	failed |= expect("memcpy_short_data",
		memcmp(memcpy_short, "abc", 3), 0);
	failed |= expect("memcpy_short_tail",
		memcpy_short[3], 0xaa);
	memset(memcpy_padded, 0xaa, sizeof(memcpy_padded));
	failed |= expect("memcpy_padded_ret",
		lean_nlattr_memcpy_core((uintptr_t)memcpy_padded,
			(uintptr_t)cmp_attr, sizeof(memcpy_padded)), 4);
	failed |= expect("memcpy_padded_data",
		memcmp(memcpy_padded, "abcd", 4), 0);
	failed |= expect("memcpy_padded_zero4", memcpy_padded[4], 0);
	failed |= expect("memcpy_padded_zero5", memcpy_padded[5], 0);
	memset(strscpy_fit, 0xaa, sizeof(strscpy_fit));
	failed |= expect("strscpy_fit_ret",
		lean_nlattr_strscpy_core((uintptr_t)strscpy_fit,
			(uintptr_t)string_ok, sizeof(strscpy_fit)), 3);
	failed |= expect("strscpy_fit_data",
		memcmp(strscpy_fit, "abc", 3), 0);
	failed |= expect("strscpy_fit_zero3", strscpy_fit[3], 0);
	failed |= expect("strscpy_fit_zero5", strscpy_fit[5], 0);
	memset(strscpy_trunc, 0xaa, sizeof(strscpy_trunc));
	failed |= expect("strscpy_trunc_ret",
		lean_nlattr_strscpy_core((uintptr_t)strscpy_trunc,
			(uintptr_t)string_ok, sizeof(strscpy_trunc)),
		HOST_CMP_NEGATIVE | 7);
	failed |= expect("strscpy_trunc_data",
		memcmp(strscpy_trunc, "ab", 2), 0);
	failed |= expect("strscpy_trunc_zero2", strscpy_trunc[2], 0);
	memset(strscpy_zero, 0xaa, sizeof(strscpy_zero));
	failed |= expect("strscpy_zero_ret",
		lean_nlattr_strscpy_core((uintptr_t)strscpy_zero,
			(uintptr_t)string_ok, 0), HOST_CMP_NEGATIVE | 7);
	failed |= expect("strscpy_zero_untouched", strscpy_zero[0], 0xaa);
	failed |= expect("strcmp_equal",
		lean_nlattr_strcmp_core((uintptr_t)strcmp_attr,
			(uintptr_t)"abc"), 0);
	failed |= expect("strcmp_greater",
		lean_nlattr_strcmp_core((uintptr_t)strcmp_attr,
			(uintptr_t)"abb"), 1);
	failed |= expect("strcmp_less",
		lean_nlattr_strcmp_core((uintptr_t)strcmp_attr,
			(uintptr_t)"abd"), HOST_CMP_NEGATIVE | 1);
	failed |= expect("strcmp_short",
		lean_nlattr_strcmp_core((uintptr_t)strcmp_attr,
			(uintptr_t)"ab"), 1);
	failed |= expect("str_payload_len_no_nul",
		lean_nlattr_str_payload_len_core((uintptr_t)cmp_attr), 4);
	failed |= expect("str_payload_len_one_nul",
		lean_nlattr_str_payload_len_core((uintptr_t)string_ok), 3);
	failed |= expect("str_payload_len_two_nuls",
		lean_nlattr_str_payload_len_core((uintptr_t)strcmp_attr), 4);
	failed |= expect("policy_len",
		host_policy_len_core((uintptr_t)policy, 3), 16);
	failed |= expect("range_u32_supported",
		lean_nlattr_range_unsigned_supported_core(HOST_NLA_U32), 1);
	failed |= expect("range_u32_default_min",
		lean_nlattr_range_unsigned_min_core(HOST_NLA_U32,
			HOST_POLICY_VALIDATE_NONE, 11, 22), 0);
	failed |= expect("range_u32_default_max",
		lean_nlattr_range_unsigned_max_core(HOST_NLA_U32,
			HOST_POLICY_VALIDATE_NONE, 11, 22), 0xffffffffULL);
	failed |= expect("range_binary_warn_min",
		lean_nlattr_range_unsigned_min_core(HOST_NLA_BINARY,
			HOST_POLICY_VALIDATE_RANGE_WARN_TOO_LONG, 4, 22), 4);
	failed |= expect("range_binary_warn_max",
		lean_nlattr_range_unsigned_max_core(HOST_NLA_BINARY,
			HOST_POLICY_VALIDATE_RANGE_WARN_TOO_LONG, 11, 22), 11);
	failed |= expect("range_uint_ptr_min",
		lean_nlattr_range_unsigned_min_core(HOST_NLA_UINT,
			HOST_POLICY_VALIDATE_RANGE_PTR, 11, 65000), 65000);
	failed |= expect("range_uint_ptr_max",
		lean_nlattr_range_unsigned_max_core(HOST_NLA_UINT,
			HOST_POLICY_VALIDATE_RANGE_PTR, 11, 70000), 70000);
	failed |= expect("range_flag_not_unsigned",
		lean_nlattr_range_unsigned_supported_core(HOST_NLA_FLAG), 0);
	failed |= expect("range_s8_supported",
		lean_nlattr_range_signed_supported_core(HOST_NLA_S8), 1);
	failed |= expect("range_s8_default_min",
		lean_nlattr_range_signed_min_core(HOST_NLA_S8,
			HOST_POLICY_VALIDATE_NONE, 11, 22), (uint64_t)-128);
	failed |= expect("range_s8_default_max",
		lean_nlattr_range_signed_max_core(HOST_NLA_S8,
			HOST_POLICY_VALIDATE_NONE, 11, 22), 127);
	failed |= expect("range_sint_min",
		lean_nlattr_range_signed_min_core(HOST_NLA_SINT,
			HOST_POLICY_VALIDATE_MIN, (uint64_t)-10, 22),
		(uint64_t)-10);
	failed |= expect("range_sint_max",
		lean_nlattr_range_signed_max_core(HOST_NLA_SINT,
			HOST_POLICY_VALIDATE_MAX, 11, 22), 11);
	failed |= expect("range_flag_not_signed",
		lean_nlattr_range_signed_supported_core(HOST_NLA_FLAG), 0);
	failed |= expect("builder_attr_size4",
		lean_nlattr_builder_required_core(4, 0), 8);
	failed |= expect("builder_attr_size5",
		lean_nlattr_builder_required_core(5, 0), 12);
	failed |= expect("builder_nohdr_size5",
		lean_nlattr_builder_required_core(5, HOST_BUILDER_NOHDR), 8);
	failed |= expect("builder_64bit_pad_size8",
		lean_nlattr_builder_required_core(8, HOST_BUILDER_64BIT_PAD), 16);
	failed |= expect("builder_nohdr_64bit_pad_size5",
		lean_nlattr_builder_required_core(5,
			HOST_BUILDER_NOHDR | HOST_BUILDER_64BIT_PAD), 12);
	failed |= expect("builder_attr_header_size0",
		lean_nlattr_builder_attr_size_core(0), 4);
	failed |= expect("builder_attr_header_size5",
		lean_nlattr_builder_attr_size_core(5), 9);
	failed |= expect("builder_padlen0",
		lean_nlattr_builder_padlen_core(0), 0);
	failed |= expect("builder_padlen1",
		lean_nlattr_builder_padlen_core(1), 3);
	failed |= expect("builder_padlen4",
		lean_nlattr_builder_padlen_core(4), 0);
	failed |= expect("builder_padlen5",
		lean_nlattr_builder_padlen_core(5), 3);
	failed |= expect("builder_status_fit",
		lean_nlattr_builder_status_core(12, 8, 0), 0);
	failed |= expect("builder_status_short",
		lean_nlattr_builder_status_core(11, 8, 0), HOST_EMSGSIZE);
	failed |= expect("builder_status_nohdr_fit",
		lean_nlattr_builder_status_core(8, 5, HOST_BUILDER_NOHDR), 0);
	failed |= expect("builder_status_nohdr_short",
		lean_nlattr_builder_status_core(7, 5, HOST_BUILDER_NOHDR),
		HOST_EMSGSIZE);
	failed |= expect("builder_status_64bit_pad_short",
		lean_nlattr_builder_status_core(15, 8, HOST_BUILDER_64BIT_PAD),
		HOST_EMSGSIZE);
	failed |= expect("builder_status_nohdr_64bit_pad_fit",
		lean_nlattr_builder_status_core(12, 5,
			HOST_BUILDER_NOHDR | HOST_BUILDER_64BIT_PAD), 0);
	failed |= expect("builder_status_nohdr_64bit_pad_short",
		lean_nlattr_builder_status_core(11, 5,
			HOST_BUILDER_NOHDR | HOST_BUILDER_64BIT_PAD),
		HOST_EMSGSIZE);

	ret = host_validate_parse_core((uintptr_t)final_unpadded,
		sizeof(final_unpadded), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("final_unpadded", ret, 0);
	failed |= expect("find_final_unpadded",
		lean_nlattr_find_core((uintptr_t)final_unpadded,
			sizeof(final_unpadded), 1),
		(uintptr_t)final_unpadded);

	ret = host_validate_parse_core((uintptr_t)short_len,
		sizeof(short_len), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("short_len", ret, 0);
	failed |= expect("find_short_len",
		lean_nlattr_find_core((uintptr_t)short_len,
			sizeof(short_len), 1), 0);
	ret = host_validate_parse_core((uintptr_t)short_len,
		sizeof(short_len), 2, (uintptr_t)policy, HOST_VALIDATE_TRAILING,
		0, 0);
	failed |= expect("short_len_trailing", ret, 22);

	ret = host_validate_parse_core((uintptr_t)overrun,
		sizeof(overrun), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("overrun", ret, 0);
	ret = host_validate_parse_core((uintptr_t)overrun,
		sizeof(overrun), 2, (uintptr_t)policy, HOST_VALIDATE_TRAILING,
		0, 0);
	failed |= expect("overrun_trailing", ret, 22);

	memset(tb, 0, sizeof(tb));
	ret = host_validate_parse_core((uintptr_t)type_zero,
		sizeof(type_zero), 2, (uintptr_t)policy, 0, 0, (uintptr_t)tb);
	failed |= expect("type_zero", ret, 0);
	failed |= expect("type_zero_tb0", tb[0], 0);
	failed |= expect("type_zero_tb1", tb[1], (uintptr_t)(type_zero + 8));
	ret = host_validate_parse_core((uintptr_t)type_zero,
		sizeof(type_zero), 2, (uintptr_t)policy, HOST_VALIDATE_MAXTYPE,
		0, 0);
	failed |= expect("type_zero_maxtype", ret, 22);

	ret = host_validate_parse_core((uintptr_t)valid, sizeof(valid), 1,
		(uintptr_t)policy, HOST_VALIDATE_MAXTYPE, 0, 0);
	failed |= expect("over_maxtype", ret, 22);

	policy[1].type = HOST_NLA_STRING;
	policy[1].len = 3;
	ret = host_validate_parse_core((uintptr_t)string_ok,
		sizeof(string_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("string_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)string_bad,
		sizeof(string_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("string_bad", ret, 34);

	policy[1].type = HOST_NLA_NUL_STRING;
	policy[1].len = 8;
	ret = host_validate_parse_core((uintptr_t)string_ok,
		sizeof(string_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nul_string_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)nul_string_bad,
		sizeof(nul_string_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nul_string_bad", ret, 22);

	policy[1].type = HOST_NLA_BITFIELD32;
	policy[1].mask = 0xff;
	ret = host_validate_parse_core((uintptr_t)bitfield_ok,
		sizeof(bitfield_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("bitfield_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)bitfield_bad,
		sizeof(bitfield_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("bitfield_bad", ret, 22);
	policy[1].validation_type = HOST_POLICY_VALIDATE_NONE;
	policy[1].validate_result = 0;

	policy[1].type = HOST_NLA_UINT;
	ret = host_validate_parse_core((uintptr_t)int_word_ok,
		sizeof(int_word_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("int_word_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)int_word_bad,
		sizeof(int_word_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("int_word_bad", ret, 22);

	memset(policy, 0, sizeof(policy));
	policy[1].kind = LEAN_KIND_MIN;
	policy[1].min_len = 1;
	policy[1].strict_len = 1;
	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE;
	policy[1].value_kind = LEAN_VALUE_UNSIGNED8;
	policy[1].value_min = 5;
	policy[1].value_max = 9;
	ret = host_validate_parse_core((uintptr_t)u8_value_ok,
		sizeof(u8_value_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("u8_range_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)u8_value_bad,
		sizeof(u8_value_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("u8_range_bad", ret, 34);

	policy[1].validation_type = HOST_POLICY_VALIDATE_MASK;
	policy[1].mask = 0x0f;
	ret = host_validate_parse_core((uintptr_t)u8_value_ok,
		sizeof(u8_value_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("u8_mask_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)u8_mask_bad,
		sizeof(u8_mask_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("u8_mask_bad", ret, 22);

	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE;
	policy[1].value_kind = LEAN_VALUE_SIGNED8;
	policy[1].value_min = (uint64_t)-10;
	policy[1].value_max = (uint64_t)-1;
	ret = host_validate_parse_core((uintptr_t)s8_neg_ok,
		sizeof(s8_neg_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("s8_range_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)s8_pos_bad,
		sizeof(s8_pos_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("s8_range_bad", ret, 34);

	policy[1].min_len = 2;
	policy[1].strict_len = 2;
	policy[1].validation_type = HOST_POLICY_VALIDATE_MAX;
	policy[1].value_kind = LEAN_VALUE_BIG_UNSIGNED16;
	policy[1].value_max = 0x1300;
	ret = host_validate_parse_core((uintptr_t)be16_ok,
		sizeof(be16_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("be16_max_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)be16_bad,
		sizeof(be16_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("be16_max_bad", ret, 34);

	policy[1].kind = LEAN_KIND_INT32_OR64;
	policy[1].validation_type = HOST_POLICY_VALIDATE_MAX;
	policy[1].value_kind = LEAN_VALUE_UNSIGNED32_OR64;
	policy[1].value_max = 100;
	ret = host_validate_parse_core((uintptr_t)uint64_ok,
		sizeof(uint64_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("uint64_max_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)uint64_bad,
		sizeof(uint64_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("uint64_max_bad", ret, 34);

	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE;
	policy[1].value_kind = LEAN_VALUE_SIGNED32_OR64;
	policy[1].value_min = (uint64_t)-10;
	policy[1].value_max = (uint64_t)-1;
	ret = host_validate_parse_core((uintptr_t)sint32_neg_ok,
		sizeof(sint32_neg_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("sint32_range_ok", ret, 0);

	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE_PTR;
	policy[1].value_kind = LEAN_VALUE_UNSIGNED32_OR64;
	policy[1].value_min = 65000;
	policy[1].value_max = 70000;
	ret = host_validate_parse_core((uintptr_t)uint64_fullrange_ok,
		sizeof(uint64_fullrange_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("uint64_range_ptr_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)uint64_fullrange_bad,
		sizeof(uint64_fullrange_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("uint64_range_ptr_bad", ret, 34);

	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE_PTR;
	policy[1].value_kind = LEAN_VALUE_SIGNED32_OR64;
	policy[1].value_min = (uint64_t)-10;
	policy[1].value_max = (uint64_t)-1;
	ret = host_validate_parse_core((uintptr_t)sint32_neg_ok,
		sizeof(sint32_neg_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("sint32_range_ptr_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)sint32_pos_bad,
		sizeof(sint32_pos_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("sint32_range_ptr_bad", ret, 34);

	policy[1].kind = LEAN_KIND_MIN;
	policy[1].min_len = 4;
	policy[1].strict_len = 0;
	policy[1].validation_type = HOST_POLICY_VALIDATE_RANGE_WARN_TOO_LONG;
	policy[1].value_kind = LEAN_VALUE_BINARY_LEN;
	policy[1].value_min = 4;
	policy[1].value_max = 4;
	ret = host_validate_parse_core((uintptr_t)binary_warn_long,
		sizeof(binary_warn_long), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("binary_warn_long_liberal", ret, 0);
	ret = host_validate_parse_core((uintptr_t)binary_warn_long,
		sizeof(binary_warn_long), 2, (uintptr_t)policy,
		HOST_VALIDATE_STRICT_ATTRS, 0, 0);
	failed |= expect("binary_warn_long_strict", ret, 22);
	ret = host_validate_parse_core((uintptr_t)binary_warn_short,
		sizeof(binary_warn_short), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("binary_warn_short", ret, 34);

	policy[1].kind = LEAN_KIND_MIN;
	policy[1].min_len = 1;
	policy[1].validation_type = HOST_POLICY_VALIDATE_FUNCTION;
	policy[1].validate_result = 0;
	ret = host_validate_parse_core((uintptr_t)u8_value_ok,
		sizeof(u8_value_ok), 2, (uintptr_t)policy, 0, 0x1234, 0);
	failed |= expect("validate_fn_ok", ret, 0);
	policy[1].validate_result = 1;
	ret = host_validate_parse_core((uintptr_t)u8_value_ok,
		sizeof(u8_value_ok), 2, (uintptr_t)policy, 0, 0x1234, 0);
	failed |= expect("validate_fn_eperm", ret, HOST_ERRNO_FLAG | 1);

	memset(policy, 0, sizeof(policy));
	policy[1].type = HOST_NLA_U32;
	ret = host_validate_parse_core((uintptr_t)fixed_wide,
		sizeof(fixed_wide), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("fixed_wide_liberal", ret, 0);
	ret = host_validate_parse_core((uintptr_t)fixed_wide,
		sizeof(fixed_wide), 2, (uintptr_t)policy,
		HOST_VALIDATE_STRICT_ATTRS, 0, 0);
	failed |= expect("fixed_wide_strict", ret, 22);

	memset(policy, 0, sizeof(policy));
	policy[1].kind = LEAN_KIND_ACCEPT;
	policy[1].is_unspec = 1;
	ret = host_validate_parse_core((uintptr_t)final_unpadded,
		sizeof(final_unpadded), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("unspec_liberal", ret, 0);
	ret = host_validate_parse_core((uintptr_t)final_unpadded,
		sizeof(final_unpadded), 2, (uintptr_t)policy,
		HOST_VALIDATE_UNSPEC, 0, 0);
	failed |= expect("unspec_strict", ret, 22);

	memset(policy, 0, sizeof(policy));
	policy[0].strict_start = 1;
	policy[1].type = HOST_NLA_U8;
	policy[1].kind = LEAN_KIND_EXACT;
	policy[1].exact_len = 1;
	policy[1].strict_len = 1;
	ret = host_validate_parse_core((uintptr_t)fixed_wide,
		sizeof(fixed_wide), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("strict_start", ret, 22);

	memset(nested_policy, 0, sizeof(nested_policy));
	nested_policy[1].type = HOST_NLA_U32;
	nested_policy[1].kind = LEAN_KIND_EXACT;
	nested_policy[1].exact_len = 4;
	memset(policy, 0, sizeof(policy));
	policy[1].type = HOST_NLA_NESTED;
	policy[1].kind = LEAN_KIND_NESTED_POLICY;
	policy[1].nested_policy = (uintptr_t)nested_policy;
	policy[1].nested_maxtype = 1;
	ret = host_validate_parse_core((uintptr_t)nested_ok,
		sizeof(nested_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)nested_bad,
		sizeof(nested_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_bad", ret, 34);
	ret = host_validate_parse_core((uintptr_t)nested_ok,
		sizeof(nested_ok), 2, (uintptr_t)policy, HOST_VALIDATE_NESTED,
		0, 0);
	failed |= expect("nested_missing_flag", ret, 22);
	ret = host_validate_parse_core((uintptr_t)nested_flag_ok,
		sizeof(nested_flag_ok), 2, (uintptr_t)policy,
		HOST_VALIDATE_NESTED, 0, 0);
	failed |= expect("nested_flag_ok", ret, 0);
	policy[1].validation_type = HOST_POLICY_VALIDATE_NONE;
	policy[1].validate_result = 0;

	policy[1].type = HOST_NLA_NESTED_ARRAY;
	policy[1].kind = LEAN_KIND_NESTED_ARRAY_POLICY;
	ret = host_validate_parse_core((uintptr_t)nested_array_ok,
		sizeof(nested_array_ok), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_array_ok", ret, 0);
	ret = host_validate_parse_core((uintptr_t)nested_array_bad,
		sizeof(nested_array_bad), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_array_bad", ret, 34);
	ret = host_validate_parse_core((uintptr_t)nested_array_empty_entry,
		sizeof(nested_array_empty_entry), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_array_empty_entry", ret, 0);
	ret = host_validate_parse_core((uintptr_t)nested_array_tail,
		sizeof(nested_array_tail), 2, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_array_tail", ret, 0);
	policy[1].validation_type = HOST_POLICY_VALIDATE_NONE;
	policy[1].validate_result = 0;

	policy[1].type = HOST_NLA_NESTED;
	policy[1].kind = LEAN_KIND_NESTED_POLICY;
	policy[1].nested_policy = (uintptr_t)policy;
	policy[1].nested_maxtype = 1;
	ret = host_validate_parse_core((uintptr_t)deep_nested,
		deep_nested_len, 1, (uintptr_t)policy, 0, 0, 0);
	failed |= expect("nested_depth_limit", ret, 22);

	policy[1].type = HOST_NLA_U8;
	policy[1].kind = LEAN_KIND_EXACT;
	policy[1].exact_len = 1;
	policy[1].is_unspec = 0;
	policy[1].strict_start = 0;
	policy[1].strict_len = 0;
	ret = host_validate_parse_core((uintptr_t)nested_flag_ok,
		sizeof(nested_flag_ok), 2, (uintptr_t)policy,
		HOST_VALIDATE_NESTED, 0, 0);
	failed |= expect("nested_unexpected_flag", ret, 22);
	policy[2].type = 99;
	policy[2].kind = LEAN_KIND_UNSUPPORTED;
	ret = host_validate_parse_core((uintptr_t)valid, sizeof(valid), 2,
		(uintptr_t)policy, 0, 0, 0);
	failed |= expect("unsupported", ret, 1);

	policy[2].type = HOST_NLA_U32;
	policy[2].kind = LEAN_KIND_RANGE;
	policy[2].min_len = 1;
	policy[2].max_len = 256;
	ret = host_validate_parse_core((uintptr_t)valid, sizeof(valid), 2,
		(uintptr_t)policy, HOST_VALIDATE_MAXTYPE, 0, 0);
	failed |= expect("validate_flags", ret, 0);

	if (failed)
		return 1;
	puts("PASS: Lean nlattr scalar core");
	return 0;
}
