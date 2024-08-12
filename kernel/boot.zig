// constants for the multiboot header
pub const ALIGN = 1 << 0;
pub const MEMINFO = 1 << 1;
pub const FLAGS = ALIGN | MEMINFO;
pub const MAGIC = 0x1BADB002;
pub const CHECKSUM = -(MAGIC + FLAGS);

// virtual base address of kernel space
pub const KERNEL_VIRTUAL_BASE: u32 = 0xC0000000; // 3GB
pub const KERNEL_PAGE_NUMBER: u32 = KERNEL_VIRTUAL_BASE >> 22;

// page table entry flags
const PTE_PRESENT = 1 << 0;
const PTE_WRITABLE = 1 << 1;
const PTE_USER = 1 << 1;
const PTE_LARGE = 1 << 7;

// declare a multiboot header that marks the program as a kernel
export var multiboot_header align(4) linksection(".multiboot") = [_]i32{ MAGIC, FLAGS, CHECKSUM };

// page directory
export var boot_page_directory: [1024]u32 align(4096) linksection(".data") = init: {
    var dir: [1024]u32 = [_]u32{0} ** 1024;
    dir[0] = 0x00000083; // identity map first 4MB
    dir[KERNEL_PAGE_NUMBER] = 0x00000083; // map kernel to higher half
    break :init dir;
};

// external symbols from linker script
extern var kernel_start: u8;
extern var kernel_end: u8;
extern var text_start: u8;
extern var text_end: u8;
extern var rodata_start: u8;
extern var rodata_end: u8;
extern var data_start: u8;
extern var data_end: u8;
extern var bss_start: u8;
extern var bss_end: u8;
extern var stack_bottom: u8;
extern var stack_top: u8;

// keep track of available memory for page tables
var next_free_page: usize = undefined;

fn set_page_directory_entry(index: usize, pde: u32) void {
    boot_page_directory[index] = pde;
}

fn get_next_free_page() usize {
    const result = next_free_page;
    next_free_page += 4096;
    return result;
}

// maps virtual pages to physical pages
fn map_pages(virt_addr: u32, phys_addr: u32, num_pages: u32, flags: u32) void {
    const pde_index = virt_addr >> 22;
    const pte_index = (virt_addr >> 12) & 0x3FF;

    var page_table: *align(4096) [1024]u32 = undefined;
    if (boot_page_directory[pde_index] & PTE_PRESENT == 0) {
        // allocate a new page table
        page_table = @ptrFromInt(get_next_free_page());
        @memset(page_table, 0);
        set_page_directory_entry(pde_index, @intFromPtr(page_table) - KERNEL_VIRTUAL_BASE | PTE_PRESENT | PTE_WRITABLE);
    } else {
        const page_table_addr = (boot_page_directory[pde_index] & 0xFFFFF000) + KERNEL_VIRTUAL_BASE;
        page_table = @ptrFromInt(page_table_addr);
    }

    for (0..num_pages) |i| {
        page_table[pte_index + i] = (phys_addr + i * 4096) | flags;
    }
}

export fn setup_paging() void {
    next_free_page = @intFromPtr(&kernel_end);
    if (next_free_page % 4096 != 0) {
        next_free_page += 4096 - (next_free_page % 4096);
    }

    // map kernel sections with appropriate permissions
    map_pages(@intFromPtr(&text_start), @intFromPtr(&text_start) - KERNEL_VIRTUAL_BASE, (@intFromPtr(&text_end) - @intFromPtr(&text_start) + 4095) / 4096, PTE_PRESENT);
    map_pages(@intFromPtr(&rodata_start), @intFromPtr(&rodata_start) - KERNEL_VIRTUAL_BASE, (@intFromPtr(&rodata_end) - @intFromPtr(&rodata_start) + 4095) / 4096, PTE_PRESENT);
    map_pages(@intFromPtr(&data_start), @intFromPtr(&data_start) - KERNEL_VIRTUAL_BASE, (@intFromPtr(&data_end) - @intFromPtr(&data_start) + 4095) / 4096, PTE_PRESENT | PTE_WRITABLE);
    map_pages(@intFromPtr(&bss_start), @intFromPtr(&bss_start) - KERNEL_VIRTUAL_BASE, (@intFromPtr(&bss_end) - @intFromPtr(&bss_start) + 4095) / 4096, PTE_PRESENT | PTE_WRITABLE);
    map_pages(@intFromPtr(&stack_bottom), @intFromPtr(&stack_bottom) - KERNEL_VIRTUAL_BASE, (@intFromPtr(&stack_top) - @intFromPtr(&stack_bottom) + 4095) / 4096, PTE_PRESENT | PTE_WRITABLE);
}

export fn enable_write_protect() void {
    asm volatile (
        \\mov %%cr0, %%eax
        \\or $0x10000, %%eax
        \\mov %%eax, %%cr0
    );
}

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
        \\call setup_paging
        \\call enable_write_protect
        \\call kernel_main
        \\
        \\halt:
        \\cli
        \\hlt
        \\jmp halt
    );

    unreachable;
}
