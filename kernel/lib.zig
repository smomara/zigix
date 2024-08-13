const tty = @import("tty.zig");
const vga = @import("vga.zig");
const std = @import("std");

pub fn panic(comptime format: []const u8, args: anytype) noreturn {
    asm volatile ("cli"); // disable interrupts

    tty.set_color(vga.entry_color(.light_red, .black));

    print("KERNEL_PANIC: ");
    printf(format, args);
    print("\n");

    while (true) {
        asm volatile ("hlt");
    }
}

pub fn print(msg: []const u8) void {
    tty.write(msg);
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    print(std.fmt.comptimePrint(format, args));
}

pub fn sleep(ms: u64) void {
    const iterations = ms * 100000;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        asm volatile (""
            :
            : [value] "r" (i),
        );
    }
}
