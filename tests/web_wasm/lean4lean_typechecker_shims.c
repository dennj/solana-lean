typedef struct {
    int      m_rc;
    unsigned m_cs_sz:16;
    unsigned m_other:8;
    unsigned m_tag:8;
} lean_object;

extern lean_object *l_Lean_instInhabitedExpr;
extern lean_object *lean_mk_string_from_bytes(const char *s, unsigned long sz);
extern void *bump_alloc(unsigned long size);

lean_object *_init_l_Lean_instInhabitedExpr(void) {
    return l_Lean_instInhabitedExpr;
}

unsigned int lean4lean_alloc_bytes(unsigned int len) {
    return (unsigned int)(unsigned long)bump_alloc((unsigned long)len);
}

lean_object *lean4lean_string_from_bytes(unsigned int ptr, unsigned int len) {
    return lean_mk_string_from_bytes((const char *)(unsigned long)ptr, (unsigned long)len);
}
