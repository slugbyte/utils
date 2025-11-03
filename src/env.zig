const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

comptime {
    if (!(builtin.os.tag == .linux or builtin.os.tag == .macos)) {
        @compileError("util.env does not support os: ");
    }
}

/// buf get an env var or null
pub fn getBuf(buffer: []u8, key: []const u8) Allocator.Error!?[]u8 {
    var fbo = std.heap.FixedBufferAllocator.init(buffer);
    return try getAlloc(fbo.allocator(), key);
}

/// get an env var or null
pub fn getAlloc(allocator: Allocator, key: []const u8) Allocator.Error!?[]u8 {
    const result = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidWtf8 => unreachable, // this module does not support windows
    };

    if (result.len == 0) return null;
    return result;
}

/// check if an env var is set
pub fn exists(key: []const u8) bool {
    var buffer: [1]u8 = undefined;
    const env = getBuf(&buffer, key) catch |err| switch (err) {
        error.OutOfMemory => return true,
    };
    if (env == null) return false;
    return true;
}
