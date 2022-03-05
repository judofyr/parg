const std = @import("std");

pub const Token = union(enum) {
    short: u8,
    long: []const u8,
    arg: []const u8,
    unexpected_value: []const u8,
};

pub const Options = struct {
    auto_double_dash: bool = true,
};

const State = union(enum) {
    // Nothing is buffered.
    default: void,

    // In the middle of parsing short flags.
    short: []const u8,

    // After observing an equal sign.
    value: ValueState,
};

const ValueState = struct {
    // This points to the value (i.e. whatever is after the = sign)
    value: []const u8,

    // This points to the key+value (e.g. `-m=message`).
    full: []const u8,
};

pub fn Parser(comptime T: type) type {
    return struct {
        const Self = @This();

        source: T,
        options: Options,
        state: State = .default,
        skip_flag_parsing: bool = false,

        pub fn init(source: T, options: Options) Self {
            return Self{ .source = source, .options = options };
        }

        pub fn deinit(self: *Self) void {
            if (@hasDecl(T, "deinit")) {
                self.source.deinit();
            }
            self.* = undefined;
        }

        pub fn next(self: *Self) ?Token {
            switch (self.state) {
                .default => {
                    const arg = self.pull() orelse return null;

                    if (self.skip_flag_parsing) {
                        return Token{ .arg = arg };
                    }

                    if (std.mem.startsWith(u8, arg, "--")) {
                        if (arg.len == 2) {
                            if (self.options.auto_double_dash) {
                                self.skip_flag_parsing = true;
                                return self.next();
                            } else {
                                return Token{ .arg = arg };
                            }
                        }

                        if (std.mem.indexOfScalar(u8, arg, '=')) |value_pos| {
                            self.state = .{
                                .value = .{
                                    .full = arg[2..],
                                    .value = arg[value_pos + 1 ..],
                                },
                            };
                            return Token{ .long = arg[2..value_pos] };
                        }

                        return Token{ .long = arg[2..] };
                    }

                    if (arg.len > 1 and std.mem.startsWith(u8, arg, "-")) {
                        self.proceedShort(arg[1..]);
                        return Token{ .short = arg[1] };
                    }

                    return Token{ .arg = arg };
                },
                .short => |arg| {
                    self.proceedShort(arg);
                    return Token{ .short = arg[0] };
                },
                .value => |v| {
                    self.state = .default;
                    return Token{ .unexpected_value = v.full };
                },
            }

            return null;
        }

        /// nextValue should be invoked after you've observed a long/short flag and expect a value. 
        /// This correctly handles both `--long=value`, `--long value`, `-svalue`, `-s=value` and `-s value`.
        pub fn nextValue(self: *Self) ?[]const u8 {
            switch (self.state) {
                .default => return self.pull(),
                .short => |buf| return buf,
                .value => |v| {
                    self.state = .default;
                    return v.value;
                },
            }
        }

        /// skipFlagParsing turns off flag parsing and causes all the next tokens to be returned as `arg`.
        pub fn skipFlagParsing(self: *Self) void {
            self.skip_flag_parsing = true;
        }

        fn pull(self: *Self) ?[]const u8 {
            return @as(?[]const u8, self.source.next());
        }

        /// proceedShort sets up the state after a short flag has been seen. 
        fn proceedShort(self: *Self, data: []const u8) void {
            if (data.len == 1) {
                // No more data in this slice => Go back to default mode.
                self.state = .default;
            } else if (data[1] == '=') {
                // We found a value!
                self.state = .{
                    .value = .{
                        .full = data,
                        .value = data[2..],
                    },
                };
            } else {
                // There's more short flags.
                self.state = .{ .short = data[1..] };
            }
        }
    };
}

pub fn parse(source: anytype, options: Options) Parser(@TypeOf(source)) {
    return Parser(@TypeOf(source)).init(source, options);
}

