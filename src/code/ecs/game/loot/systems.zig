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
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");

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
    const fog_ety = reg.create();
    reg.add(fog_ety, rcmp.SpriteResource {
        .atlas = "resources/atlases/gameplay.json",
        .sprite = "hidden_loot",
    });
    reg.add(fog_ety, rcmp.AttachTo {
        .target = tile_ety,
    });
    reg.add(fog_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(fog_ety, rcmp.Order { .order = loot.RenderLayers.FOG });
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
    reg.add(entity, rcmp.Order { .order = loot.RenderLayers.FOG });
    reg.add(entity, cmp.Opener { .tile = tile_ety, .source_tile = source_tile_ety });

    reg.add(entity, gcmp.CreateButton {});

    return entity;
}

fn rollLoot(reg: *ecs.Registry, tile_ety: ecs.Entity, items: *itm.Items, rnd: *std.rand.Random) ecs.Entity {
    if (items.roll(rnd)) |item_name| {
        if (items.info(item_name)) |item| {
            var entity = reg.create();
            reg.add(entity, rcmp.SpriteResource {
                .atlas = item.atlas,
                .sprite = item.sprite,
            });
            reg.add(entity, rcmp.AttachTo {
                .target = tile_ety,
            });
            reg.add(entity, rcmp.Position { .x = 0, .y = 0 });
            reg.add(entity, rcmp.Order { .order = loot.RenderLayers.ITEM });
            reg.add(entity, cmp.Loot { .tile = tile_ety, .item_name = item_name });

            return entity;
        }
    }

    unreachable;
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

            const LootRoll = struct { entity: ecs.Entity, weight: f64 = 1 };
            var loot_roll_table = std.ArrayList(LootRoll).init(allocator);
            defer loot_roll_table.deinit();

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
                        reg.add(tile_ety, rcmp.Order { .order = loot.RenderLayers.TILE });

                        reg.add(tile_ety, cmp.Tile { });
                        reg.add(tile_ety, cmp.TileFog { 
                            .entity = createFog(reg, tile_ety),
                        });

                        if (at.is_center) {
                            reg.add(tile_ety, cmp.Open { .free = true });
                        } else {
                            try loot_roll_table.append(LootRoll { .entity = tile_ety });
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

            var cnt = rnd.intRangeAtMost(i32,
                @as(i32, @intFromFloat(cfg.loot_count_min)),
                @as(i32, @intFromFloat(cfg.loot_count_max)));
            
            while (cnt > 0) : (cnt -= 1) {
                var loot_tile = rr.select(LootRoll, "weight", loot_roll_table.items, rnd);

                if (loot_tile) |ok_loot_tile| {
                    reg.add(ok_loot_tile.entity, cmp.RollItem {});

                    const index_of: ?usize = for (loot_roll_table.items, 0..) |loot_item, idx| {
                        if (loot_item.entity == ok_loot_tile.entity) {
                            break idx;
                        }
                    } else null;
                    if (index_of) |found_idx| {
                        _ = loot_roll_table.swapRemove(found_idx);
                    }
                } else {
                    break;
                }
            }
        }
    }
}

pub fn rollItem(reg: *ecs.Registry, items: *itm.Items, rnd: *std.rand.Random) void {
    var view = reg.view(.{ cmp.RollItem }, .{ cmp.TileLoot });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.TileLoot {
            .entity = rollLoot(reg, entity, items, rnd),
        });

        reg.remove(cmp.RollItem, entity);
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

fn cleanupFog(reg: *ecs.Registry, tile_fog: *cmp.TileFog, entity: ecs.Entity) void {
    if (!reg.has(ccmp.Destroyed, tile_fog.entity)) {
        reg.add(tile_fog.entity, ccmp.Destroyed {});
    }

    reg.remove(cmp.TileFog, entity);
}

fn cleanupOpener(reg: *ecs.Registry, tile_opener: *cmp.TileOpener, entity: ecs.Entity) void {
    if (!reg.has(ccmp.Destroyed, tile_opener.entity)) {
        reg.add(tile_opener.entity, ccmp.Destroyed {});
    }

    reg.remove(cmp.TileOpener, entity);
}

fn cleanupLoot(reg: *ecs.Registry, tile_loot: *cmp.TileLoot, entity: ecs.Entity) void {
    if (!reg.has(ccmp.Destroyed, tile_loot.entity)) {
        reg.add(tile_loot.entity, ccmp.Destroyed {});
    }

    reg.remove(cmp.TileLoot, entity);
}

pub fn openTile(reg: *ecs.Registry, props: *pr.Properties, items: *itm.Items) !void {
    var click_view = reg.view(.{ gcmp.ButtonClicked, cmp.Opener }, .{});
    var click_iter = click_view.entityIterator();
    while (click_iter.next()) |entity| {
        var opener = reg.getConst(cmp.Opener, entity);
        if (!reg.has(cmp.Open, opener.tile)) {
            reg.add(opener.tile, cmp.Open {});
        }
    }

    var view = reg.view(.{ cmp.Open, cmp.Tile, rcmp.Parent }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var open = reg.get(cmp.Open, entity);
        const parent = reg.getConst(rcmp.Parent, entity);
        var loot_start = if (reg.tryGetConst(cmp.LootStart, parent.entity)) |loot_start|
            loot_start else continue;
        
        const cost_property = loot_start.cfg_json.value.cost_property;
        const stamina = props.get(cost_property);
        const step_cost = loot_start.cfg_json.value.step_cost;

        if (stamina < step_cost and !open.free) {
            game.selectNextScene(reg);
        } else {
            if (reg.tryGet(cmp.TileFog, entity)) |tile_fog| {
                cleanupFog(reg, tile_fog, entity);
            }

            if (reg.tryGet(cmp.TileOpener, entity)) |tile_opener| {
                var opener = reg.getConst(cmp.Opener, tile_opener.entity);
                cleanupOpener(reg, tile_opener, entity);

                var source_connection_iter = ConnectionIterator.init(reg, opener.source_tile);
                while (source_connection_iter.next()) |source_neighbour_ety| {
                    if (reg.tryGet(cmp.TileOpener, source_neighbour_ety)) |source_neighbour_opener| {
                        cleanupOpener(reg, source_neighbour_opener, source_neighbour_ety);

                        if (
                            !reg.has(cmp.TileFog, source_neighbour_ety)
                            and !reg.has(cmp.Visited, source_neighbour_ety)
                        ) {
                            reg.add(source_neighbour_ety, cmp.TileFog {
                                .entity = createFog(reg, source_neighbour_ety),
                            });
                        }
                    }
                }
            }

            var connection_iter = ConnectionIterator.init(reg, entity);
            while (connection_iter.next()) |neighbour_ety| {
                if (reg.tryGet(cmp.TileFog, neighbour_ety)) |neighbour_fog| {
                    cleanupFog(reg, neighbour_fog, neighbour_ety);
                }

                if (!reg.has(cmp.TileOpener, neighbour_ety)) {
                    reg.add(neighbour_ety, cmp.TileOpener {
                        .entity = createOpenable(reg, neighbour_ety, entity),
                    });
                }
            }

            if (!reg.has(cmp.Visited, entity)) {
                reg.add(entity, cmp.Visited {});
            }

            if (reg.tryGet(cmp.TileLoot, entity)) |tile_loot| {
                var loot_on_tile = reg.get(cmp.Loot, tile_loot.entity);
                _ = try items.add(loot_on_tile.item_name);

                cleanupLoot(reg, tile_loot, entity);
            }

            if (!open.free) {
                try props.add(cost_property, -step_cost);
            }
        }

        reg.remove(cmp.Open, entity);
    }
}