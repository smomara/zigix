const std = @import("std");

// constants for the multiboot header
pub const ALIGN = 1 << 0; // align loaded modules on page boundaries
pub const MEMINFO = 1 << 1; // provide memory map
pub const FLAGS = ALIGN | MEMINFO; // this is the Multiboot 'flag' field
pub const MAGIC = 0x1BADB002; // 'magic number' lets bootloader find the header
pub const CHECKSUM = -(MAGIC + FLAGS); // checksum of above, to prove we are multiboot

// declare a multiboot header that marks the program as a kernel
// bootloader searches for this in the first 8 KiB of the kernel file, aligned at a 32-bit boundary
// signature is in its own section so we can force it into the first 8 KiB of the kernel file
export var multiboot_header align(4) linksection(".multiboot") = [_]i32{ MAGIC, FLAGS, CHECKSUM };

// multiboot standard does not define the value of the stack pointer, up to kernel to provide stack
// we allocate room for a small 16384 byte 16-byte aligned stack in linker.ld
extern var stack_bottom: u8;
extern var stack_top: u8;

// linker.ld specifies _start as the entry point to the kernel, so the bootloader jumps here
export fn _start() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    asm volatile (
        \\mov $stack_top, %%esp
        \\call kernel_main
        \\cli
        \\1:
        \\hlt
        \\jmp 1b
    );
    unreachable;
}
