const std = @import("std");
const assert = std.debug.assert;

pub const width = 80;
pub const height = 25;

const Color = enum {
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

pub fn entry_color(fg: Color, bg: Color) u8 {
    const result = @as(u8, @intFromEnum(fg)) | (@as(u8, @intFromEnum(bg)) << 4);
    assert(result <= 0xFF);
    return result;
}

pub fn entry(uc: u8, color: u8) u16 {
    const result = @as(u16, uc) | (@as(u16, color) << 8);
    assert(result <= 0xFFFF);
    return result;
}
