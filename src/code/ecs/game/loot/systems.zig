const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const Properties = @import("../../../engine/parameters.zig").Properties;

const loot = @import("loot.zig");
const cfg_text = @embedFile("../../../assets/cfg/loot_scene.json");

const Point = struct {
    x: i32,
    y: i32,
    parent: ?struct { entity: ecs.Entity, side: loot.Side },
    is_center: bool = false,
};

const TileSizeX = 32;
const TileSizeY = 32;

fn createFog(reg: *ecs.Registry, tile_ety: ecs.Entity) ecs.Entity {
    var fog_ety = reg.create();
    reg.add(fog_ety, rcmp.SpriteResource {
        .atlas = "resources/atlases/gameplay.json",
        .sprite = "hidden_loot",
    });
    reg.add(fog_ety, rcmp.AttachTo {
        .target = tile_ety,
    });
    reg.add(fog_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(fog_ety, cmp.Fog { .tile = tile_ety });
    return fog_ety;
}

fn createOpenable(reg: *ecs.Registry, tile_ety: ecs.Entity, source_tile_ety: ecs.Entity) ecs.Entity {
    var entity = reg.create();
    reg.add(entity, rcmp.SpriteResource {
        .atlas = "resources/atlases/gameplay.json",
        .sprite = "openable",
    });
    reg.add(entity, rcmp.AttachTo {
        .target = tile_ety,
    });
    reg.add(entity, rcmp.Position { .x = 0, .y = 0 });
    reg.add(entity, cmp.Opener { .tile = tile_ety, .source_tile = source_tile_ety });

    reg.add(entity, gcmp.CreateButton {});

    return entity;
}

fn connect(reg: *ecs.Registry, a: ecs.Entity, b: ecs.Entity, ab_side: loot.Side) void {
    var a_tile = reg.get(cmp.Tile, a);
    var b_tile = reg.get(cmp.Tile, b);

    switch (ab_side) {
        .LEFT => {
            a_tile.l = b;
            b_tile.r = a;
        },
        .UP => {
            a_tile.u = b;
            b_tile.d = a;
        },
        .RIGHT => {
            a_tile.r = b;
            b_tile.l = a;
        },
        .DOWN => {
            a_tile.d = b;
            b_tile.u = a;
        },
    }
}

pub fn initLoot(reg: *ecs.Registry, allocator: std.mem.Allocator, rnd: *std.rand.Random) !void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "loot-start")) {
            const cfg_json = try std.json.parseFromSlice(
                loot.LootCfg,
                allocator,
                cfg_text,
                .{ .ignore_unknown_fields = true }
            );
            var cfg = cfg_json.value;
            reg.add(entity, cmp.LootStart {
                .cfg_json = cfg_json
            });

            var index = try loot.TileIndex.init(&cfg, rnd, allocator);
            defer index.deinit();

            const center = Point {
                .x = @divFloor(index.size_x, 2),
                .y = @divFloor(index.size_y, 2),
                .is_center = true,
                .parent = null,
            };
            var stack = std.ArrayList(Point).init(allocator);
            defer stack.deinit();
            try stack.append(center);
            while (stack.items.len > 0) {
                const at = stack.pop();
                if (try index.rollTile(at.x, at.y)) |tile_cfg| {
                    if (index.add(at.x, at.y, tile_cfg)) {
                        var tile_ety = reg.create();
                        reg.add(tile_ety, rcmp.SpriteResource {
                            .atlas = tile_cfg.atlas,
                            .sprite = tile_cfg.sprite,
                        });
                        reg.add(tile_ety, rcmp.Position {
                            .x = @as(f32, @floatFromInt((at.x - center.x) * TileSizeX)),
                            .y = @as(f32, @floatFromInt((at.y - center.y) * TileSizeY)),
                        });
                        reg.add(tile_ety, rcmp.AttachTo {
                            .target = entity,
                        });

                        reg.add(tile_ety, cmp.Tile {
                            .fog = createFog(reg, tile_ety),
                        });

                        if (at.is_center) {
                            reg.add(tile_ety, cmp.Open { .free = true });
                        }

                        if (at.parent) |parent| {
                            connect(reg, parent.entity, tile_ety, parent.side);
                        }

                        _ = index.setEntity(at.x, at.y, tile_ety);

                        var it = loot.OffsetIterator.init(tile_cfg);
                        while (it.next()) |dxdy| {
                            try stack.append(Point {
                                .x = at.x + dxdy.dx,
                                .y = at.y + dxdy.dy,
                                .parent = .{
                                    .entity = tile_ety,
                                    .side = dxdy.side
                                },
                            });
                        }
                    } else if (index.tryGetEntity(at.x, at.y)) |at_entity| {
                        if (at.parent) |parent| {
                            connect(reg, parent.entity, at_entity, parent.side);
                        }
                    }
                }
            }
        }
    }
}

