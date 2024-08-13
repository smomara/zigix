const tty = @import("tty.zig");
const vga = @import("vga.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const pic = @import("pic.zig");

const lib = @import("lib.zig");

export fn kernel_main() void {
    // initialize and enable interrupts
    gdt.init();
    idt.init();
    pic.init();
    tty.init();
    asm volatile ("sti");

    lib.print("Hello, welcome to ZigIX!\n");
    lib.print("This is a new line.\n");

    tty.set_color(vga.entry_color(.green, .black));
    lib.print("This text is green!\n");

    tty.set_color(vga.entry_color(.cyan, .light_gray));
    lib.print("Tabs:\t1\t2\t3\t4\n");

    tty.set_color(vga.entry_color(.green, .black));
    lib.print("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n");

    tty.set_color(vga.entry_color(.blue, .white));
    for (0..30) |_| {
        // lib.sleep(50);
        lib.print("lol\n");
    }
    lib.print("works!\n");

    lib.panic("Oh no!", .{});
}
