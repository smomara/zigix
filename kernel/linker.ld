/* The bootloader will look at this image and start execution at the symbol
   designated as the entry point. */
ENTRY(_start)

/* Tell where the various sections of the object files will be put in the final
   kernel image. */
SECTIONS
{
    /* Start at 2M as a safer option for both BIOS and UEFI systems */
    . = 2M;

    /* First put the multiboot header, as it is required to be put very early
       in the image or the bootloader won't recognize the file format.
       Next we'll put the .text section. */
    .text ALIGN(4K) :
    {
        *(.multiboot)
        *(.text)
    }

    /* Read-only data. */
    .rodata ALIGN(4K) :
    {
        *(.rodata)
    }

    /* Read-write data (initialized) */
    .data ALIGN(4K) :
    {
        *(.data)
    }

    /* Read-write data (uninitialized) and stack */
    .bss ALIGN(4K) :
    {
        *(COMMON)
        *(.bss)
        
        /* Stack allocation */
        . = ALIGN(16);
        stack_bottom = .;
        . += 16K;  /* Allocate 16 KiB for stack */
        stack_top = .;
    }

    /* The compiler may produce other sections, by default it will put them in
       a segment with the same name. Simply add stuff here as needed. */
}
