const tty = @import("tty.zig");
const vga = @import("vga.zig");
const pit = @import("pit.zig");

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

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    @setEvalBranchQuota(2000);
    comptime var i = 0;
    comptime var arg_i = 0;
    inline while (i < fmt.len) {
        if (fmt[i] == '%') {
            i += 1;
            if (i < fmt.len) {
                switch (fmt[i]) {
                    's' => tty.write(args[arg_i]),
                    'd' => printInt(args[arg_i]),
                    'x' => printHex(args[arg_i]),
                    '%' => tty.write("%"),
                    else => tty.write("?"),
                }
                arg_i += 1;
            }
        } else {
            tty.write(&[_]u8{fmt[i]});
        }
        i += 1;
    }
}

fn printInt(value: anytype) void {
    if (value == 0) {
        tty.write("0");
        return;
    }
    var buf: [20]u8 = undefined;
    var i: usize = 0;
    var v = if (value < 0) -value else value;
    while (v > 0) : (v /= 10) {
        buf[i] = @intCast((v % 10) + '0');
        i += 1;
    }
    if (value < 0) {
        tty.write("-");
    }
    while (i > 0) {
        i -= 1;
        tty.write(&[_]u8{buf[i]});
    }
}

fn printHex(value: anytype) void {
    tty.write("0x");
    var buf: [16]u8 = undefined;
    var i: usize = 0;
    var v = value;
    while (v > 0 or i == 0) : (v >>= 4) {
        buf[i] = "0123456789abcdef"[v & 0xF];
        i += 1;
    }
    while (i > 0) {
        i -= 1;
        tty.write(&[_]u8{buf[i]});
    }
}

pub fn sleep(ms: u64) void {
    pit.sleep(ms);
}
