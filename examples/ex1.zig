const std = @import("std");

const parg = @import("../src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leaked");
    }

    var p = try parg.parseProcess(gpa.allocator(), .{});
    defer p.deinit();

    const program_name = p.nextValue() orelse @panic("no executable name");

    var verbose = false;
    var force = false;
    var arg: ?[]const u8 = null;

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isLong("force") or flag.isShort("f")) {
                    force = true;
                } else if (flag.isLong("verbose") or flag.isShort("v")) {
                    verbose = true;
                } else if (flag.isLong("version")) {
                    std.debug.print("v1\n", .{});
                    std.os.exit(0);
                }
            },
            .arg => |val| {
                if (arg != null) @panic("only one argument supported");
                arg = val;
            },
            .unexpected_value => @panic("unexpected value"),
        }
    }

    std.debug.print("program={s} verbose={} force={} arg={s}\n", .{ program_name, verbose, force, arg orelse "(null)" });
}
