#include <stdint.h>

#define UART_BASE             0x10000000u
#define UART_TXDATA           (*(volatile uint32_t *)(UART_BASE + 0x00u))
#define UART_STATUS           (*(volatile uint32_t *)(UART_BASE + 0x08u))
#define UART_BAUD_DIV         (*(volatile uint32_t *)(UART_BASE + 0x0Cu))
#define UART_CTRL             (*(volatile uint32_t *)(UART_BASE + 0x10u))
#define UART_STATUS_TX_READY  (1u << 0)

#define CORDIC_BASE           0x10001000u
#define CORDIC_ID_VERSION     (*(volatile uint32_t *)(CORDIC_BASE + 0x00u))
#define CORDIC_CONTROL        (*(volatile uint32_t *)(CORDIC_BASE + 0x04u))
#define CORDIC_STATUS         (*(volatile uint32_t *)(CORDIC_BASE + 0x08u))
#define CORDIC_OPCODE         (*(volatile uint32_t *)(CORDIC_BASE + 0x0Cu))
#define CORDIC_X              (*(volatile int32_t  *)(CORDIC_BASE + 0x10u))
#define CORDIC_Y              (*(volatile int32_t  *)(CORDIC_BASE + 0x14u))
#define CORDIC_ANGLE          (*(volatile int32_t  *)(CORDIC_BASE + 0x18u))
#define CORDIC_RESULT0        (*(volatile int32_t  *)(CORDIC_BASE + 0x1Cu))
#define CORDIC_RESULT1        (*(volatile int32_t  *)(CORDIC_BASE + 0x20u))
#define CORDIC_IRQ_ENABLE     (*(volatile uint32_t *)(CORDIC_BASE + 0x24u))
#define CORDIC_IRQ_STATUS     (*(volatile uint32_t *)(CORDIC_BASE + 0x28u))
#define CORDIC_ERROR_CODE     (*(volatile uint32_t *)(CORDIC_BASE + 0x2Cu))

#define CORDIC_CONTROL_START      (1u << 0)
#define CORDIC_CONTROL_SOFT_RESET (1u << 1)
#define CORDIC_CONTROL_CLEAR_DONE (1u << 2)
#define CORDIC_CONTROL_CLEAR_ERR  (1u << 3)
#define CORDIC_STATUS_IDLE        (1u << 0)
#define CORDIC_STATUS_BUSY        (1u << 1)
#define CORDIC_STATUS_DONE        (1u << 2)
#define CORDIC_STATUS_ERROR       (1u << 3)
#define CORDIC_STATUS_IRQ_PENDING (1u << 4)
#define CORDIC_OPCODE_ATAN2       0u
#define CORDIC_OPCODE_SINCOS      1u
#define CORDIC_ID_MAGIC           0x434F5244u
#define CORDIC_ERR_NONE           0u
#define CORDIC_ERR_BUSY           1u
#define CORDIC_ERR_BAD_OPCODE     2u

static inline int32_t abs32(int32_t value) {
    return (value < 0) ? -value : value;
}

static void uart_putc(char ch) {
    while ((UART_STATUS & UART_STATUS_TX_READY) == 0u) {
    }
    UART_TXDATA = (uint32_t)(uint8_t)ch;
}

static void uart_puts(const char *text) {
    while (*text != '\0') {
        uart_putc(*text++);
    }
}

static void uart_put_hex32(uint32_t value) {
    for (int shift = 28; shift >= 0; shift -= 4) {
        uint32_t nibble = (value >> shift) & 0xFu;
        uart_putc((char)(nibble < 10u ? ('0' + nibble) : ('A' + nibble - 10u)));
    }
}

static void fail(const char *reason, uint32_t got, uint32_t expected) {
    uart_puts("FAIL ");
    uart_puts(reason);
    uart_puts(" got=");
    uart_put_hex32(got);
    uart_puts(" exp=");
    uart_put_hex32(expected);
    uart_puts("\n");
    while (1) {
    }
}

static void cordic_wait_done(void) {
    while ((CORDIC_STATUS & CORDIC_STATUS_DONE) == 0u) {
    }
    if ((CORDIC_STATUS & CORDIC_STATUS_ERROR) != 0u) {
        fail("STATUS", CORDIC_STATUS, 0u);
    }
}

static void check_close(const char *name, int32_t actual, int32_t expected, int32_t tolerance) {
    if (abs32(actual - expected) > tolerance) {
        fail(name, (uint32_t)actual, (uint32_t)expected);
    }
}

