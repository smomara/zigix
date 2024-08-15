const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
    } });
    const optimize = b.standardOptimizeOption(.{});

    const boot = b.addExecutable(.{
        .name = "zigix",
        .root_source_file = b.path("kernel/boot.zig"),
        .target = target,
        .optimize = optimize,
    });

    const kernel = b.addObject(.{
        .name = "kernel",
        .root_source_file = b.path("kernel/kernel.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .medium,
    });

    boot.setLinkerScriptPath(b.path("kernel/linker.ld"));
    boot.addObject(kernel);
    b.installArtifact(boot);

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel",
        "./zig-out/bin/zigix",
        "-no-reboot",
    });
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&run_cmd.step);

    const debug_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel",
        "./zig-out/bin/zigix",
        "-no-reboot",
        "-s",
        "-S",
    });
    debug_cmd.step.dependOn(b.getInstallStep());
    const debug_step = b.step("debug", "Run the kernel in QEMU with GDB server enabled");
    debug_step.dependOn(&debug_cmd.step);
}
