const pic = @import("pic.zig");
const idt = @import("idt.zig");

const PIT_CHANNEL0 = 0x40;
const PIT_CHANNEL1 = 0x41;
const PIT_CHANNEL2 = 0x42;
const PIT_COMMAND = 0x43;

const PIT_OCW_MASK_BINCOUNT = 1;
const PIT_OCW_MASK_MODE = 0xE;
const PIT_OCW_MASK_RL = 0x30;
const PIT_OCW_MASK_COUNTER = 0xC0;

const PIT_OCW_BINCOUNT_BINARY = 0;
const PIT_OCW_BINCOUNT_BCD = 1;

const PIT_OCW_MODE_TERMINALCOUNT = 0;
const PIT_OCW_MODE_ONESHOT = 0x2;
const PIT_OCW_MODE_RATEGEN = 0x4;
const PIT_OCW_MODE_SQUAREWAVEGEN = 0x6;
const PIT_OCW_MODE_SOFTWARETRIG = 0x8;
const PIT_OCW_MODE_HARDWARETRIG = 0xA;

const PIT_OCW_RL_LATCH = 0;
const PIT_OCW_RL_LSBONLY = 0x10;
const PIT_OCW_RL_MSBONLY = 0x20;
const PIT_OCW_RL_DATA = 0x30;

const PIT_OCW_COUNTER_0 = 0;
const PIT_OCW_COUNTER_1 = 0x40;
const PIT_OCW_COUNTER_2 = 0x80;

const TIMER_IRQ = 0;
const INTERRUPT_GATE = 0x8E;

var ticks: u64 = 0;

pub fn init() void {
    // Set up the timer to generate an interrupt every 1ms (1000 Hz)
    const divisor: u16 = 1193; // 1.193182 MHz / 1000 Hz

    pic.outb(PIT_COMMAND, PIT_OCW_MASK_COUNTER | PIT_OCW_MASK_RL | PIT_OCW_MASK_MODE | PIT_OCW_BINCOUNT_BINARY);

    pic.outb(PIT_CHANNEL0, @intCast(divisor & 0xFF));
    pic.outb(PIT_CHANNEL0, @intCast((divisor >> 8) & 0xFF));

    // Register the timer IRQ handler
    // Note: This part depends on your IDT setup, so you might need to adjust it
    idt.set_gate(32, timer_handler, INTERRUPT_GATE, 0);
}

pub fn timer_handler() callconv(.Interrupt) void {
    ticks += 1;
    if (ticks % 1000 == 0) {
        // One second has passed
        // You can add any per-second operations here
    }
    pic.send_eoi(TIMER_IRQ);
}

pub fn get_ticks() u64 {
    return ticks;
}

pub fn sleep(ms: u64) void {
    const start = ticks;
    while (ticks - start < ms) {
        asm volatile ("hlt");
    }
}
