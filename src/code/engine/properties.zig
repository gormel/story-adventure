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
    map: std.StringArrayHashMap(f64),
    initial: std.StringArrayHashMap(f64),
    loaded: std.StringArrayHashMap(f64),
    silent: bool,
    setup: ?*Setup,

    loadedText: ?[:0] u8,
    loadedJson: ?std.json.Parsed(std.json.ArrayHashMap(f64)),

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry, setup: *Setup) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .loaded = std.StringArrayHashMap(f64).init(allocator),
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
            .map = std.StringArrayHashMap(f64).init(allocator),
            .initial = std.StringArrayHashMap(f64).init(allocator),
            .loaded = std.StringArrayHashMap(f64).init(allocator),
            .silent = true,
            .setup = null,

            .loadedText = null,
            .loadedJson = null,
        };
    }

    pub fn deinit(self: *Self) void {
        std.debug.print("++++props.deinit\n", .{ });
        self.map.deinit();
        self.initial.deinit();

        if (self.loadedJson) |json| {
            json.deinit();
        }

        if (self.loadedText) |text| {
            rl.unloadFileText(text);
        }
    }

    pub fn get(self: *Self, name: []const u8) f64 {
        if (self.map.get(name)) |value| {
            std.debug.print("++++props.get {s}={}\n", .{ name, value });
        } else {
            std.debug.print("++++props.get {s}=null\n", .{ name });
        }
        return self.map.get(name) orelse 0;
    }

    pub fn getInitial(self: *Self, name: []const u8) f64 {
        if (self.initial.get(name)) |value| {
            std.debug.print("++++props.getInitial {s}={}\n", .{ name, value });
        } else {
            std.debug.print("++++props.getInitial {s}=null\n", .{ name });
        }
        return self.initial.get(name) orelse 0;
    }

    pub fn create(self: *Self, name: []const u8, value: f64) !void {
        std.debug.print("++++props.create {s}={}\n", .{ name, value });
        try self.set(name, value);
        try self.initial.put(name, value);
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
        
        std.debug.print("++++props.set {s}={}\n", .{ name, actual });
        try self.map.put(name, actual);

        if (!self.silent) {
            const entity = self.reg.create();
            self.reg.add(entity, cmp.TriggerPlayerPropertyChanged { .name = name });
        }
    }

    pub fn add(self: *Self, name: []const u8, value: f64) !void {
        std.debug.print("++++props.add {s}+={}\n", .{ name, value });
        const current_value = self.get(name);
        try self.set(name, current_value + value);
    }

    pub fn reset(self: *Self) !void {
        std.debug.print("++++props.reset\n", .{ });
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
        std.debug.print("++++props.save\n", .{ });
        if (self.setup) |setup| {
            var saveobj = std.json.ObjectMap.init(self.allocator);
            defer saveobj.deinit();

            for (setup.save) |propname| {
                if (self.map.get(propname)) |propvalue| {
                    try saveobj.put(propname, std.json.Value { .float = propvalue });
                }
            }

            var savemap = try std.json.ArrayHashMap(f64)
                .jsonParseFromValue(self.allocator, std.json.Value { .object = saveobj }, .{});
            
            var strlist = std.ArrayList(u8).init(self.allocator);
            defer strlist.deinit();

            const strwriter = strlist.writer();
            var jwriter = std.json.WriteStream(@TypeOf(strwriter), .checked_to_arbitrary_depth)
                .init(self.allocator, strwriter, .{});
            defer jwriter.deinit();

            try savemap.jsonStringify(&jwriter);
            const jsontext = try std.fmt.allocPrintZ(self.allocator, "{s}", .{ strlist.items });
            defer self.allocator.free(jsontext);

            _ = rl.saveFileText(SAVE_FILENAME, jsontext);
        }
    }

    pub fn load(self: *Self) !void {
        std.debug.print("++++props.load\n", .{ });
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
                try self.loaded.put(kv.key_ptr.*, kv.value_ptr.*);
            }
        }
    }
};