const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/parser.zig" },
        .target = target,
        .optimize = optimize,
    });
    const tests_run_step = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests_run_step.step);
}
