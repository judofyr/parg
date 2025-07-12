const std = @import("std");

const parg = @import("parg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leaked");
    }

    var p = try parg.parseProcess(gpa.allocator(), .{});
    defer p.deinit();

    const program_name = p.nextValue() orelse @panic("no executable name");

    var verbose: bool = false;
    var file: ?[]const u8 = null;

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isLong("file") or flag.isShort("f")) {
                    file = p.nextValue() orelse @panic("--file requires value");
                } else if (flag.isLong("verbose") or flag.isShort("v")) {
                    verbose = true;
                } else if (flag.isLong("version")) {
                    std.debug.print("v1\n", .{});
                    std.process.exit(0);
                }
            },
            .arg => @panic("unexpected argument"),
            .unexpected_value => @panic("unexpected value"),
        }
    }

    std.debug.print("program={s} verbose={} file={s}\n", .{ program_name, verbose, file orelse "(null)" });
}