pub const SliceIter = struct {
    items: []const []const u8,
    idx: usize = 0,

    pub fn next(self: *SliceIter) ?[]const u8 {
        defer self.idx += 1;

        if (self.idx < self.items.len) {
            return self.items[self.idx];
        } else {
            return null;
        }
    }
};

pub fn parseSlice(slice: []const []const u8, options: Options) Parser(SliceIter) {
    return parse(SliceIter{ .items = slice }, options);
}

pub fn parseProcess(allocator: std.mem.Allocator, options: Options) !Parser(std.process.ArgIterator) {
    return parse(try std.process.argsWithAllocator(allocator), options);
}

const testing = std.testing;

fn expectShort(arg: ?Token) !u8 {
    if (arg) |a| {
        switch (a) {
            .short => |name| return name,
            else => {},
        }
    }
    return error.TestExpectedLong;
}

fn expectLong(arg: ?Token) ![]const u8 {
    if (arg) |a| {
        switch (a) {
            .long => |name| return name,
            else => {},
        }
    }
    return error.TestExpectedLong;
}

fn expectArg(arg: ?Token) ![]const u8 {
    if (arg) |a| {
        switch (a) {
            .arg => |name| return name,
            else => {},
        }
    }
    return error.TestExpectedValue;
}

fn expectUnexpectedValue(arg: ?Token) ![]const u8 {
    if (arg) |a| {
        switch (a) {
            .unexpected_value => |name| return name,
            else => {},
        }
    }
    return error.TestExpectedUnexpectedValue;
}

fn expectNull(arg: ?Token) !void {
    return testing.expectEqual(@as(?Token, null), arg);
}

