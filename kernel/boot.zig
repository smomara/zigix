const std = @import("std");

// constants for the multiboot header
pub const ALIGN = 1 << 0; // align loaded modules on page boundaries
pub const MEMINFO = 1 << 1; // provide memory map
pub const FLAGS = ALIGN | MEMINFO; // this is the Multiboot 'flag' field
pub const MAGIC = 0x1BADB002; // 'magic number' lets bootloader find the header
pub const CHECKSUM = -(MAGIC + FLAGS); // checksum of above, to prove we are multiboot

// virtual base address of kernel space
// must be used to convert virt addresses into physical addresses where paging is enabled
// just the amount that must be subtracted from a virtual address to get physical address
pub const KERNEL_VIRTUAL_BASE: u32 = 0xC0000000; // 3GB
pub const KERNEL_PAGE_NUMBER: u32 = KERNEL_VIRTUAL_BASE >> 22; // page dir index of kernel's 4MB PTE

// declare a multiboot header that marks the program as a kernel
// bootloader searches for this in the first 8 KiB of the kernel file, aligned at a 32-bit boundary
// signature is in its own section so we can force it into the first 8 KiB of the kernel file
export var multiboot_header align(4) linksection(".multiboot") = [_]i32{ MAGIC, FLAGS, CHECKSUM };

// page directory
export var boot_page_directory: [1024]u32 align(4096) linksection(".data") = init: {
    var dir: [1024]u32 = [_]u32{0} ** 1024;
    dir[0] = 0x00000083; // identity map first 4MB
    dir[KERNEL_PAGE_NUMBER] = 0x00000083; // map kernel to higher half
    break :init dir;
};

// multiboot standard does not define the value of the stack pointer, up to kernel to provide stack
// we allocate room for a small 16384 byte 16-byte aligned stack in linker.ld
extern var stack_bottom: u8;
extern var stack_top: u8;

// linker.ld specifies _start as the entry point to the kernel, so the bootloader jumps here
export fn _start() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    asm volatile (
        \\mov $boot_page_directory - 0xC0000000, %%ecx
        \\mov %%ecx, %%cr3
        \\mov %%cr4, %%ecx
        \\or $0x00000010, %%ecx
        \\mov %%ecx, %%cr4
        \\mov %%cr0, %%ecx
        \\or $0x80000000, %%ecx
        \\mov %%ecx, %%cr0
        \\lea higher_half, %%ecx
        \\jmp *%%ecx
        \\
        \\higher_half:
        \\movl $0, boot_page_directory
        \\invlpg [0]
        \\mov $stack_top, %%esp
        \\call kernel_main
        \\
        \\halt:
        \\cli
        \\hlt
        \\jmp halt
    );

    unreachable;
}
