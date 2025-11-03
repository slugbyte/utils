const std = @import("std");
const Allocator = std.mem.Allocator;
const ArgIterator = @import("ArgIterator.zig");

pub const Error = error{Unknown} || ArgIterator.Error;
pub const FlagParser = @This();

/// return true if arg is a flag
parseFn: *const fn (*FlagParser, [:0]const u8, *ArgIterator) Error!bool,
/// return true if ArgIterator is now owned by caller
setArgIteratorFn: *const fn (*FlagParser, ArgIterator) bool,
/// return true if positional_list is now owned by caller
setPositionalListFn: *const fn (*FlagParser, [][:0]const u8) bool,
/// return true if program_path is now owned by caller
setProgramPathFn: *const fn (*FlagParser, [:0]const u8) bool,

pub fn parse(flag_parser: *FlagParser, allocator: Allocator) !void {
    var iter = try ArgIterator.init(allocator);
    defer {
        iter.reset();
        if (!flag_parser.setArgIteratorFn(flag_parser, iter)) {
            iter.deinit();
        }
    }

    const program_path = try allocator.dupeZ(u8, iter.next().?);
    errdefer allocator.free(program_path);
    if (!flag_parser.setProgramPathFn(flag_parser, program_path)) {
        allocator.free(program_path);
    }

    var positional = std.ArrayList([:0]const u8).empty;
    errdefer positional.deinit(allocator);
    while (iter.next()) |arg| {
        if (!try flag_parser.parseFn(flag_parser, arg, &iter)) {
            try positional.append(allocator, try allocator.dupeZ(u8, arg));
        }
    }

    const positional_list = try positional.toOwnedSlice(allocator);
    if (!flag_parser.setPositionalListFn(flag_parser, positional_list)) {
        allocator.free(positional_list);
    }
}

pub fn noopSetProgramPath(_: *FlagParser, _: [:0]const u8) bool {
    return false;
}
pub fn noopSetPositionalList(_: *FlagParser, _: [][:0]const u8) bool {
    return false;
}
pub fn noopSetArgIterator(_: *FlagParser, _: ArgIterator) bool {
    return false;
}
