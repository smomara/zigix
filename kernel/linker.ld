ENTRY(_start)

SECTIONS {
   /* The kernel will live at 3GB + 1MB in the virtual address space,
      which will be mapped to 1MB in the physical address space. */
   . = 0xC0100000;

   .text ALIGN(4K) : AT(ADDR(.text) - 0xC0000000) {
       *(.multiboot)
       *(.text)
   }

   .rodata ALIGN(4K) : AT(ADDR(.rodata) - 0xC0000000) {
       *(.rodata)
   }

   .data ALIGN(4K) : AT(ADDR(.data) - 0xC0000000) {
       *(.data)
   }

   .bss ALIGN(4K) : AT(ADDR(.bss) - 0xC0000000) {
       *(COMMON)
       *(.bss)
   }

    .stack ALIGN(4K) : AT(ADDR(.stack) - 0xC0000000) {
       stack_bottom = .;
       . += 16K; /* 16 KiB of stack space */
       stack_top = .;
   }

   /* The compiler may produce other sections, put them in the proper place in
      in this file, if you'd like to include them in the final kernel. */
}