pub fn freeLootStart(reg: *ecs.Registry) void {
    var view = reg.view(.{ ccmp.Destroyed, cmp.LootStart }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var loot_start = reg.get(cmp.LootStart, entity);
        loot_start.cfg_json.deinit();
    }
}

const ConnectionIterator = struct {
    const Self = @This();

    reg: *ecs.Registry,
    tile_ety: ecs.Entity,
    side: loot.Side,
    iterations: usize,

    pub fn init(reg: *ecs.Registry, tile_ety: ecs.Entity) Self {
        return .{
            .reg = reg,
            .tile_ety = tile_ety,
            .side = loot.Side.LEFT,
            .iterations = 0,
        };
    }

    fn current(self: *Self) ?ecs.Entity {
        var tile = self.reg.get(cmp.Tile, self.tile_ety);
        return switch (self.side) {
            .LEFT => tile.l,
            .UP => tile.u,
            .RIGHT => tile.r,
            .DOWN => tile.d,
        };
    }

    fn rotate(self: *Self) void {
        self.side = switch (self.side) {
            .LEFT => loot.Side.UP,
            .UP => loot.Side.RIGHT,
            .RIGHT => loot.Side.DOWN,
            .DOWN => loot.Side.LEFT,
        };
    }

    pub fn next(self: *Self) ?ecs.Entity {
        if (self.iterations > 3) {
            return null;
        }

        while (self.current() == null) {
            self.iterations += 1;
            self.rotate();

            if (self.iterations > 3) {
                return null;
            }
        }

        var curr = self.current();
        self.rotate();
        self.iterations += 1;
        return curr;
    }
};

pub fn openTile(reg: *ecs.Registry, props: *Properties) !void {
    var click_view = reg.view(.{ gcmp.ButtonClicked, cmp.Opener }, .{});
    var click_iter = click_view.entityIterator();
    while (click_iter.next()) |entity| {
        var opener = reg.getConst(cmp.Opener, entity);
        if (!reg.has(cmp.Open, opener.tile)) {
            reg.add(opener.tile, cmp.Open {});
        }
    }

    var view = reg.view(.{ cmp.Open, cmp.Tile }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var open = reg.get(cmp.Open, entity);
        const stamina = try props.get(loot.STAMINA);
        if (stamina < loot.OPEN_COST and !open.free) {
            game.selectNextScene(reg);
        } else {
            var tile = reg.get(cmp.Tile, entity);
            if (tile.fog) |fog_ety| {
                if (!reg.has(ccmp.Destroyed, fog_ety)) {
                    reg.add(fog_ety, ccmp.Destroyed {});
                }

                tile.fog = null;
            }

            if (tile.opener) |opener_ety| {
                var opener = reg.getConst(cmp.Opener, opener_ety);

                if (!reg.has(ccmp.Destroyed, opener_ety)) {
                    reg.add(opener_ety, ccmp.Destroyed {});
                }
                tile.opener = null;

                var source_connection_iter = ConnectionIterator.init(reg, opener.source_tile);
                while (source_connection_iter.next()) |source_neighbour_ety| {
                    var source_connection_tile = reg.get(cmp.Tile, source_neighbour_ety);
                    if (source_connection_tile.opener) |source_neighbour_opener_ety| {
                        if (!reg.has(ccmp.Destroyed, source_neighbour_opener_ety)) {
                            reg.add(source_neighbour_opener_ety, ccmp.Destroyed {});
                        }

                        source_connection_tile.opener = null;

                        if (
                            source_connection_tile.fog == null
                            and !reg.has(cmp.Visited, source_neighbour_ety)
                        ) {
                            source_connection_tile.fog = createFog(reg, source_neighbour_ety);
                        }
                    }
                }
            }

            var connection_iter = ConnectionIterator.init(reg, entity);
            while (connection_iter.next()) |neighbour_ety| {
                var neighbour_tile = reg.get(cmp.Tile, neighbour_ety);
                if (neighbour_tile.fog) |fog_ety| {
                    if (!reg.has(ccmp.Destroyed, fog_ety)) {
                        reg.add(fog_ety, ccmp.Destroyed {});
                    }

                    neighbour_tile.fog = null;
                }

                if (neighbour_tile.opener == null) {
                    neighbour_tile.opener = createOpenable(reg, neighbour_ety, entity);
                }
            }

            if (!reg.has(cmp.Visited, entity)) {
                reg.add(entity, cmp.Visited {});
            }

            //collect loot
            if (!open.free) {
                try props.set(loot.STAMINA, stamina - loot.OPEN_COST);
            }
        }

        reg.remove(cmp.Open, entity);
    }
}