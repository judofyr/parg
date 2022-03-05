const std = @import("std");

const parg = @import("../src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) @panic("memory leaked");
    }

    var p = try parg.parseProcess(gpa.allocator(), .{});
    defer p.deinit();

    const program_name = p.nextValue() orelse @panic("no executable name");

    var verbose = false;
    var force = false;
    var arg: ?[]const u8 = null;

    while (p.next()) |token| {
        switch (token) {
            .long => |flag| {
                if (std.mem.eql(u8, "force", flag)) {
                    force = true;
                } else if (std.mem.eql(u8, "verbose", flag)) {
                    verbose = true;
                } else if (std.mem.eql(u8, "version", flag)) {
                    std.debug.print("v1\n", .{});
                    std.os.exit(0);
                }
            },
            .short => |flag| {
                switch (flag) {
                    'v' => verbose = true,
                    'f' => force = true,
                    else => @panic("unknown flag"),
                }
            },
            .arg => |val| {
                if (arg != null) @panic("only one argument supported");
                arg = val;
            },
            .unexpected_value => @panic("unexpected value"),
        }
    }

    std.debug.print("program={s} verbose={} force={} arg={s}\n", .{ program_name, verbose, force, arg });
}
