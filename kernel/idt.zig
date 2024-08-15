const lib = @import("lib.zig");
const std = @import("std");
const assert = std.debug.assert;

const ENTRIES = 256;

const Type = enum(u4) { task = 0b0101, interrupt = 0b1110, trap = 0b1111 };

const Entry = packed struct {
    offset_low: u16, // offset bits 0..15
    selector: u16, // a code segment selector in GDT or LDT
    zero: u8, // unused, set to 0
    type_attributes: u8, // gate types, dpl and p fields
    offset_high: u16, // offset bits 16..31

    fn init(offset: u32, selector: u16, gate_type: Type, dpl: u2, comptime present: bool) Entry {
        const type_attributes: u8 = @as(u8, @intFromEnum(gate_type)) |
            (@as(u8, dpl) << 5) |
            (if (present) 0x80 else 0);
        return .{
            .offset_low = @truncate(offset & 0xFFFF),
            .selector = selector,
            .zero = 0,
            .type_attributes = type_attributes,
            .offset_high = @truncate((offset >> 16) & 0xFFFF),
        };
    }

    fn get_offset(self: Entry) u32 {
        return @as(u32, self.offset_high) << 16 | self.offset_low;
    }

    fn get_dpl(self: Entry) u2 {
        return @truncate((self.type_attributes >> 5) & 0b11);
    }

    fn is_present(self: Entry) bool {
        return (self.type_attributes & 0x80) != 0;
    }

    fn get_gate_type(self: Entry) Type {
        return @enumFromInt(self.type_attributes & 0xF);
    }
};

comptime {
    assert(@sizeOf(Entry) == 8);
    assert(@bitSizeOf(Entry) == 64);
    assert(@offsetOf(Entry, "offset_low") == 0);
    assert(@offsetOf(Entry, "selector") == 2);
    assert(@offsetOf(Entry, "zero") == 4);
    assert(@offsetOf(Entry, "type_attributes") == 5);
    assert(@offsetOf(Entry, "offset_high") == 6);
}

const Pointer = packed struct {
    limit: u16,
    base: u32,
};

comptime {
    assert(@bitSizeOf(Pointer) == 48);
}

var entries: [ENTRIES]Entry align(8) = undefined;
var pointer: Pointer = undefined;

pub fn init() void {
    @compileError("Not implemented");
}
