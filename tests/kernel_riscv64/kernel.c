#include "lean_freestanding.h"

extern void *lean_kernel_module_init(unsigned char builtin, void *world);
extern uint64_t lean_kernel_invoke_entry(void);
extern uint64_t lean_kernel_trap_entry_io(uint64_t boots, uint64_t scause, uint64_t sepc,
    uint64_t stval, uint64_t syscall_no, uint64_t syscall_arg, void *world);
extern void kernel_trap_vector(void);

static volatile uint8_t *const uart0 = (volatile uint8_t *)0x10000000UL;
static volatile uint64_t *const clint_mtimecmp = (volatile uint64_t *)0x02004000UL;
static volatile uint64_t *const clint_mtime = (volatile uint64_t *)0x0200bff8UL;
static const uint64_t timer_interval = 1000000UL;
static uint64_t kernel_state_boots = 0;

static void raw_putc(uint8_t c) {
    *uart0 = c;
}

void lean_freestanding_log(const char *msg, uint64_t len) {
    for (uint64_t i = 0; i < len; ++i) {
        raw_putc((uint8_t)msg[i]);
    }
    raw_putc((uint8_t)'\n');
}

void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b) {
    (void)a;
    (void)b;
    while (*what) {
        raw_putc((uint8_t)*what++);
    }
    raw_putc((uint8_t)'\n');
    for (;;) {}
}

void *kernel_store8(uint64_t addr, uint8_t value) {
    *(volatile uint8_t *)(uintptr_t)addr = value;
    return (void *)1;
}

void *kernel_store8_u64(uint64_t addr, uint64_t value) {
    *(volatile uint8_t *)(uintptr_t)addr = (uint8_t)value;
    return (void *)1;
}

void *kernel_store64(uint64_t addr, uint64_t value) {
    *(volatile uint64_t *)(uintptr_t)addr = value;
    return (void *)1;
}

uint8_t kernel_load8(uint64_t addr) {
    return *(volatile uint8_t *)(uintptr_t)addr;
}

uint64_t kernel_load64(uint64_t addr) {
    return *(volatile uint64_t *)(uintptr_t)addr;
}

uint64_t kernel_trap_vector_addr(void *unit) {
    (void)unit;
    return (uint64_t)(uintptr_t)&kernel_trap_vector;
}

void *kernel_write_stvec(uint64_t addr) {
    __asm__ volatile ("csrw stvec, %0" :: "r"(addr) : "memory");
    return (void *)1;
}

void *kernel_write_satp(uint64_t satp) {
    __asm__ volatile ("csrw satp, %0" :: "r"(satp) : "memory");
    return (void *)1;
}

void *kernel_write_sepc(uint64_t sepc) {
    __asm__ volatile ("csrw sepc, %0" :: "r"(sepc) : "memory");
    return (void *)1;
}

void *kernel_set_timer(void *unit) {
    (void)unit;
    /* OpenSBI 3.0 PMP-protects the CLINT region from S-mode (boot log shows
       `Domain0 Region02 0x02000000-0x0200ffff M: (I,R,W) S/U: ()` — no S/U
       access). Direct loads from `clint_mtime`/`clint_mtimecmp` therefore
       trap with scause=5 (load access fault). Use the SBI Time extension
       (EID = 'TIME', FID = 0) to program the next timer, and the user-mode
       `time` CSR (`Zicntr`, advertised in the boot log) to read the current
       time. */
    uint64_t now;
    __asm__ volatile ("csrr %0, time" : "=r"(now));
    register uintptr_t a7 __asm__("a7") = 0x54494D45UL; /* 'TIME' EID */
    register uintptr_t a6 __asm__("a6") = 0;            /* FID 0 = set_timer */
    register uint64_t  a0 __asm__("a0") = now + timer_interval;
    __asm__ volatile ("ecall"
                      : "+r"(a0)
                      : "r"(a6), "r"(a7)
                      : "memory");
    __asm__ volatile ("csrs sie, %0" :: "r"(1ULL << 5) : "memory");
    return (void *)1;
}

void *kernel_enter_user(uint64_t entry) {
    uint64_t sstatus;
    __asm__ volatile ("csrr %0, sstatus" : "=r"(sstatus));
    sstatus &= ~(1ULL << 8);
    sstatus |= (1ULL << 5);
    __asm__ volatile (
        "csrw sstatus, %0\n"
        "csrw sepc, %1\n"
        "sret\n"
        :: "r"(sstatus), "r"(entry) : "memory");
    for (;;) {}
}

void *kernel_set_state_boots(uint64_t boots) {
    kernel_state_boots = boots;
    return (void *)1;
}

void *kernel_deny_bad_page_table_action(void *unit) {
    (void)unit;
    lean_freestanding_log("bad page-table action denied", 28);
    return (void *)1;
}

void *kernel_deny_unhandled_trap(uint64_t scause, uint64_t stval) {
    (void)scause;
    (void)stval;
    lean_freestanding_log("unhandled trap denied", 21);
    return (void *)1;
}

void *kernel_sfence_vma(void *unit) {
    (void)unit;
    __asm__ volatile ("sfence.vma" ::: "memory");
    return (void *)1;
}

void *kernel_probe_breakpoint_trap(void *unit) {
    (void)unit;
    __asm__ volatile (".4byte 0x00100073" ::: "memory");
    return (void *)1;
}

void kernel_trap(uint64_t scause, uint64_t sepc, uint64_t stval,
    uint64_t syscall_no, uint64_t syscall_arg) {
    (void)lean_kernel_trap_entry_io(kernel_state_boots, scause, sepc, stval,
        syscall_no, syscall_arg, (void *)0);
}

void kmain(uint64_t hartid, void *fdt) {
    (void)hartid;
    (void)fdt;
    (void)lean_kernel_module_init(0, (void *)0);
    (void)lean_kernel_invoke_entry();
    for (;;) {}
}
