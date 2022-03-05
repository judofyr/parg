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
            .flag => |flag| {
                if (std.mem.eql(u8, "file", flag.name) or std.mem.eql(u8, "f", flag.name)) {
                    file = p.nextValue() orelse @panic("--file requires value");
                } else if (std.mem.eql(u8, "verbose", flag.name) or std.mem.eql(u8, "v", flag.name)) {
                    verbose = true;
                } else if (std.mem.eql(u8, "version", flag.name)) {
                    std.debug.print("v1\n", .{});
                    std.os.exit(0);
                }
            },
            .arg => @panic("unexpected argument"),
            .unexpected_value => @panic("unexpected value"),
        }
    }

    std.debug.print("program={s} verbose={} file={s}\n", .{ program_name, verbose, file });
}
