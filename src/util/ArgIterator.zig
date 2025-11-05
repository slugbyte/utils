const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ArgIterator = @This();

pub const Error = error{
    MissingValue,
    ParseFalied,
} || Allocator.Error;

// inner: std.process.ArgIterator,
args: [][:0]u8,
index: usize,
allocator: Allocator,

pub fn init(allocator: Allocator) !ArgIterator {
    return .{
        .args = try std.process.argsAlloc(allocator),
        .index = 0,
        .allocator = allocator,
    };
}

pub fn deinit(self: *ArgIterator) void {
    self.allocator.free(self.args);
    self.* = undefined;
}

pub fn create(allocator: Allocator) !*ArgIterator {
    const iter = try allocator.create(ArgIterator);
    errdefer allocator.destroy(iter);
    iter.* = try ArgIterator.init(allocator);
    return iter;
}

pub fn destroy(self: *ArgIterator) void {
    const allocator = self.allocator;
    self.deinit();
    allocator.destroy(self);
}

pub fn reset(self: *ArgIterator) void {
    self.index = 0;
}

pub fn countRemaing(self: ArgIterator) usize {
    return self.args.len - self.index;
}

pub inline fn peek(self: ArgIterator) ?[:0]const u8 {
    if (self.index < self.args.len) {
        return self.args[self.index];
    }
    return null;
}

pub inline fn skip(self: *ArgIterator) ?[:0]const u8 {
    if (self.index < self.args.len) {
        self.index += 1;
    }
    return null;
}

pub inline fn next(self: *ArgIterator) ?[:0]const u8 {
    if (self.index < self.args.len) {
        defer self.index += 1;
        return self.args[self.index];
    }
    return null;
}

pub inline fn nextOrFail(self: *ArgIterator) ![:0]const u8 {
    return self.next() orelse Error.MissingValue;
}

pub inline fn nextInt(self: *ArgIterator, T: type, base: u8) !T {
    const arg = try self.nextOrFail();
    return std.fmt.parseInt(T, arg, base) catch return Error.ParseFailed;
}

pub inline fn nextFloat(self: *ArgIterator, T: type) !T {
    const arg = try self.nextOrFail();
    return std.fmt.parseFloat(T, arg) catch Error.ParseFailed;
}

pub inline fn nextEnum(self: *ArgIterator, T: type) !T {
    const arg = try self.nextOrFail();
    return std.meta.stringToEnum(T, arg) orelse return Error.ParseFailed;
}

/// convert an arg `[]const u8` into a enum
/// if its a long flag `--flag` it will just parse the whole arg as an enum
/// if its a short flag `-SiCk` it will parse each char as an enum
pub fn FlagIterator(FlagEnum: type) type {
    if (@typeInfo(FlagEnum) != .@"enum") {
        @compileError("FlagIterator expects an enum");
    }
    return struct {
        arg: []const u8,
        is_long: bool,
        index: usize = 0,

        const empty: @This() = .{ .arg = "", .is_long = false };

        const NextResult = union(enum) {
            /// the long or short arg cast as the enum
            Flag: FlagEnum,
            /// the arg started with `--` but could not be cast as the enum
            UnknownLong: []const u8,
            /// the arg started with `-` but the char could not be cast as the enmu
            UnknownShort: u8,
        };

        pub fn init(arg: []const u8) @This() {
            if (std.mem.startsWith(u8, arg, "--")) return .{
                .arg = arg,
                .is_long = true,
            };
            if (std.mem.startsWith(u8, arg, "-")) return .{
                .arg = arg[1..],
                .is_long = false,
            };
            return @This().empty;
        }

        pub inline fn isFlag(self: @This()) bool {
            return self.index != 0;
        }

        pub fn next(self: *@This()) ?NextResult {
            if (self.arg.len == 0) return null;

            if (self.is_long) {
                if (self.index != 0) return null;
                self.index += 1;
                if (std.meta.stringToEnum(FlagEnum, self.arg)) |value| {
                    return NextResult{ .Flag = value };
                }
                return NextResult{ .UnknownLong = self.arg };
            }

            if (self.index < self.arg.len) {
                defer self.index += 1;
                if (std.meta.stringToEnum(FlagEnum, self.arg[self.index..][0..1])) |value| {
                    return NextResult{ .Flag = value };
                }
                return NextResult{ .UnknownShort = self.arg[self.index] };
            }
            return null;
        }
    };
}
