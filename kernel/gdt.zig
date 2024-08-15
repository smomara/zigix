const std = @import("std");
const assert = std.debug.assert;

const ENTRIES = 6; // null, kernel code, kernel data, user code, user data, tss

pub const KERNEL_CODE_SELECTOR = 1 * @sizeOf(Entry);
pub const KERNEL_DATA_SELECTOR = 2 * @sizeOf(Entry);
pub const USER_CODE_SELECTOR = 3 * @sizeOf(Entry) | 3; // RPL 3
pub const USER_DATA_SELECTOR = 4 * @sizeOf(Entry) | 3; // RPL 3
pub const TSS_SELECTOR = 5 * @sizeOf(Entry);

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
        return @as(u32, self.base_low) | (@as(u32, self.base_middle) << 16) | (@as(u32, self.base_high) << 24);
    }

    fn get_limit(self: Entry) u32 {
        return @as(u32, self.limit_low) | ((@as(u32, self.granularity) & 0x0F) << 16);
    }
};

comptime {
    assert(@sizeOf(Entry) == 8);
}

const Pointer = packed struct {
    limit: u16,
    base: u32,
};

comptime {
    assert(@bitSizeOf(Pointer) == 48);
}

const TSS = packed struct {
    // reference: https://wiki.osdev.org/Task_State_Segment
    prev_tss: u16, // LINK at offset 0x00
    reserved1: u16 = 0,
    esp0: u32, // ESP0 at offset 0x04
    ss0: u16, // SS0 at offset 0x08
    reserved2: u16 = 0,
    esp1: u32, // ESP1 at offset 0x0C
    ss1: u16, // SS1 at offset 0x10
    reserved3: u16 = 0,
    esp2: u32, // ESP2 at offset 0x14
    ss2: u16, // SS2 at offset 0x18
    reserved4: u16 = 0,
    cr3: u32, // CR3 at offset 0x1C
    eip: u32, // EIP at offset 0x20
    eflags: u32, // EFLAGS at offset 0x24
    eax: u32, // EAX at offset 0x28
    ecx: u32, // ECX at offset 0x2C
    edx: u32, // EDX at offset 0x30
    ebx: u32, // EBX at offset 0x34
    esp: u32, // ESP at offset 0x38
    ebp: u32, // EBP at offset 0x3C
    esi: u32, // ESI at offset 0x40
    edi: u32, // EDI at offset 0x44
    es: u16, // ES at offset 0x48
    reserved5: u16 = 0,
    cs: u16, // CS at offset 0x4C
    reserved6: u16 = 0,
    ss: u16, // SS at offset 0x50
    reserved7: u16 = 0,
    ds: u16, // DS at offset 0x54
    reserved8: u16 = 0,
    fs: u16, // FS at offset 0x58
    reserved9: u16 = 0,
    gs: u16, // GS at offset 0x5C
    reserved10: u16 = 0,
    ldt: u16, // LDTR at offset 0x60
    reserved11: u16 = 0,
    trap: u16, // Trap at offset 0x64
    iomap_base: u16, // IOPB at offset 0x66
    ssp: u32, // SSP at offset 0x68
};

comptime {
    assert(@bitSizeOf(TSS) == 108 * 8); // 108 bytes
    assert(@offsetOf(TSS, "esp0") == 0x04);
    assert(@offsetOf(TSS, "ss0") == 0x08);
    assert(@offsetOf(TSS, "iomap_base") == 0x66);
}

var entries: [ENTRIES]Entry align(8) = undefined;
var pointer: Pointer = undefined;
var tss: TSS align(4) = std.mem.zeroes(TSS);

extern var stack_top: u8;

pub fn init() void {
    // Null descriptor
    entries[0] = Entry.init(0, 0, 0, 0);

    // Kernel code segment
    entries[1] = Entry.init(0, 0xFFFFF, 0x9A, 0xC0);

    // Kernel data segment
    entries[2] = Entry.init(0, 0xFFFFF, 0x92, 0xC0);

    // User code segment
    entries[3] = Entry.init(0, 0xFFFFF, 0xFA, 0xC0);

    // User data segment
    entries[4] = Entry.init(0, 0xFFFFF, 0xF2, 0xC0);

    // TSS
    const tss_base = @intFromPtr(&tss);
    const tss_limit = @sizeOf(TSS) - 1;
    entries[5] = Entry.init(tss_base, tss_limit, 0x89, 0);

    // GTD entry assertions
    assert(entries[0].get_base() == 0 and entries[0].get_limit() == 0);
    assert(entries[1].get_base() == 0 and entries[1].get_limit() == 0xFFFFF);
    assert(entries[2].get_base() == 0 and entries[2].get_limit() == 0xFFFFF);
    assert(entries[3].get_base() == 0 and entries[3].get_limit() == 0xFFFFF);
    assert(entries[4].get_base() == 0 and entries[4].get_limit() == 0xFFFFF);
    assert(entries[5].get_base() == tss_base and entries[5].get_limit() == tss_limit);

    assert(entries[1].access == 0x9A and entries[1].granularity == 0xCF);
    assert(entries[2].access == 0x92 and entries[2].granularity == 0xCF);
    assert(entries[3].access == 0xFA and entries[3].granularity == 0xCF);
    assert(entries[4].access == 0xF2 and entries[4].granularity == 0xCF);
    assert(entries[5].access == 0x89 and entries[5].granularity == 0x00);

    // set up GDTR
    pointer = .{
        .limit = @sizeOf(@TypeOf(entries)) - 1,
        .base = @intFromPtr(&entries),
    };

    // initialize TSS
    tss.ss0 = KERNEL_DATA_SELECTOR;
    tss.esp0 = @intFromPtr(&stack_top);
    tss.iomap_base = @sizeOf(TSS);

    // Load GDT
    asm volatile ("lgdt (%[pointer])"
        :
        : [pointer] "r" (&pointer),
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

    // assertions to check if segment registers are set correctly
    var ds: u16 = undefined;
    var cs: u16 = undefined;
    var ss: u16 = undefined;
    var tr: u16 = undefined;
    asm volatile (
        \\  movw %%ds, %[ds]
        \\  movw %%cs, %[cs]
        \\  movw %%ss, %[ss]
        \\  str %[tr]
        : [ds] "=r" (ds),
          [cs] "=r" (cs),
          [ss] "=r" (ss),
          [tr] "=r" (tr),
    );
    assert(ds == KERNEL_DATA_SELECTOR);
    assert(cs == KERNEL_CODE_SELECTOR);
    assert(ss == KERNEL_DATA_SELECTOR);
    assert(tr == TSS_SELECTOR);
}
