const std = @import("std");
const boot = @import("boot.zig");

const GDT_ENTRIES = 6; // null, kernel code, kernel data, user code, user data, tss

pub const KERNEL_CODE_SELECTOR = 1 * @sizeOf(Entry);
pub const KERNEL_DATA_SELECTOR = 2 * @sizeOf(Entry);
pub const USER_CODE_SELECTOR = 3 * @sizeOf(Entry) | 3; // RPL 3
pub const USER_DATA_SELECTOR = 4 * @sizeOf(Entry) | 3; // RPL 3
pub const TSS_SELECTOR = 5 * @sizeOf(Entry);

// Access byte flags
const PRESENT = 1 << 7;
const RING0 = 0 << 5;
const RING3 = 3 << 5;
const S = 1 << 4;
const EXECUTABLE = 1 << 3;
const DIRECTION = 1 << 2;
const RW = 1 << 1;

// Granularity byte flags
const PAGE_GRANULARITY = 1 << 7;
const PROTECTED_MODE = 1 << 6;

// TSS flags
const TSS_AVAILABLE = 0x9;

const Entry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,

    fn init(base: u32, limit: u32, access: u8, flags: u8) Entry {
        return .{
            .limit_low = @truncate(limit & 0xFFFF),
            .base_low = @truncate(base & 0xFFFF),
            .base_middle = @truncate((base >> 16) & 0xFF),
            .access = access,
            .granularity = @truncate(((limit >> 16) & 0x0F) | (flags & 0xF0)),
            .base_high = @truncate((base >> 24) & 0xFF),
        };
    }

    fn get_base(self: Entry) u32 {
        return @as(u32, self.base_low) |
            (@as(u32, self.base_middle) << 16) |
            (@as(u32, self.base_high) << 24);
    }

    fn get_limit(self: Entry) u32 {
        var limit: u32 = @as(u32, self.limit_low) |
            (@as(u32, self.granularity & 0x0F) << 16);
        if (self.granularity & PAGE_GRANULARITY != 0) {
            limit = (limit << 12) | 0xFFF;
        }
        return limit;
    }
};

const Pointer = packed struct {
    limit: u16,
    base: u32,
};

const TSS = packed struct {
    prev_tss: u32,
    esp0: u32,
    ss0: u32,
    esp1: u32,
    ss1: u32,
    esp2: u32,
    ss2: u32,
    cr3: u32,
    eip: u32,
    eflags: u32,
    eax: u32,
    ecx: u32,
    edx: u32,
    ebx: u32,
    esp: u32,
    ebp: u32,
    esi: u32,
    edi: u32,
    es: u32,
    cs: u32,
    ss: u32,
    ds: u32,
    fs: u32,
    gs: u32,
    ldt: u32,
    trap: u16,
    iomap_base: u16,
};

var gdt: [GDT_ENTRIES]Entry = undefined;
var gdtr: Pointer = undefined;
var tss: TSS align(4) = std.mem.zeroes(TSS);

extern var stack_top: u8;

pub fn init() void {
    // Null descriptor
    gdt[0] = Entry.init(0, 0, 0, 0);

    // Kernel code segment
    gdt[1] = Entry.init(0, 0xFFFFFFFF, PRESENT | RING0 | S | EXECUTABLE | RW, PAGE_GRANULARITY | PROTECTED_MODE);

    // Kernel data segment
    gdt[2] = Entry.init(0, 0xFFFFFFFF, PRESENT | RING0 | S | RW, PAGE_GRANULARITY | PROTECTED_MODE);

    // User code segment
    gdt[3] = Entry.init(0, 0xFFFFFFFF, PRESENT | RING3 | S | EXECUTABLE | RW, PAGE_GRANULARITY | PROTECTED_MODE);

    // User data segment
    gdt[4] = Entry.init(0, 0xFFFFFFFF, PRESENT | RING3 | S | RW, PAGE_GRANULARITY | PROTECTED_MODE);

    // TSS
    const tss_base = @intFromPtr(&tss);
    const tss_limit = @sizeOf(TSS) - 1;
    gdt[5] = Entry.init(tss_base, tss_limit, PRESENT | RING0 | TSS_AVAILABLE, 0);

    // Set up GDTR
    gdtr = .{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    // Initialize TSS
    tss.ss0 = KERNEL_DATA_SELECTOR;
    tss.esp0 = @intFromPtr(&stack_top);
    tss.iomap_base = @sizeOf(TSS);

    // Verify GDT
    std.debug.assert(gdt[0].get_base() == 0 and gdt[0].get_limit() == 0);
    std.debug.assert(gdt[1].get_base() == 0 and gdt[1].get_limit() == 0xFFFFFFFF);
    std.debug.assert(gdt[2].get_base() == 0 and gdt[2].get_limit() == 0xFFFFFFFF);
    std.debug.assert(gdt[3].get_base() == 0 and gdt[3].get_limit() == 0xFFFFFFFF);
    std.debug.assert(gdt[4].get_base() == 0 and gdt[4].get_limit() == 0xFFFFFFFF);

    std.debug.assert(gdt[1].access == (PRESENT | RING0 | S | EXECUTABLE | RW));
    std.debug.assert(gdt[2].access == (PRESENT | RING0 | S | RW));
    std.debug.assert(gdt[3].access == (PRESENT | RING3 | S | EXECUTABLE | RW));
    std.debug.assert(gdt[4].access == (PRESENT | RING3 | S | RW));

    std.debug.assert(gdt[1].granularity & 0xF0 == (PAGE_GRANULARITY | PROTECTED_MODE));
    std.debug.assert(gdt[2].granularity & 0xF0 == (PAGE_GRANULARITY | PROTECTED_MODE));
    std.debug.assert(gdt[3].granularity & 0xF0 == (PAGE_GRANULARITY | PROTECTED_MODE));
    std.debug.assert(gdt[4].granularity & 0xF0 == (PAGE_GRANULARITY | PROTECTED_MODE));

    std.debug.assert(gdtr.limit == @sizeOf(@TypeOf(gdt)) - 1);
    std.debug.assert(gdtr.base == @intFromPtr(&gdt));

    // Verify TSS
    std.debug.assert(gdt[5].get_base() == @intFromPtr(&tss));
    std.debug.assert(gdt[5].get_limit() == @sizeOf(TSS) - 1);
    std.debug.assert(gdt[5].access == (PRESENT | RING0 | TSS_AVAILABLE));
    std.debug.assert(gdt[5].granularity & 0xF0 == 0); // TSS should not use page granularity

    std.debug.assert(tss.ss0 == KERNEL_DATA_SELECTOR);
    std.debug.assert(tss.esp0 == @intFromPtr(&stack_top));
    std.debug.assert(tss.iomap_base == @sizeOf(TSS));

    // Load GDT
    asm volatile ("lgdt (%[gdtr])"
        :
        : [gdtr] "r" (&gdtr),
    );

    // Update segment registers
    asm volatile (
        \\  movw %[kernel_ds], %%ds
        \\  movw %[kernel_ds], %%es
        \\  movw %[kernel_ds], %%fs
        \\  movw %[kernel_ds], %%gs
        \\  movw %[kernel_ds], %%ss
        \\  pushl %[kernel_cs]
        \\  pushl $1f
        \\  lret
        \\1:
        \\  movw %[tss_selector], %%ax
        \\  ltr %%ax
        :
        : [kernel_ds] "r" (@as(u16, KERNEL_DATA_SELECTOR)),
          [kernel_cs] "r" (@as(u32, KERNEL_CODE_SELECTOR)),
          [tss_selector] "r" (@as(u16, TSS_SELECTOR)),
    );
}
