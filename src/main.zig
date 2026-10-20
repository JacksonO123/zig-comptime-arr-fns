const std = @import("std");
const Writer = std.Io.Writer;

const ArrHandler = @import("lib.zig").ArrHandler;

var count: usize = 0;

pub fn main(init: std.process.Init) !void {
    const arena_allocator = init.arena.allocator();
    const arr_size = 10;
    const arr = try arena_allocator.alloc(u32, arr_size);

    {
        var i: u32 = 0;
        while (i < arr.len) : (i += 1) {
            arr[i] = i;
        }
    }

    var write_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &write_buf);
    defer stdout.end() catch {};
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    // const allocator = init.gpa;

    // var buf = try allocator.alloc(u32, arr_size);
    // for (arr, 0..) |item, index| {
    //     buf[index] = item + 1;
    // }

    // var buf2 = try allocator.alloc(u32, arr_size);
    // for (buf, 0..) |item, index| {
    //     buf2[index] = item + 1;
    // }
    // allocator.free(buf);

    // var buf3 = try allocator.alloc(?u32, arr_size);
    // for (buf2, 0..) |item, index| {
    //     if (item % 2 == 0) {
    //         buf3[index] = item;
    //     } else {
    //         buf3[index] = null;
    //     }
    // }
    // allocator.free(buf2);

    // var buf4 = try allocator.alloc(?u32, arr_size);
    // for (buf3, 0..) |item_or_null, index| {
    //     if (item_or_null) |item| {
    //         buf4[index] = item - 1;
    //     } else {
    //         buf4[index] = null;
    //     }
    // }
    // allocator.free(buf3);

    // for (buf4) |item_or_null| {
    //     if (item_or_null) |item| {
    //         _ = item;
    //         count += 1;
    //     }
    // }
    // allocator.free(buf4);

    // try writer.print(":: {d}\n", .{count});

    // ---------------

    // ArrHandler(u32)
    //     .map(u32, struct {
    //         fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
    //             return item + 1;
    //         }
    //     }.callback)
    //     .map(u32, struct {
    //         fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
    //             return item + 1;
    //         }
    //     }.callback)
    //     .filter(struct {
    //         fn callback(comptime T: type, item: T) bool {
    //             return item % 2 == 0;
    //         }
    //     }.callback)
    //     .map(u32, struct {
    //         fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
    //             return item - 1;
    //         }
    //     }.callback)
    //     .for_each(struct {
    //         fn callback(comptime T: type, item: T) void {
    //             std.debug.print(":: {}\n", .{item});
    //             count += 1;
    //         }
    //     }.callback)
    //     .result(init.gpa, arr);

    // try writer.print(":: {d}\n", .{count});

    const value = ArrHandler(u32)
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
        .reduce(u32, struct {
            fn callback(comptime Ret: type, comptime T: type, acc: Ret, item: T) Ret {
                return acc + item;
            }
        }.callback)
        .result(init.gpa, arr, .{ .value = 5 });

    std.debug.print(":: {}\n", .{value});
}
