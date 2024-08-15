const std = @import("std");
const vga = @import("vga.zig");
const assert = std.debug.assert;

var row: usize = 0;
var column: usize = 0;
var color: u8 = undefined;
var buffer: [*]volatile u16 = @ptrFromInt(0xc00B8000);

pub fn init() void {
    row = 0;
    column = 0;
    color = vga.entry_color(.black, .white);
    for (0..vga.height) |y| {
        for (0..vga.width) |x| {
            const index = y * vga.width + x;
            buffer[index] = vga.entry(' ', color);
        }
    }
}

pub fn set_color(c: u8) void {
    color = c;
}

fn put_entry_at(c: u8, col: u8, x: usize, y: usize) void {
    assert(x < vga.width);
    assert(y < vga.height);
    const index = y * vga.width + x;
    buffer[index] = vga.entry(c, col);
}

fn putchar(c: u8) void {
    switch (c) {
        '\n' => newline(),
        '\r' => column = 0,
        '\t' => {
            const tab_size = 4;
            const spaces = tab_size - (column % tab_size);
            for (0..spaces) |_| {
                put_entry_at(' ', color, column, row);
                column += 1;
                if (column == vga.width) {
                    newline();
                }
            }
        },
        else => {
            put_entry_at(c, color, column, row);
            column += 1;
        },
    }

    if (column == vga.width) {
        newline();
    }

    assert(column < vga.width);
    assert(row < vga.height);
}

fn newline() void {
    column = 0;
    if (row == vga.height - 1) {
        scroll();
    } else {
        row += 1;
    }
    assert(column == 0);
    assert(row < vga.height);
}

fn scroll() void {
    for (1..vga.height) |y| {
        for (0..vga.width) |x| {
            const to_index = (y - 1) * vga.width + x;
            const from_index = y * vga.width + x;
            buffer[to_index] = buffer[from_index];
        }
    }
    const last_row = vga.height - 1;
    for (0..vga.width) |x| {
        put_entry_at(' ', color, x, last_row);
    }
    assert(row == vga.height - 1);
}

pub fn write(data: []const u8) void {
    for (data) |c| {
        putchar(c);
    }
}
