const std = @import("std");
const ecs = @import("zig-ecs");
const rollrate = @import("../../../engine/rollrate.zig");

pub const RenderLayers = struct {
    pub const TILE = 0;
    pub const ITEM = 1;
    pub const FOG = 2;
    pub const PLAYER = 3;
};

pub const Side = enum {
    LEFT,
    UP,
    RIGHT,
    DOWN,
};

pub const TileCfg = struct {
    weight: f64,
    atlas: []const u8,
    sprite: []const u8,
    connections: [] Side,
};

pub const LootCfg = struct {
    loot_count_min: f64,
    loot_count_max: f64,
    step_cost: f64,
    cost_property: []const u8,
    tiles: [] TileCfg
};

pub fn revert(side: Side) Side {
    return switch (side) {
        .LEFT => Side.RIGHT,
        .UP => Side.DOWN,
        .RIGHT => Side.LEFT,
        .DOWN => Side.UP,
    };
}

pub const OffsetIterator = struct {
    const Self = @This();

    index: usize,
    tile: TileCfg,

    pub fn init(tile: TileCfg) Self {
        return .{
            .index = 0,
            .tile = tile,
        };
    }

    pub fn next(self: *Self) ?struct { dx: i32, dy: i32, side: Side } {
        if (self.index >= self.tile.connections.len) {
            return null;
        }

        self.index += 1;
        return switch (self.tile.connections[self.index - 1]) {
            .LEFT => .{ .dx = -1, .dy = 0, .side = Side.LEFT },
            .UP => .{ .dx = 0, .dy = -1, .side = Side.UP },
            .RIGHT => .{ .dx = 1, .dy = 0, .side = Side.RIGHT },
            .DOWN => .{ .dx = 0, .dy = 1, .side = Side.DOWN },
        };
    }
};

pub const AroundIterator = struct {
    const Self = @This();
    const sides = [4]Side { Side.LEFT, Side.UP, Side.RIGHT, Side.DOWN };

    count: usize,
    dx: i32,
    dy: i32,
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Self {
        return .{
            .x = x,
            .y = y,
            .dx = 0,
            .dy = 1,
            .count = 0,
        };
    }

    pub fn next(self: *Self) ?struct { x: i32, y: i32, side: Side } {
        if (self.count >= 4) {
            return null;
        }

        const t = self.dx;
        self.dx = -self.dy;
        self.dy = t;
        self.count += 1;

        return .{ .x = self.x + self.dx, .y = self.y + self.dy, .side = Self.sides[self.count - 1] };
    }
};

fn getIdx(side: Side) usize {
    return switch (side) {
        .LEFT => 0,
        .UP => 1,
        .RIGHT => 2,
        .DOWN => 3,
    };
}

pub const TileIndex = struct {
    const Self = @This();
    const TilePtr = struct { tile: ?TileCfg = null, entity: ?ecs.Entity };
    const Size = 10;

    cfg: *LootCfg,
    rnd: *std.rand.Random,
    allocator: std.mem.Allocator,
    index: []TilePtr,
    size_x: i32,
    size_y: i32,

    fn getIndex(self: *Self, x: i32, y: i32) usize {
        return @as(usize, @intCast(x + y * self.size_x));
    }

    pub fn init(cfg: *LootCfg, rnd: *std.rand.Random, allocator: std.mem.Allocator) !Self {
        var index = try allocator.alloc(TilePtr, Size * Size);
        for (0..index.len) |idx| {
            index[idx].tile = null;
            index[idx].entity = null;
        }
        return .{
            .cfg = cfg,
            .rnd = rnd,
            .allocator = allocator,
            .index = index,
            .size_x = Size,
            .size_y = Size,
        };
    }

    pub fn inBounds(self: *Self, x: i32, y: i32) bool {
        return !(x < 0 or x >= self.size_x or y < 0 or y >= self.size_y);
    }

    pub fn tryGet(self: *Self, x: i32, y: i32) ?TileCfg {
        if (!self.inBounds(x, y)) {
            return null;
        }

        return self.index[self.getIndex(x, y)].tile;
    }

    pub fn add(self: *Self, x: i32, y: i32, tile: TileCfg) bool {
        const idx = self.getIndex(x, y); 
        if (self.index[idx].tile) |_| {
            return false;
        }

        self.index[idx].tile = tile;
        return true;
    }

    pub fn setEntity(self: *Self, x: i32, y: i32, entity: ecs.Entity) bool {
        const idx = self.getIndex(x, y);
        if (self.index[idx].entity) |_| {
            return false;
        }

        self.index[idx].entity = entity;
        return true;
    }

    pub fn tryGetEntity(self: *Self, x: i32, y: i32) ?ecs.Entity {
        if (!self.inBounds(x, y)) {
            return null;
        }

        return self.index[self.getIndex(x, y)].entity;
    }

    pub fn rollTile(self: *Self, x: i32, y: i32) !?TileCfg {
        if (!self.inBounds(x, y)) {
            return null;
        }
        
        const TileRoll = struct { tile: TileCfg, weight: f64 };

        var roll_size: usize = 0;
        var roll_list = try self.allocator.alloc(TileRoll, self.cfg.tiles.len);
        defer self.allocator.free(roll_list);

        var inc = [4]bool { false, false, false, false };
        var exc = [4]bool { false, false, false, false };
        var it = AroundIterator.init(x, y);
        while (it.next()) |xy| {
            if (!self.inBounds(xy.x, xy.y)) {
                exc[getIdx(xy.side)] = true;
            } else if (self.tryGet(xy.x, xy.y)) |neighbour_tile| {
                const expected = revert(xy.side);
                const has = for (neighbour_tile.connections) |connection| {
                    if (connection == expected) {
                        break true;
                    }
                } else false;

                if (has) {
                    inc[getIdx(xy.side)] = true;
                } else {
                    exc[getIdx(xy.side)] = true;
                }
            }
        }

        for (self.cfg.tiles) |tile_cfg| {
            const exc_ok = for (tile_cfg.connections) |connection| {
                if (exc[getIdx(connection)]) {
                    break false;
                }
            } else true;

            var inc_tmp = [4]bool { inc[0], inc[1], inc[2], inc[3] };
            for (tile_cfg.connections) |connection| {
                inc_tmp[getIdx(connection)] = false;
            }
            const inc_ok = for (inc_tmp) |b| {
                if (b) { break false; }
            } else true;

            if (exc_ok and inc_ok) {
                roll_list[roll_size] = .{
                    .tile = tile_cfg,
                    .weight = tile_cfg.weight
                };
                roll_size += 1;
            }
        }

        var roll = rollrate.select(TileRoll, "weight", roll_list[0..roll_size], self.rnd);
        if (roll) |ok_roll| {
            return ok_roll.tile;
        }

        return null;
    }

    pub fn deinit(self: *Self) void {
        for (0..self.index.len) |idx| {
            self.index[idx].tile = null;
        }

        self.allocator.free(self.index);
    }
};