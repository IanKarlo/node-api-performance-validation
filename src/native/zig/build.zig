const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "addon",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.linkLibC();

    lib.root_module.addIncludePath(b.path("include"));

    lib.root_module.strip = false;
    lib.linker_allow_shlib_undefined = true;

    const install_step = b.addInstallFile(lib.getEmittedBin(), "lib/addon.node");
    b.getInstallStep().dependOn(&install_step.step);
}
