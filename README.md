# parg

**parg** is a lightweight argument parser for Zig which focuses on a single task:
Parsing command-line arguments into positional arguments and long/short flags.
It doesn't concern itself _anything_ else.
You may find this useful as a quick way of parsing some arguments, or use it as a building block for a more elaborate CLI toolkit.

## Features / non-features

* Parses command-line arguments into **positional arguments**, **long flags** and **short flags**.
* Provides an iterator interface (`while (parser.next()) |token| …`).
* Supports boolean flags (`--force`, `-f`).
* Supports multiple short flags (`-avz`).
* Values can be provided as separate arguments (`--message Hello`), with a delimiter (`--message=Hello`) and also part of short flag (`-mHello`).
* Automatically detects `--` and skips any further parsing.
* Licensed under 0BSD.

## Usage

The principles of `parg` are as follows:

* Use `parseProcess`, `parseSlice` or `parse` to create a new parser.
* Remember to call `deinit()` when you're done with the parser.
* Call `next()` in a loop to parse arguments.
* Call `nextValue()` whenever you need a plain value.
* There's a few more knobs you can tweak with.

Let's go over these steps a bit more in detail.

### Create a new parser instance

There's three ways of creating a parser instance.
All of these accept some _options_ as the last argument.

```zig
const parg = @import("parg");

// (1) Parse arguments given to the current process:
var p = try parg.parseProcess(allocator, .{});

// (2) Parse arguments from a `[]const []const u8`:
var p = parg.parseSlice(slice, .{});

// (3) Parse arguments from an iterator (advanced usage):
var p = parg.parse(it, .{});

// Always remember to deinit:
defer p.deinit();
```

In addition, remember that the first parameter given to a process is the file name of the executable.
You typically want to call `nextValue()` to retrieve this value before you continue parsing any arguments.

```zig
const program_name = p.nextValue() orelse @panic("no executable name");
```

### Parsing boolean flags and positional arguments

Once you have a parser you want to call `next()` in a loop.
This returns a token which has four different possibilities:

* `.long` when it encounters a long flag (e.g. `--verbose`).
* `.short` when it encounters a short flag (e.g. `-v`).
* `.arg` when it encounters a positional argument.
* `.unexpected_value` when it encounters an unexpected value.
  You should just quit the program with an error when this happens.
  We'll come back to this in the next section.

Also note that this will automatically split up short flags as expected:
If you give the program `-fv` then `next()` will first return `.{.short = 'f'}` and then `.{.short = 'v'}`.

```zig
// See examples/ex1.zig for full example.

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
```

### Parsing flags with values

When you find a flag which require a value you need to invoke `nextValue()`.
This returns an optional slice:

```zig
// See examples/ex2.zig for full example.

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
    }
}
```

All of these will be treated the same way:

* `--file build.zig`
* `--file=build.zig`
* `-f build.zig`
* `-f=build.zig`
* `-fbuild.zig`

Most notably, notice that when you call `nextValue()` it will "break out" of parsing short flags.
Without the call to `nextValue()` the code would parse `-fbuild.zig` as the short flags `-f`, `-b`, `-u`, and so on.

This also explains the need for `.unexpected_value` in `next()`:
If you pass `--force=yes` to the first example it will parse the `--force` as a long flag.
When you then _don't_ invoke `nextValue()` (since it's a boolean flag) then we need to later bail out since we didn't expect a value.

### Options and other functionality

There's currently only one option (which you configure when instantiate the parser):

* `auto_double_dash` (defaults to `true`).
  When this is `true` it will look for `--` and then stop parsing anything as a flag.
  Your program will _not_ observe the `--` token at all, and all tokens after this point will be returned as `.arg` (even though they start with a dash).
  When this is `false` it will return `--` as a regular argument (`.arg`) and argument parsing will continue as usual.

There's also one additional method:

* `p.skipFlagParsing()`.
  This turns off any further argument parsing.
  All tokens after this point will be returned as `.arg` (even though they start with a dash).
