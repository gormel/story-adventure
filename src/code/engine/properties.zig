const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("../ecs/game/components.zig");

const SAVE_FILENAME = "props.json";

pub const Setup = struct {
    min: std.json.ArrayHashMap(f64),
    max: std.json.ArrayHashMap(f64),
    save: []const []const u8,
};

pub const Properties = struct {
    const Self = @This();
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    map: std.array_hash_map.String(f64),
    initial: std.array_hash_map.String(f64),
    loaded: std.array_hash_map.String(f64),
    silent: bool,
    setup: ?*Setup,

    loadedText: ?[:0] u8,
    loadedJson: ?std.json.Parsed(std.json.ArrayHashMap(f64)),

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry, setup: *Setup) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.array_hash_map.String(f64).empty,
            .initial = std.array_hash_map.String(f64).empty,
            .loaded = std.array_hash_map.String(f64).empty,
            .silent = false,
            .setup = setup,
            
            .loadedText = null,
            .loadedJson = null,
        };
    }

    pub fn initSilent(allocator: std.mem.Allocator, reg: *ecs.Registry) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.array_hash_map.String(f64).empty,
            .initial = std.array_hash_map.String(f64).empty,
            .loaded = std.array_hash_map.String(f64).empty,
            .silent = true,
            .setup = null,

            .loadedText = null,
            .loadedJson = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit(self.allocator);
        self.initial.deinit(self.allocator);

        if (self.loadedJson) |json| {
            json.deinit();
        }

        if (self.loadedText) |text| {
            rl.unloadFileText(text);
        }
    }

    pub fn get(self: *Self, name: []const u8) f64 {
        return self.map.get(name) orelse 0;
    }

    pub fn getInitial(self: *Self, name: []const u8) f64 {
        return self.initial.get(name) orelse 0;
    }

    pub fn create(self: *Self, name: []const u8, value: f64) !void {
        try self.set(name, value);
        try self.initial.put(self.allocator, name, value);
    }

    pub fn set(self: *Self, name: []const u8, value: f64) !void {
        var actual = value;

        if (self.setup) |setup| {
            if (setup.min.map.get(name)) |min| {
                actual = @max(min, actual);
            }

            if (setup.max.map.get(name)) |max| {
                actual = @min(max, actual);
            }
        }
        
        try self.map.put(self.allocator, name, actual);

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
            if (!self.loaded.contains(kv.key_ptr.*)) {
                try self.set(kv.key_ptr.*, kv.value_ptr.*);
            }
        }

        var curr_it = self.map.iterator();
        while (curr_it.next()) |kv| {
            if (!self.loaded.contains(kv.key_ptr.*)) {
                if (!self.initial.contains(kv.key_ptr.*)) {
                    try self.set(kv.key_ptr.*, 0);
                }
            }
        }
    }

    pub fn save(self: *Self) !void {
        if (self.setup) |setup| {
            var saveobj = std.json.ObjectMap.empty;
            defer saveobj.deinit(self.allocator);

            for (setup.save) |propname| {
                if (self.map.get(propname)) |propvalue| {
                    try saveobj.put(self.allocator, propname, std.json.Value { .float = propvalue });
                }
            }

            var out = std.Io.Writer.Allocating.init(self.allocator);
            defer out.deinit();
            var ws = std.json.Stringify {
                .writer = &out.writer,
                .options = .{}
            };

            var savemap = try std.json.ArrayHashMap(f64)
                .jsonParseFromValue(self.allocator, std.json.Value { .object = saveobj }, .{});
            
            var strlist = std.ArrayList(u8).empty;
            defer strlist.deinit(self.allocator);

            try savemap.jsonStringify(&ws);
            const jsontext = try std.fmt.allocPrintSentinel(self.allocator, "{s}", .{ strlist.items }, 0);
            defer self.allocator.free(jsontext);

            _ = rl.saveFileText(SAVE_FILENAME, jsontext);
        }
    }

    pub fn load(self: *Self) !void {
        if (rl.fileExists(SAVE_FILENAME)) {
            if (self.loadedJson) |json| {
                json.deinit();
            }

            if (self.loadedText) |text| {
                rl.unloadFileText(text);
            }

            self.loadedText = rl.loadFileText(SAVE_FILENAME);
            self.loadedJson = try std.json.parseFromSlice(
                std.json.ArrayHashMap(f64), self.allocator, self.loadedText.?, .{ });

            var it = self.loadedJson.?.value.map.iterator();
            while (it.next()) |kv| {
                try self.set(kv.key_ptr.*, kv.value_ptr.*);
                try self.loaded.put(self.allocator, kv.key_ptr.*, kv.value_ptr.*);
            }
        }
    }
};