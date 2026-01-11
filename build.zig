const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("parg", .{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
    });

    const tests = b.addTest(.{
        .root_module = mod,
    });
    const tests_run_step = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests_run_step.step);

    var ex1 = b.addExecutable(.{
        .name = "ex1",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ex1.zig"),
            .target = target,
        }),
    });
    ex1.root_module.addImport("parg", mod);

    var ex2 = b.addExecutable(.{
        .name = "ex2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ex2.zig"),
            .target = target,
        }),
    });
    ex2.root_module.addImport("parg", mod);

    const examples_step = b.step("examples", "Build examples");
    examples_step.dependOn(&b.addInstallArtifact(ex1, .{}).step);
    examples_step.dependOn(&b.addInstallArtifact(ex2, .{}).step);
}
