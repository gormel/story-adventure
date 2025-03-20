const std = @import("std");
const ecs = @import("zig-ecs");
const cmp = @import("../ecs/game/components.zig");

pub const Restrictions = struct {
    min: std.json.ArrayHashMap(f64),
    max: std.json.ArrayHashMap(f64),
};

pub const Properties = struct {
    const Self = @This();
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMap(f64),
    initial: std.StringArrayHashMap(f64),
    silent: bool,
    restrictions: ?*Restrictions,

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry, restrictions: *Restrictions) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .silent = false,
            .restrictions = restrictions,
        };
    }

    pub fn initSilent(allocator: std.mem.Allocator, reg: *ecs.Registry) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .silent = true,
            .restrictions = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
        self.initial.deinit();
    }

    pub fn get(self: *Self, name: []const u8) f64 {
        return self.map.get(name) orelse 0;
    }

    pub fn getInitial(self: *Self, name: []const u8) f64 {
        return self.initial.get(name) orelse 0;
    }

    pub fn create(self: *Self, name: []const u8, value: f64) !void {
        try self.set(name, value);
        try self.initial.put(name, value);
    }

    pub fn set(self: *Self, name: []const u8, value: f64) !void {
        var actual = value;

        if (self.restrictions) |restrictions| {
            if (restrictions.min.map.get(name)) |min| {
                actual = @max(min, actual);
            }

            if (restrictions.max.map.get(name)) |max| {
                actual = @min(max, actual);
            }
        }
        
        try self.map.put(name, actual);

        if (!self.silent) {
            const entity = self.reg.create();
            self.reg.add(entity, cmp.TriggerPlayerPropertyChanged { .name = name });
        }
    }

    pub fn add(self: *Self, name: []const u8, value: f64) !void {
        const current_value = self.get(name);
        try self.set(name, current_value + value);
    }

    pub fn reset(self: *Self) !void {
        var it = self.initial.iterator();
        while (it.next()) |kv| {
            try self.set(kv.key_ptr.*, kv.value_ptr.*);
        }

        var curr_it = self.map.iterator();
        while (curr_it.next()) |kv| {
            if (!self.initial.contains(kv.key_ptr.*)) {
                try self.set(kv.key_ptr.*, 0);
            }
        }
    }
};