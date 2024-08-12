const tty = @import("tty.zig");
const vga = @import("vga.zig");
const gdt = @import("gdt.zig");

fn do_not_optimize(value: anytype) void {
    asm volatile (""
        :
        : [value] "r" (value),
    );
}

fn sleep(ms: u64) void {
    const iterations = ms * 100000;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        do_not_optimize(i);
    }
}
export fn kernel_main() void {
    tty.init();
    gdt.init();

    tty.write("Hello, welcome to ZigIX!\n");
    tty.write("This is a new line.\n");

    tty.set_color(vga.entry_color(.green, .black));
    tty.write("This text is green!\n");

    tty.set_color(vga.entry_color(.cyan, .light_gray));
    tty.write("Tabs:\t1\t2\t3\t4\n");

    tty.set_color(vga.entry_color(.green, .black));
    tty.write("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.");

    tty.set_color(vga.entry_color(.blue, .white));
    for (0..30) |_| {
        sleep(5);
        tty.write("lol\n");
    }
    tty.write("works!\n");
}
