const std = @import("std");
const ecs = @import("zig-ecs");
const cmp = @import("../ecs/game/components.zig");

pub const Properties = struct {
    const Self = @This();
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMap(f64),
    initial: std.StringArrayHashMap(f64),
    silent: bool,

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .silent = false,
        };
    }

    pub fn initSilent(allocator: std.mem.Allocator, reg: *ecs.Registry) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .silent = true,
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
        try self.map.put(name, value);
        if (!self.silent) {
            var entity = self.reg.create();
            self.reg.add(entity, cmp.TriggerPlayerPropertyChanged { .name = name });
        }
    }

    pub fn add(self: *Self, name: []const u8, value: f64) !void {
        var current_value = self.get(name);
        try self.set(name, current_value + value);
    }

    pub fn reset(self: *Self) !void {
        var it = self.initial.iterator();
        while (it.next()) |kv| {
            try self.set(kv.key_ptr.*, kv.value_ptr.*);
        }
    }
};