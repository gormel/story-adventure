const std = @import("std");
const pr = @import("properties.zig");
const rr = @import("../engine/rollrate.zig");

pub const ItemCfg = struct {
    atlas: []const u8,
    sprite: []const u8,
    parameters: std.json.ArrayHashMap(f64),
    one_time: bool,
};

pub const ItemListCfg = std.json.ArrayHashMap(ItemCfg);

pub const ItemDropCfg = struct {
    item: []const u8,
    weight: f64,
    groups: [][]const u8,
};

pub const ItemDropListCfg = []ItemDropCfg;

pub const Items = struct {
    const Self = @This();

    item_list_cfg: *ItemListCfg,
    item_drop_list_cfg: *ItemDropListCfg,
    props: *pr.Properties,

    pub fn init(item_list_cfg: *ItemListCfg, item_drop_list_cfg: *ItemDropListCfg, props: *pr.Properties) Self {
        return .{
            .item_list_cfg = item_list_cfg,
            .props = props,
            .item_drop_list_cfg = item_drop_list_cfg,
        };
    }

    pub fn roll(self: *Self, rnd: *std.rand.Random) ?[]const u8 {
        if (rr.select(ItemDropCfg, "weight", self.item_drop_list_cfg.*, rnd)) |item| {
            return item.item;
        }
        return null;
    }

    pub fn rollGroup(self: *Self, group: []const u8, rnd: *std.rand.Random) ?[]const u8 {
        _ = self;
        _ = group;
        _ = rnd;
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

            if (!item_cfg.one_time) {
                try self.props.add(name, 1);
            }

            return true;
        }
        return false;
    }

    pub fn del(self: *Self, name: []const u8) !void {
        if (self.item_list_cfg.map.get(name)) |item_cfg| {
            if (item_cfg.one_time) {
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