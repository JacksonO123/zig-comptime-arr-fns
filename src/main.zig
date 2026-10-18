const std = @import("std");
const Allocator = std.mem.Allocator;

fn ArrHandler(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []const T,

        pub fn init(data: []const T) Self {
            return Self{ .data = data };
        }

        pub fn for_each(self: Self, comptime callback: fn (comptime T: type, T) void) void {
            for (self.data) |item| {
                callback(T, item);
            }
        }

        pub fn map(comptime callback: fn (comptime T: type, T) T) type {
            // _ = self;
            // const arr = try allocator.alloc(T, self.data.len);
            // for (self.data, 0..) |item, index| {
            //     arr[index] = callback(T, item);
            // }
            // return arr;

            return ActionWrapper(@Struct(
                .auto,
                null,
                &.{ "action", "next_action" },
                &.{
                    @Struct(
                        .auto,
                        null,
                        &.{"map"},
                        &.{@TypeOf(callback)},
                        &.{.{}},
                    ),
                    @TypeOf(null),
                },
                &.{ .{}, .{} },
            ));
        }
    };
}

fn ActionWrapper(comptime T: type) type {
    _ = T;
    return struct {
        fn result() void {
            std.debug.print("HERE\n", .{});
        }
    };
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    const arr = &.{ 1, 2, 3, 4, 5 };
    const handler: ArrHandler(u32) = .init(arr);
    _ = handler;

    ArrHandler(u32).map(struct {
        fn callback(comptime T: type, item: T) T {
            return item + 1;
        }
    }.callback).result();
    // @compileLog(@typeInfo(ArrHandler(u32)).@"struct".fields);

    // const new_arr = handler.map(init.arena.allocator(), struct {
    //     fn callback(comptime T: type, item: T) T {
    //         return item + 1;
    //     }
    // }.callback);

    // std.debug.print(":: {any}\n", .{new_arr});
}
