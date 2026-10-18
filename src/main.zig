const std = @import("std");
const Allocator = std.mem.Allocator;

const ActionTypes = enum {
    const Self = @This();

    map,
    for_each,

    fn to_string(self: Self) []const u8 {
        return switch (self) {
            .map => "map",
            .for_each => "for_each",
        };
    }

    fn requires_allocation(self: Self) bool {
        return switch (self) {
            .map => true,
            .for_each => false,
        };
    }

    fn from_action_desc(comptime desc: type) Self {
        const action_struct = @FieldType(desc, "action");

        const self_info = @typeInfo(Self).@"enum";
        for (self_info.fields) |field| {
            if (@hasField(action_struct, field.name)) {
                const action_type: Self = @enumFromInt(field.value);
                return action_type;
            }
        }

        @compileError("Action type not found on desc");
    }

    fn allow_next_action(self: Self, next: Self) bool {
        return switch (self) {
            .map => switch (next) {
                .map, .for_each => true,
            },
            .for_each => switch (next) {
                .map, .for_each => false,
            },
        };
    }
};

fn ArrHandler(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn for_each(comptime callback: fn (comptime T: type, T) void) type {
            return ActionWrapper(action_description_from(void, callback, .for_each, T));
        }

        pub fn map(comptime Ret: type, comptime callback: fn (comptime type, comptime T: type, T) Ret) type {
            return ActionWrapper(action_description_from(Ret, callback, .map, T));
        }
    };
}

fn action_description_from(
    comptime Ret: type,
    comptime callback: anytype,
    comptime action_type: ActionTypes,
    comptime original_type: ?type,
) type {
    return @Struct(
        .auto,
        null,
        &.{ "action", "next_action", "ret_type", "allocates", "original_type" },
        &.{
            @Struct(
                .auto,
                null,
                &.{action_type.to_string()},
                &.{@TypeOf(callback)},
                &.{.{ .@"comptime" = true, .default_value_ptr = callback }},
            ),
            @TypeOf(null),
            Ret,
            if (action_type.requires_allocation()) bool else @TypeOf(null),
            if (original_type) |orig_type| orig_type else void,
        },
        &.{ .{}, .{}, .{}, .{}, .{} },
    );
}

fn get_action_result_type(comptime T: type) type {
    const next_action = @FieldType(T, "next_action");
    if (next_action != @TypeOf(null)) return get_action_result_type(next_action);

    const action_struct = @FieldType(T, "action");
    return if (@hasField(action_struct, "map")) @FieldType(T, "ret_type") else void;
}

fn get_action_fn_type(comptime T: type) type {
    const action_struct = @FieldType(T, "action");
    const inst: action_struct = .{};

    const action_fn = if (@hasField(action_struct, "map"))
        @field(inst, "map")
    else if (@hasField(action_struct, "for_each"))
        @field(inst, "for_each")
    else
        @compileError("Expected a valid arr action");

    return @TypeOf(action_fn);
}

fn get_action_fn(comptime T: type) get_action_fn_type(T) {}

fn handle_action_results(comptime T: type, comptime K: type, item: K) get_action_result_type(T) {
    const res_value = a: {
        const action_struct = @FieldType(T, "action");
        const inst: action_struct = .{};

        break :a if (@hasField(action_struct, "map")) b: {
            const action = @field(inst, "map");
            const ret_type = @FieldType(T, "ret_type");
            const res_value = action(ret_type, K, item);
            break :b res_value;
        } else if (@hasField(action_struct, "for_each")) {
            const action = @field(inst, "for_each");
            action(K, item);
        } else {
            @compileError("Expected a valid arr action");
        };
    };

    const next_action = @FieldType(T, "next_action");
    if (next_action == @TypeOf(null)) return res_value;

    return handle_action_results(next_action, @TypeOf(res_value), res_value);
}

fn append_to_action_impl(
    comptime T: type,
    comptime new_desc: type,
    comptime action_type: ActionTypes,
    comptime original_type: ?type,
) type {
    const current_info = @typeInfo(T).@"struct";

    var field_names: [current_info.fields.len][]const u8 = undefined;
    var field_types: [current_info.fields.len]type = undefined;
    var field_attributes: [current_info.fields.len]std.builtin.Type.StructField.Attributes = undefined;

    const src_action_type = ActionTypes.from_action_desc(T);
    if (!src_action_type.allow_next_action(action_type)) @compileError("Invalid action order");

    for (current_info.fields, 0..) |field, index| {
        field_names[index] = field.name;

        if (std.mem.eql(u8, field.name, "next_action")) {
            field_types[index] = if (field.type == @TypeOf(null))
                new_desc
            else
                append_to_action_impl(field.type, new_desc, action_type, original_type);
            field_attributes[index] = .{};
            continue;
        } else if (std.mem.eql(u8, field.name, "allocates")) {
            if (field.type == @TypeOf(null) and @FieldType(new_desc, "allocates") != @TypeOf(null)) {
                field_types[index] = bool;
                field_attributes[index] = .{};
                continue;
            }
        }

        field_types[index] = field.type;
        field_attributes[index] = .{
            .@"comptime" = field.is_comptime,
            .@"align" = field.alignment,
            .default_value_ptr = field.default_value_ptr,
        };
    }

    return @Struct(.auto, null, &field_names, &field_types, &field_attributes);
}

fn append_to_action(
    comptime T: type,
    comptime new_desc: type,
    comptime action_type: ActionTypes,
    comptime original_type: ?type,
) type {
    const desc = append_to_action_impl(T, new_desc, action_type, original_type);
    return ActionWrapper(desc);
}

fn ActionWrapper(comptime T: type) type {
    return struct {
        fn result(
            allocator: Allocator,
            data: []const @FieldType(T, "original_type"),
        ) ![]@FieldType(T, "original_type") {
            const res_type = @FieldType(T, "original_type");
            var map_result = try allocator.alloc(res_type, data.len);

            for (data, 0..) |item, index| {
                const res = handle_action_results(T, res_type, item);
                if (@TypeOf(res) != void) {
                    map_result[index] = res;
                }
            }

            return map_result;
        }

        pub fn for_each(comptime callback: fn (comptime T: type, T) void) type {
            const original_type = @FieldType(T, "original_type");
            const new_desc = action_description_from(void, callback, .for_each, original_type);
            return append_to_action(T, new_desc, .for_each, original_type);
        }

        fn map(comptime Ret: type, comptime callback: fn (comptime type, comptime T: type, T) Ret) type {
            const original_type = @FieldType(T, "original_type");
            const new_desc = action_description_from(Ret, callback, .map, original_type);
            return append_to_action(T, new_desc, .map, original_type);
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const arr = &.{ 1, 2, 3, 4, 5 };

    _ = try ArrHandler(u32).map(u32, struct {
        fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
            return item + 1;
        }
    }.callback).map(u32, struct {
        fn callback(comptime Ret: type, comptime T: type, item: T) Ret {
            return item + 1;
        }
    }.callback).for_each(struct {
        fn callback(comptime T: type, item: T) void {
            std.debug.print(":: {}\n", .{item});
        }
    }.callback).result(init.arena.allocator(), arr);
}
