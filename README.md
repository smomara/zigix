# ZigIX

ZigIX is a bare-bones x85 kernel written in Zig, developed alongside the study of Operating Systems: Three Easy Pieces (OSTEP).

## Current Features
* Multiboot compliant
* Higher-half kernel loading
* Basic VGA text mode driver
* Simple terminal output

## Building and running
Ensure you have Zig and QEMU installed, then:
```bash
zig build
zig build run
```

## Future Plans
This kernel is a work in progress, with plans to implement more OS concepts as covered in OSTEP.

## License
Do as you please
