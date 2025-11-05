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
