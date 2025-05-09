const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib = b.addLibrary(.{
        .name = "retro",
        .root_module = b.createModule(.{
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
            .strip = false,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    lib.root_module.addCSourceFile(.{
        .file = b.path("libretro.c"),
    });
    const install = b.addInstallArtifact(lib, .{
        .dest_sub_path = "gam4980_libretro.so",
    });
    b.getInstallStep().dependOn(&install.step);
}
