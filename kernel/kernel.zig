const std = @import("std");
const tty = @import("tty.zig");
const vga = @import("vga.zig");

export fn kernel_main() void {
    tty.init();

    tty.write("Hello, welcome to ZigIX!\n");
    tty.write("This is a new line.\n");

    tty.set_color(vga.entry_color(.green, .black));
    tty.write("This text is green!\n");

    tty.set_color(vga.entry_color(.cyan, .light_gray));
    tty.write("Tabs:\t1\t2\t3\t4\n");

    tty.set_color(vga.entry_color(.green, .black));
    tty.write("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.");
}
