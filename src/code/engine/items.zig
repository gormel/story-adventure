const std = @import("std");
const pr = @import("properties.zig");
const rr = @import("../engine/rollrate.zig");
const utils = @import("../engine/utils.zig");
const condition = @import("../engine/condition.zig");

pub const ItemViewCfg = struct {
    atlas: []const u8,
    image: []const u8,
    name: [:0]const u8,
    description: [:0]const u8,
};

pub const ItemCfg = struct {
    view: ItemViewCfg,
    parameters: std.json.ArrayHashMap(f64),
    one_time_parameters: std.json.ArrayHashMap(f64),
};

pub const ItemListCfg = std.json.ArrayHashMap(ItemCfg);

pub const ItemDropCfg = struct {
    item: []const u8,
    weight: f64,
    groups: [][]const u8,
    condition: std.json.ArrayHashMap(f64),
};

pub const ItemDropListCfg = []ItemDropCfg;

pub const ItemProgressCfg = std.json.ArrayHashMap([]const u8);

pub const Items = struct {
    const Self = @This();

    item_list_cfg: *ItemListCfg,
    item_drop_list_cfg: *ItemDropListCfg,
    item_progress_cfg: *ItemProgressCfg,
    props: *pr.Properties,
    allocator: std.mem.Allocator,

    pub fn init(
        item_list_cfg: *ItemListCfg,
        item_drop_list_cfg: *ItemDropListCfg,
        item_progress_cfg: *ItemProgressCfg,
        props: *pr.Properties,
        allocator: std.mem.Allocator
    ) Self {
        return .{
            .item_list_cfg = item_list_cfg,
            .props = props,
            .item_drop_list_cfg = item_drop_list_cfg,
            .item_progress_cfg = item_progress_cfg,
            .allocator = allocator
        };
    }

    pub fn roll(self: *Self, rnd: *std.Random) ?[]const u8 {
        var table_size: usize = 0;
        var table = try self.allocator.alloc(ItemDropCfg, self.item_drop_list_cfg.len);
        defer self.allocator.free(table);

        const source_table = self.item_drop_list_cfg.*;
        for (source_table) |cfg| {
            if (condition.check(cfg.condition, self.props)) {
                table[table_size] = cfg;
                table_size += 1;
            }
        }

        if (rr.select(ItemDropCfg, "weight", table[0..table_size], rnd)) |item| {
            return item.item;
        }
        return null;
    }

    pub fn rollGroup(self: *Self, group: []const u8, rnd: *std.Random) !?[]const u8 {
        var table_size: usize = 0;
        var table = try self.allocator.alloc(ItemDropCfg, self.item_drop_list_cfg.len);
        defer self.allocator.free(table);

        const source_table = self.item_drop_list_cfg.*;
        for (source_table) |cfg| {
            if (
                utils.containsTag(cfg.groups, group)
                and condition.check(cfg.condition, self.props)
            ) {
                table[table_size] = cfg;
                table_size += 1;
            }
        }

        if (rr.select(ItemDropCfg, "weight", table[0..table_size], rnd)) |item| {
            return item.item;
        }

        return null;
    }

    pub fn info(self: *Self, name: []const u8) ?ItemCfg {
        return self.item_list_cfg.map.get(name);
    }

    pub fn add(self: *Self, name: []const u8) !bool {
        if (self.item_list_cfg.map.get(name)) |item_cfg| {
            var iter = item_cfg.parameters.map.iterator();
            while (iter.next()) |kv| {
                try self.props.add(kv.key_ptr.*, kv.value_ptr.*);
            }

            var one_time_iter = item_cfg.one_time_parameters.map.iterator();
            while (one_time_iter.next()) |kv| {
                try self.props.add(kv.key_ptr.*, kv.value_ptr.*);
            }

            if (item_cfg.parameters.map.count() > 0) {
                try self.props.add(name, 1);
            }

            if (self.item_progress_cfg.map.get(name)) |prog_prop| {
                try self.props.set(prog_prop, 1);
            }

            return true;
        }
        return false;
    }

    pub fn del(self: *Self, name: []const u8) !void {
        if (self.item_list_cfg.map.get(name)) |item_cfg| {
            if (item_cfg.parameters.map.count() == 0) {
                unreachable;
            }

            try self.props.add(name, -1);

            var iter = item_cfg.parameters.map.iterator();
            while (iter.next()) |kv| {
                try self.props.add(kv.key_ptr.*, -kv.value_ptr.*);
            }

        } else {
            unreachable;
        }
    }
};