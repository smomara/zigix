const std = @import("std");

const VgaWidth = 80;
const VgaHeight = 25;

const VgaColor = enum {
    black,
    blue,
    green,
    cyan,
    red,
    magenta,
    brown,
    light_gray,
    dark_gray,
    light_blue,
    light_green,
    light_cyan,
    light_red,
    light_magenta,
    light_brown,
    white,
};

fn vga_entry_color(fg: VgaColor, bg: VgaColor) u8 {
    return @as(u8, @intFromEnum(fg)) | (@as(u8, @intFromEnum(bg)) << 4);
}

fn vga_entry(uc: u8, color: u8) u16 {
    return @as(u16, uc) | (@as(u16, color) << 8);
}

var terminal_row: usize = 0;
var terminal_column: usize = 0;
var terminal_color: u8 = undefined;
var terminal_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);

fn terminal_init() void {
    terminal_row = 0;
    terminal_column = 0;
    terminal_color = vga_entry_color(.black, .white);

    for (0..VgaHeight) |y| {
        for (0..VgaWidth) |x| {
            const index = y * VgaWidth + x;
            terminal_buffer[index] = vga_entry(' ', terminal_color);
        }
    }
}

fn terminal_set_color(color: u8) void {
    terminal_color = color;
}

fn terminal_put_entry_at(c: u8, color: u8, x: usize, y: usize) void {
    const index = y * VgaWidth + x;
    terminal_buffer[index] = vga_entry(c, color);
}

fn terminal_putchar(c: u8) void {
    terminal_put_entry_at(c, terminal_color, terminal_column, terminal_row);
    terminal_column += 1;
    if (terminal_column == VgaWidth) {
        terminal_column = 0;
        terminal_row += 1;
        if (terminal_row == VgaHeight) {
            terminal_row = 0;
        }
    }
}

fn terminal_write(data: []const u8) void {
    for (data) |c| {
        terminal_putchar(c);
    }
}

export fn kernel_main() void {
    terminal_init();
    terminal_write("Welcome to ZigIX!\n");
}
