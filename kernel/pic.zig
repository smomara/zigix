const PIC1 = 0x20; // IO base address for master PIC
const PIC2 = 0xA0; // IO base address for slave PIC
const PIC1_COMMAND = PIC1;
const PIC1_DATA = PIC1 + 1;
const PIC2_COMMAND = PIC2;
const PIC2_DATA = PIC2 + 1;

const PIC_EOI = 0x20; // End-of-interrupt command code

// ICW1 control words
const ICW1_ICW4 = 0x01; // Indicates that ICW4 will be present
const ICW1_SINGLE = 0x02; // Single (cascade) mode
const ICW1_INTERVAL4 = 0x04; // Call address interval 4 (8)
const ICW1_LEVEL = 0x08; // Level triggered (edge) mode
const ICW1_INIT = 0x10; // Initialization - required!

// ICW4 control words
const ICW4_8086 = 0x01; // 8086/88 (MCS-80/85) mode
const ICW4_AUTO = 0x02; // Auto (normal) EOI
const ICW4_BUF_SLAVE = 0x08; // Buffered mode/slave
const ICW4_BUF_MASTER = 0x0C; // Buffered mode/master
const ICW4_SFNM = 0x10; // Special fully nested (not)

const PIC_READ_IRR = 0x0a; // OCW3 irq ready next CMD read
const PIC_READ_ISR = 0x0b; // OCW3 irq service next CMD read

pub fn init() void {
    const offset1 = 0x20; // Master PIC vector offset
    const offset2 = 0x28; // Slave PIC vector offset

    // Save masks
    const a1 = inb(PIC1_DATA);
    const a2 = inb(PIC2_DATA);

    // Start the initialization sequence (in cascade mode)
    outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();
    outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();

    // ICW2: Set vector offsets
    outb(PIC1_DATA, offset1);
    io_wait();
    outb(PIC2_DATA, offset2);
    io_wait();

    // ICW3: Tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
    outb(PIC1_DATA, 4);
    io_wait();
    // ICW3: Tell Slave PIC its cascade identity (0000 0010)
    outb(PIC2_DATA, 2);
    io_wait();

    // ICW4: Have the PICs use 8086 mode (and not 8080 mode)
    outb(PIC1_DATA, ICW4_8086);
    io_wait();
    outb(PIC2_DATA, ICW4_8086);
    io_wait();

    // Restore saved masks
    outb(PIC1_DATA, a1);
    outb(PIC2_DATA, a2);
}

pub fn send_eoi(irq: u8) void {
    if (irq >= 8) {
        outb(PIC2_COMMAND, PIC_EOI);
    }
    outb(PIC1_COMMAND, PIC_EOI);
}

pub fn disable() void {
    outb(PIC1_DATA, 0xff);
    outb(PIC2_DATA, 0xff);
}

pub fn set_mask(irq_line: u8) void {
    const port = if (irq_line < 8) PIC1_DATA else PIC2_DATA;
    const value = inb(port) | (@as(u8, 1) << @intCast(if (irq_line >= 8) irq_line - 8 else irq_line));
    outb(port, value);
}

pub fn clear_mask(irq_line: u8) void {
    const port = if (irq_line < 8) PIC1_DATA else PIC2_DATA;
    const value = inb(port) & ~(@as(u8, 1) << @intCast(if (irq_line >= 8) irq_line - 8 else irq_line));
    outb(port, value);
}

fn get_irq_reg(ocw3: u8) u16 {
    outb(PIC1_COMMAND, ocw3);
    outb(PIC2_COMMAND, ocw3);
    return (@as(u16, inb(PIC2_COMMAND)) << 8) | inb(PIC1_COMMAND);
}

pub fn get_irr() u16 {
    return get_irq_reg(PIC_READ_IRR);
}

pub fn get_isr() u16 {
    return get_irq_reg(PIC_READ_ISR);
}

pub fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

fn io_wait() void {
    outb(0x80, 0);
}
