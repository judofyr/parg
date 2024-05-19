const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("parg", .{
        .root_source_file = b.path("src/parser.zig"),
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tests_run_step = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests_run_step.step);
}