int main(void) {
    int32_t phase_45;
    int32_t cos_0;
    int32_t sin_0;
    int32_t cos_45;
    int32_t sin_45;
    uint32_t status;

    UART_BAUD_DIV = 7u;
    UART_CTRL = 1u;

    uart_puts("CORDIC boot\n");

    if (CORDIC_ID_VERSION != CORDIC_ID_MAGIC) {
        fail("ID", CORDIC_ID_VERSION, CORDIC_ID_MAGIC);
    }

    CORDIC_IRQ_ENABLE = 1u;
    CORDIC_CONTROL = CORDIC_CONTROL_SOFT_RESET;
    if ((CORDIC_STATUS & (CORDIC_STATUS_DONE | CORDIC_STATUS_ERROR | CORDIC_STATUS_IRQ_PENDING)) != 0u) {
        fail("RESET_STATUS", CORDIC_STATUS, 0u);
    }
    if (CORDIC_ERROR_CODE != CORDIC_ERR_NONE) {
        fail("RESET_ERR", CORDIC_ERROR_CODE, CORDIC_ERR_NONE);
    }

    CORDIC_OPCODE = CORDIC_OPCODE_SINCOS;
    CORDIC_ANGLE = 0;
    CORDIC_CONTROL = CORDIC_CONTROL_START;
    cordic_wait_done();
    status = CORDIC_STATUS;
    if ((status & (CORDIC_STATUS_DONE | CORDIC_STATUS_IRQ_PENDING)) !=
        (CORDIC_STATUS_DONE | CORDIC_STATUS_IRQ_PENDING)) {
        fail("SINCOS0_STATUS", status, CORDIC_STATUS_DONE | CORDIC_STATUS_IRQ_PENDING);
    }
    cos_0 = CORDIC_RESULT0;
    sin_0 = CORDIC_RESULT1;
    CORDIC_CONTROL = CORDIC_CONTROL_CLEAR_DONE;
    if ((CORDIC_STATUS & CORDIC_STATUS_DONE) != 0u) {
        fail("CLR_DONE0", CORDIC_STATUS, 0u);
    }

    CORDIC_ANGLE = 51472;
    CORDIC_CONTROL = CORDIC_CONTROL_START;
    cordic_wait_done();
    cos_45 = CORDIC_RESULT0;
    sin_45 = CORDIC_RESULT1;
    CORDIC_CONTROL = CORDIC_CONTROL_CLEAR_DONE;

    check_close("COS0", cos_0, 65536, 2);
    check_close("SIN0", sin_0, 0, 2);
    check_close("COS45", cos_45, 46341, 8);
    check_close("SIN45", sin_45, 46341, 8);

    CORDIC_OPCODE = CORDIC_OPCODE_ATAN2;
    CORDIC_X = 65536;
    CORDIC_Y = 65536;
    CORDIC_CONTROL = CORDIC_CONTROL_START;
    cordic_wait_done();
    phase_45 = CORDIC_RESULT0;
    check_close("ATAN45", phase_45, 51472, 8);
    CORDIC_CONTROL = CORDIC_CONTROL_CLEAR_DONE;

    CORDIC_OPCODE = 99u;
    CORDIC_CONTROL = CORDIC_CONTROL_START;
    status = CORDIC_STATUS;
    if ((status & CORDIC_STATUS_ERROR) == 0u) {
        fail("BADOP_STATUS", status, CORDIC_STATUS_ERROR);
    }
    if (CORDIC_ERROR_CODE != CORDIC_ERR_BAD_OPCODE) {
        fail("BADOP_ERR", CORDIC_ERROR_CODE, CORDIC_ERR_BAD_OPCODE);
    }
    CORDIC_CONTROL = CORDIC_CONTROL_CLEAR_ERR;
    if ((CORDIC_STATUS & CORDIC_STATUS_ERROR) != 0u) {
        fail("CLR_ERR", CORDIC_STATUS, 0u);
    }
    if (CORDIC_ERROR_CODE != CORDIC_ERR_NONE) {
        fail("CLR_ERR_CODE", CORDIC_ERROR_CODE, CORDIC_ERR_NONE);
    }

    uart_puts("CORDIC ok cos0=");
    uart_put_hex32((uint32_t)cos_0);
    uart_puts(" cos45=");
    uart_put_hex32((uint32_t)cos_45);
    uart_puts(" atan45=");
    uart_put_hex32((uint32_t)phase_45);
    uart_puts("\nPASS\n");

    __asm__ volatile("ebreak");
    while (1) {
    }
}
