const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var main_tests = b.addTest("src/parser.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
