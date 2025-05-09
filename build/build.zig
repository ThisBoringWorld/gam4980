const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib = b.addSharedLibrary(.{
        // XXX: Remove "lib" prefix in "libgame4980_libretro.so"
        .name = "retro",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .strip = true,
    });
    lib.linkLibC();
    lib.addCSourceFile(.{
        .file = b.path("libretro.c"),
        .flags = &.{},
    });
    b.installArtifact(lib);
}
