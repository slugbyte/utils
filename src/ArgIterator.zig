const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ArgIterator = @This();

pub const Error = error{
    MissingValue,
    ParseFalied,
} || Allocator.Error || std.fs.Dir.StatFileError;

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
    return std.meta.stringToEnum(T, arg) catch return Error.ParseFailed;
}

pub inline fn nextFileOpen(self: *ArgIterator, flags: std.fs.File.OpenFlags) !std.fs.File {
    const file_path = try self.nextFilePath();
    if (file_path.stat.kind != .file) return Error.ParseFailed;
    return try std.fs.cwd().openFile(file_path.path, flags);
}

pub inline fn nextFileRead(self: *ArgIterator, allocator: Allocator) ![:0]const u8 {
    const file = try self.nextFileOpen(.{});
    // TODO: can i remove this buffer? it seems like it might not be needed when streamReamaing to Writer.Allocating...
    var buffer: [4 * 1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    var allocating = std.Io.Writer.Allocating.init(allocator);
    errdefer allocating.deinit();
    _ = file_reader.interface.streamRemaining(&allocating.writer) catch return Error.OutOfMemory;
    return try allocating.toOwnedSliceSentinel(0);
}

pub inline fn nextFileParseZon(self: *ArgIterator, T: type, allocator: Allocator, diagnostics: ?*std.zon.parse.Diagnostics, options: std.zon.parse.Options) !T {
    const file_content = try self.nextFileRead(Allocator);
    defer allocator.free(file_content);
    return std.zon.parse.fromSlice(T, allocator, file_content, diagnostics, options) catch Error.ParseFailed;
}

pub const FilePath = struct {
    stat: std.fs.File.Stat,
    path: [:0]const u8,
};

pub inline fn nextFilePath(self: *ArgIterator) !FilePath {
    const arg = try self.nextOrFail();
    const stat = try std.fs.cwd().statFile(arg);
    return .{
        .path = arg,
        .stat = stat,
    };
}
