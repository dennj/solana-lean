#ifndef LEAN_FREESTANDING_H
#define LEAN_FREESTANDING_H

#include <stddef.h>
#include <stdint.h>

/* Lean object layout subset shared by freestanding runtime embedders.
   Mirrors the corresponding layout in src/include/lean/lean.h. */

typedef struct {
    int      m_rc;
    unsigned m_cs_sz:16;
    unsigned m_other:8;
    unsigned m_tag:8;
} lean_object;

typedef struct {
    lean_object   m_header;
    lean_object * m_objs[];
} lean_ctor_object;

typedef struct {
    lean_object m_header;
    size_t      m_size;
    size_t      m_capacity;
    size_t      m_length;
    char        m_data[];
} lean_string_object;

typedef struct {
    lean_object   m_header;
    size_t        m_size;
    size_t        m_capacity;
    lean_object * m_data[];
} lean_array_object;

typedef struct {
    lean_object m_header;
    size_t      m_size;
    size_t      m_capacity;
    uint8_t     m_data[];
} lean_sarray_object;

typedef struct {
    lean_object   m_header;
    lean_object * m_value;
} lean_ref_object;

#define LEAN_TAG_STRING        249
#define LEAN_TAG_ARRAY         246
#define LEAN_TAG_SCALAR_ARRAY  248
#define LEAN_TAG_REF           253

#endif