test "parse values" {
    var parser = parseSlice(&[_][]const u8{ "hello", "world" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectArg(parser.next()));
    try testing.expectEqualStrings("world", try expectArg(parser.next()));
    try expectNull(parser.next());
}

test "parse short flags" {
    var parser = parseSlice(&[_][]const u8{ "-abc", "-def" }, .{});
    defer parser.deinit();
    for ("abcdef") |flag| {
        try testing.expectEqual(flag, try expectShort(parser.next()));
    }
    try expectNull(parser.next());
}

test "parse short with values" {
    // -a=1
    {
        var parser = parseSlice(&[_][]const u8{"-a=1"}, .{});
        defer parser.deinit();
        try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
        try testing.expectEqualStrings("1", parser.nextValue() orelse unreachable);
        try expectNull(parser.next());
    }

    // -a1
    {
        var parser = parseSlice(&[_][]const u8{"-a=1"}, .{});
        defer parser.deinit();
        try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
        try testing.expectEqualStrings("1", parser.nextValue() orelse unreachable);
        try expectNull(parser.next());
    }

    // -a 1
    {
        var parser = parseSlice(&[_][]const u8{ "-a", "1" }, .{});
        defer parser.deinit();
        try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
        try testing.expectEqualStrings("1", parser.nextValue() orelse unreachable);
        try expectNull(parser.next());
    }
}

test "parse long" {
    var parser = parseSlice(&[_][]const u8{ "--force", "--author" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("force", try expectLong(parser.next()));
    try testing.expectEqualStrings("author", try expectLong(parser.next()));
    try expectNull(parser.next());
}

test "parse long with value" {
    // --name=bob
    {
        var parser = parseSlice(&[_][]const u8{"--name=bob"}, .{});
        defer parser.deinit();
        try testing.expectEqualStrings("name", try expectLong(parser.next()));
        try testing.expectEqualStrings("bob", parser.nextValue() orelse unreachable);
        try expectNull(parser.next());
    }

    // --name bob
    {
        var parser = parseSlice(&[_][]const u8{ "--name", "bob" }, .{});
        defer parser.deinit();
        try testing.expectEqualStrings("name", try expectLong(parser.next()));
        try testing.expectEqualStrings("bob", parser.nextValue() orelse unreachable);
        try expectNull(parser.next());
    }
}

test "unexpected value" {
    // --name=bob
    {
        var parser = parseSlice(&[_][]const u8{"--name=bob"}, .{});
        defer parser.deinit();
        try testing.expectEqualStrings("name", try expectLong(parser.next()));
        try testing.expectEqualStrings("name=bob", try expectUnexpectedValue(parser.next()));
        try expectNull(parser.next());
    }

    // -ab=bob
    {
        var parser = parseSlice(&[_][]const u8{"-ab=bob"}, .{});
        defer parser.deinit();
        try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
        try testing.expectEqual(@as(u8, 'b'), try expectShort(parser.next()));
        try testing.expectEqualStrings("b=bob", try expectUnexpectedValue(parser.next()));
        try expectNull(parser.next());
    }
}

test "unexpected value followed by flag" {
    var parser = parseSlice(&[_][]const u8{ "--name=bob", "--file" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("name", try expectLong(parser.next()));
    try testing.expectEqualStrings("name=bob", try expectUnexpectedValue(parser.next()));
    try testing.expectEqualStrings("file", try expectLong(parser.next()));
    try expectNull(parser.next());
}

test "empty long value" {
    var parser = parseSlice(&[_][]const u8{"--name="}, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("name", try expectLong(parser.next()));
    try testing.expectEqualStrings("", parser.nextValue() orelse unreachable);
    try expectNull(parser.next());
}

test "empty short value" {
    var parser = parseSlice(&[_][]const u8{"-a="}, .{});
    defer parser.deinit();
    try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
    try testing.expectEqualStrings("", parser.nextValue() orelse unreachable);
    try expectNull(parser.next());
}

test "single dash" {
    var parser = parseSlice(&[_][]const u8{ "--hello", "world", "-" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    try testing.expectEqualStrings("world", try expectArg(parser.next()));
    try testing.expectEqualStrings("-", try expectArg(parser.next()));
    try expectNull(parser.next());
}

test "double dash" {
    var parser = parseSlice(&[_][]const u8{ "--hello", "world", "--", "--hello" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    try testing.expectEqualStrings("world", try expectArg(parser.next()));
    try testing.expectEqualStrings("--hello", try expectArg(parser.next()));
    try expectNull(parser.next());
}

test "manual dash" {
    var parser = parseSlice(&[_][]const u8{ "--hello", "world", "--", "--hello" }, .{ .auto_double_dash = false });
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    try testing.expectEqualStrings("world", try expectArg(parser.next()));
    try testing.expectEqualStrings("--", try expectArg(parser.next()));
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    try expectNull(parser.next());
}

test "manual skip" {
    var parser = parseSlice(&[_][]const u8{ "--hello", "--world", "-a" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    parser.skipFlagParsing();
    try testing.expectEqualStrings("--world", try expectArg(parser.next()));
    try testing.expectEqualStrings("-a", try expectArg(parser.next()));
    try expectNull(parser.next());
}

test "manual skip during value" {
    var parser = parseSlice(&[_][]const u8{ "--hello=world", "--name" }, .{});
    defer parser.deinit();
    try testing.expectEqualStrings("hello", try expectLong(parser.next()));
    parser.skipFlagParsing();
    try testing.expectEqualStrings("hello=world", try expectUnexpectedValue(parser.next()));
    try testing.expectEqualStrings("--name", try expectArg(parser.next()));
    try expectNull(parser.next());
}

test "manual skip during short" {
    var parser = parseSlice(&[_][]const u8{ "-abc", "--file" }, .{});
    defer parser.deinit();
    try testing.expectEqual(@as(u8, 'a'), try expectShort(parser.next()));
    parser.skipFlagParsing();
    try testing.expectEqual(@as(u8, 'b'), try expectShort(parser.next()));
    try testing.expectEqual(@as(u8, 'c'), try expectShort(parser.next()));
    try testing.expectEqualStrings("--file", try expectArg(parser.next()));
    try expectNull(parser.next());
}
