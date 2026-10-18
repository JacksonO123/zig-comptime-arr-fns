const std = @import("std");

const ArrHandler = @import("lib.zig").ArrHandler;

pub fn main(init: std.process.Init) !void {
    const arr = &.{ 1, 2, 3, 4, 5 };

    ArrHandler(u32)
        .map(u32, struct {
            fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
                return item + 1;
            }
        }.callback)
        .map(u32, struct {
            fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
                return item + 1;
            }
        }.callback)
        .filter(struct {
            fn callback(comptime T: type, item: T) bool {
                return item % 2 == 0;
            }
        }.callback)
        .map(u32, struct {
            fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
                return item - 1;
            }
        }.callback)
        .for_each(struct {
            fn callback(comptime T: type, item: T) void {
                std.debug.print(":: {}\n", .{item});
            }
        }.callback)
        .result(init.gpa, arr);
}
