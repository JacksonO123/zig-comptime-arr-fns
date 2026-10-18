const std = @import("std");
const Allocator = std.mem.Allocator;

fn ArrHandler(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []const T,

        pub fn init(data: []const T) Self {
            return Self{ .data = data };
        }

        // pub fn for_each(self: Self, comptime callback: fn (comptime T: type, T) void) void {
        //     for (self.data) |item| {
        //         callback(T, item);
        //     }
        // }

        pub fn map(comptime Ret: type, comptime callback: fn (comptime type, comptime T: type, T) Ret) type {
            return ActionWrapper(action_description_from(Ret, callback));
        }
    };
}

fn action_description_from(comptime Ret: type, comptime callback: anytype) type {
    return @Struct(
        .auto,
        null,
        &.{ "action", "next_action", "ret_type" },
        &.{
            @Struct(
                .auto,
                null,
                &.{"map"},
                &.{@TypeOf(callback)},
                &.{.{ .@"comptime" = true, .default_value_ptr = callback }},
            ),
            @TypeOf(null),
            Ret,
        },
        &.{ .{}, .{}, .{} },
    );
}

fn get_action_result_type(comptime T: type) type {
    const next_action = @FieldType(T, "next_action");
    if (next_action != @TypeOf(null)) return get_action_result_type(next_action);

    return @FieldType(T, "ret_type");
}

fn get_action_fn_type(comptime T: type) type {
    const action_type = @FieldType(T, "action");
    const inst: action_type = .{};

    const action = if (@hasField(action_type, "map")) @field(inst, "map") else {
        @compileError("Expected a valid arr action");
    };

    return @TypeOf(action);
}

fn get_action_fn(comptime T: type) get_action_fn_type(T) {}

fn handle_action_results(comptime T: type, comptime K: type, item: K) get_action_result_type(T) {
    const res_value = a: {
        const action_type = @FieldType(T, "action");
        const inst: action_type = .{};

        break :a if (@hasField(action_type, "map")) b: {
            const action = @field(inst, "map");
            const ret_type = @FieldType(T, "ret_type");
            const res_value = action(ret_type, K, item);
            break :b res_value;
        } else {
            @compileError("Expected a valid arr action");
        };
    };

    const next_action = @FieldType(T, "next_action");
    if (next_action == @TypeOf(null)) return res_value;

    return handle_action_results(next_action, @TypeOf(res_value), res_value);
}

fn append_to_action(comptime T: type, comptime new_desc: type) type {
    const current_info = @typeInfo(T).@"struct";

    var field_names: [current_info.fields.len][]const u8 = undefined;
    var field_types: [current_info.fields.len]type = undefined;
    var field_attributes: [current_info.fields.len]std.builtin.Type.StructField.Attributes = undefined;

    for (current_info.fields, 0..) |field, index| {
        field_names[index] = field.name;

        if (std.mem.eql(u8, field.name, "next_action")) {
            field_types[index] = if (field.type == @TypeOf(null))
                new_desc
            else
                append_to_action(field.type, new_desc);
            field_attributes[index] = .{};
            continue;
        }

        field_types[index] = field.type;
        field_attributes[index] = .{
            .@"comptime" = field.is_comptime,
            .@"align" = field.alignment,
            .default_value_ptr = field.default_value_ptr,
        };
    }

    const desc = @Struct(.auto, null, &field_names, &field_types, &field_attributes);
    return ActionWrapper(desc);
}

fn ActionWrapper(comptime T: type) type {
    return struct {
        fn result(comptime K: type, data: []const K) void {
            for (data) |item| {
                const new_val = handle_action_results(T, K, item);

                std.debug.print(":: {}\n", .{new_val});
            }
        }

        fn map(comptime Ret: type, comptime callback: fn (comptime type, comptime T: type, T) Ret) type {
            const new_desc = action_description_from(Ret, callback);
            return append_to_action(T, new_desc);
        }
    };
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    const arr = &.{ 1, 2, 3, 4, 5 };

    ArrHandler(u32).map(u32, struct {
        fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
            return item + 1;
        }
    }.callback).map(f32, struct {
        fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
            return @floatFromInt(item / 2);
        }
    }.callback).result(u32, arr);
}
