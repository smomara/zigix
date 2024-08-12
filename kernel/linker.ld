ENTRY(_start)

SECTIONS {
   /* The kernel will live at 3GB + 1MB in the virtual address space,
      which will be mapped to 1MB in the physical address space. */
   . = 0xC0100000;

   kernel_start = .;

   .text ALIGN(4K) : AT(ADDR(.text) - 0xC0000000) {
       text_start = .;
       *(.multiboot)
       *(.text)
       text_end = .;
   }

   .rodata ALIGN(4K) : AT(ADDR(.rodata) - 0xC0000000) {
       rodata_start = .;
       *(.rodata)
       rodata_end = .;
   }

   .data ALIGN(4K) : AT(ADDR(.data) - 0xC0000000) {
       data_start = .;
       *(.data)
       data_end = .;
   }

   .bss ALIGN(4K) : AT(ADDR(.bss) - 0xC0000000) {
       bss_start = .;
       *(COMMON)
       *(.bss)
       bss_end = .;
   }

   .stack ALIGN(4K) : AT(ADDR(.stack) - 0xC0000000) {
       stack_bottom = .;
       . += 16K; /* 16 KiB of stack space */
       stack_top = .;
   }

   kernel_end = .;
}

