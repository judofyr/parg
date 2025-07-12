const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("parg", .{
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

    const ex1 = b.addExecutable(.{
        .name = "ex1",
        .root_source_file = b.path("examples/ex1.zig"),
        .target = target,
    });
    ex1.root_module.addImport("parg", mod);

    const ex2 = b.addExecutable(.{
        .name = "ex1",
        .root_source_file = b.path("examples/ex2.zig"),
        .target = target,
    });
    ex2.root_module.addImport("parg", mod);

    const examples_step = b.step("examples", "Build examples");
    examples_step.dependOn(&ex1.step);
}
