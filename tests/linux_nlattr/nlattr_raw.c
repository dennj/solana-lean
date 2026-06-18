// SPDX-License-Identifier: GPL-2.0

#include <stdint.h>
#include <stddef.h>

typedef uint64_t u64;
typedef uint8_t u8;

#define LEAN_TAG_SCALAR_ARRAY 248

struct lean_object {
	int m_rc;
	unsigned m_cs_sz:16;
	unsigned m_other:8;
	unsigned m_tag:8;
};

struct lean_sarray_object {
	struct lean_object m_header;
	size_t m_size;
	size_t m_capacity;
	u8 m_data[];
};

extern void *lean_alloc_object(size_t size);

__attribute__((always_inline))
u64 lean_nlattr_raw_ptr_byte(u64 ptr, u64 ix)
{
	const u8 *data = (const u8 *)(uintptr_t)ptr;

	return data[ix];
}

__attribute__((always_inline))
u64 lean_nlattr_raw_ptr_set_byte(u64 ptr, u64 ix, u64 value)
{
	u8 *data = (u8 *)(uintptr_t)ptr;

	data[ix] = (u8)value;
	return 0;
}

void *lean_nlattr_raw_byte_array(u64 ptr, u64 len)
{
	const u8 *src = (const u8 *)(uintptr_t)ptr;
	size_t size = (size_t)len;
	struct lean_sarray_object *array;
	size_t i;

	array = lean_alloc_object(sizeof(*array) + size);
	array->m_header.m_rc = 1;
	array->m_header.m_cs_sz = 0;
	array->m_header.m_other = 1;
	array->m_header.m_tag = LEAN_TAG_SCALAR_ARRAY;
	array->m_size = size;
	array->m_capacity = size;
	for (i = 0; i < size; i++)
		array->m_data[i] = src[i];
	return array;
}

__attribute__((always_inline))
u64 lean_nlattr_raw_set_tb(u64 tb, u64 ty, u64 attr)
{
	u64 *table = (u64 *)(uintptr_t)tb;

	table[ty] = attr;
	return 0;
}
