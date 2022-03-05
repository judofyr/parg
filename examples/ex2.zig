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

    var verbose: bool = false;
    var file: ?[]const u8 = null;

    while (p.next()) |token| {
        switch (token) {
            .long => |flag| {
                if (std.mem.eql(u8, "file", flag)) {
                    file = p.nextValue() orelse @panic("--file requires value");
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
                    'f' => {
                        file = p.nextValue() orelse @panic("--file requires value");
                    },
                    else => @panic("unknown flag"),
                }
            },
            .arg => @panic("unexpected argument"),
            .unexpected_value => @panic("unexpected value"),
        }
    }

    std.debug.print("program={s} verbose={} file={s}\n", .{ program_name, verbose, file });
}
