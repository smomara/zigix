const lib = @import("lib.zig");

const IDT_ENTRIES = 256;

const Entry = packed struct {
    offset_low: u16, // offset bits 0..15
    selector: u16, // a code segment selector in GDT or LDT
    zero: u8, // unused, set to 0
    type_attributes: u8, // gate types, dpl and p fields
    offset_high: u16, // offset bits 16..31

    fn init(offset: u32, selector: u16, type_attributes: u8) Entry {
        return .{
            .offset_low = @truncate(offset & 0xFFFF),
            .selector = selector,
            .zero = 0,
            .type_attributes = type_attributes,
            .offset_high = @truncate((offset >> 16) & 0xFFFF),
        };
    }
};

const Pointer = packed struct {
    limit: u16,
    base: u32,
};

var idt: [IDT_ENTRIES]Entry align(8) = undefined;

const INTERRUPT_GATE: u8 = 0x8E;
const TRAP_GATE: u8 = 0x8F;
const TASK_GATE: u8 = 0x85;

pub fn init() void {
    for (&idt) |*entry| {
        entry.* = Entry.init(0, 0, 0);
    }

    set_idt_gate(0, divide_error_handler, TRAP_GATE, 0);
    set_idt_gate(1, debug_exception_handler, TRAP_GATE, 0);
    set_idt_gate(2, nmi_handler, INTERRUPT_GATE, 0);
    set_idt_gate(3, breakpoint_handler, TRAP_GATE, 3);
    set_idt_gate(4, overflow_handler, TRAP_GATE, 0);
    set_idt_gate(5, bound_range_exceeded_handler, TRAP_GATE, 0);
    set_idt_gate(6, invalid_opcode_handler, TRAP_GATE, 0);
    set_idt_gate(7, device_not_available_handler, TRAP_GATE, 0);
    set_idt_gate(8, double_fault_handler, TRAP_GATE, 0);
    set_idt_gate(9, coprocessor_segment_overrun_handler, TRAP_GATE, 0);
    set_idt_gate(10, invalid_tss_handler, TRAP_GATE, 0);
    set_idt_gate(11, segment_not_present_handler, TRAP_GATE, 0);
    set_idt_gate(12, stack_segment_fault_handler, TRAP_GATE, 0);
    set_idt_gate(13, general_protection_fault_handler, TRAP_GATE, 0);
    set_idt_gate(14, page_fault_handler, TRAP_GATE, 0);
    set_idt_gate(15, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(16, x87_floating_point_exception_handler, TRAP_GATE, 0);
    set_idt_gate(17, alignment_check_handler, TRAP_GATE, 0);
    set_idt_gate(18, machine_check_handler, TRAP_GATE, 0);
    set_idt_gate(19, simd_floating_point_exception_handler, TRAP_GATE, 0);
    set_idt_gate(20, virtualization_exception_handler, TRAP_GATE, 0);
    set_idt_gate(21, control_protection_exception_handler, TRAP_GATE, 0);
    set_idt_gate(22, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(23, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(24, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(25, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(26, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(27, reserved_exception_handler, TRAP_GATE, 0);
    set_idt_gate(28, hypervisor_injection_exception_handler, TRAP_GATE, 0);
    set_idt_gate(29, vmm_communication_exception_handler, TRAP_GATE, 0);
    set_idt_gate(30, security_exception_handler, TRAP_GATE, 0);
    set_idt_gate(31, reserved_exception_handler, TRAP_GATE, 0);

    const idtr = Pointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );
}

fn set_idt_gate(n: u8, handler: *const fn () callconv(.Interrupt) void, gate_type: u8, dpl: u2) void {
    const addr = @intFromPtr(handler);
    idt[n] = Entry.init(addr, 0x08, gate_type | (@as(u8, dpl) << 5));
}

fn divide_error_handler() callconv(.Interrupt) void {
    lib.panic("Divide Error (#DE)", .{});
}

fn debug_exception_handler() callconv(.Interrupt) void {
    lib.panic("Debug Exception (#DB)", .{});
}

fn nmi_handler() callconv(.Interrupt) void {
    lib.panic("Non-Maskable Interrupt (NMI)", .{});
}

fn breakpoint_handler() callconv(.Interrupt) void {
    lib.panic("Breakpoint (#BP)", .{});
}

fn overflow_handler() callconv(.Interrupt) void {
    lib.panic("Overflow (#OF)", .{});
}

fn bound_range_exceeded_handler() callconv(.Interrupt) void {
    lib.panic("Bound Range Exceeded (#BR)", .{});
}

fn invalid_opcode_handler() callconv(.Interrupt) void {
    lib.panic("Invalid Opcode (#UD)", .{});
}

fn device_not_available_handler() callconv(.Interrupt) void {
    lib.panic("Device Not Available (#NM)", .{});
}

fn double_fault_handler() callconv(.Interrupt) void {
    lib.panic("Double Fault (#DF)", .{});
}

fn coprocessor_segment_overrun_handler() callconv(.Interrupt) void {
    lib.panic("Coprocessor Segment Overrun", .{});
}

fn invalid_tss_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Invalid TSS (#TS), Error Code: {}", .{error_code});
}

fn segment_not_present_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Segment Not Present (#NP), Error Code: {}", .{error_code});
}

fn stack_segment_fault_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Stack-Segment Fault (#SS), Error Code: {}", .{error_code});
}

fn general_protection_fault_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("General Protection Fault (#GP), Error Code: {}", .{error_code});
}

fn page_fault_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    const cr2_value = asm volatile ("mov %%cr2, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Page Fault (#PF), Error Code: {}, CR2: {x}", .{ error_code, cr2_value });
}

fn x87_floating_point_exception_handler() callconv(.Interrupt) void {
    lib.panic("x87 Floating-Point Exception (#MF)", .{});
}

fn alignment_check_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Alignment Check (#AC), Error Code: {}", .{error_code});
}

fn machine_check_handler() callconv(.Interrupt) void {
    lib.panic("Machine Check (#MC)", .{});
}

fn simd_floating_point_exception_handler() callconv(.Interrupt) void {
    lib.panic("SIMD Floating-Point Exception (#XM)", .{});
}

fn virtualization_exception_handler() callconv(.Interrupt) void {
    lib.panic("Virtualization Exception (#VE)", .{});
}

fn control_protection_exception_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Control Protection Exception (#CP), Error Code: {}", .{error_code});
}

fn hypervisor_injection_exception_handler() callconv(.Interrupt) void {
    lib.panic("Hypervisor Injection Exception (#HV)", .{});
}

fn vmm_communication_exception_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("VMM Communication Exception (#VC), Error Code: {}", .{error_code});
}

fn security_exception_handler() callconv(.Interrupt) void {
    const error_code = asm volatile ("mov %%esp, %%eax"
        : [ret] "={eax}" (-> usize),
        :
        : "memory"
    );
    lib.panic("Security Exception (#SX), Error Code: {}", .{error_code});
}

fn reserved_exception_handler() callconv(.Interrupt) void {
    lib.panic("Reserved Exception", .{});
}
