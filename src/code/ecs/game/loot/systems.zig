const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");
const easing = @import("../../render/easing.zig");
const rutils = @import("../../render/utils.zig");
const utils = @import("../../../engine/utils.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");

const loot = @import("loot.zig");
const cfg_text = @embedFile("../../../assets/cfg/scene_customs/loot.json");

const Error = error {
    TileHasNoParent,
    CharacterHasNoTileParent,
    CharacterNotFound,
};

const Point = struct {
    x: i32,
    y: i32,
    parent: ?struct { entity: ecs.Entity, side: loot.Side },
    is_center: bool = false,
};

const TileSizeX = 32;
const TileSizeY = 32;

fn createFog(reg: *ecs.Registry, tile_ety: ecs.Entity, cfg: *const loot.LootCfg) ecs.Entity {
    const fog_ety = reg.create();
    reg.add(fog_ety, rcmp.ImageResource {
        .atlas = cfg.fog_view.atlas,
        .image = cfg.fog_view.image,
    });
    reg.add(fog_ety, rcmp.AttachTo {
        .target = tile_ety,
    });
    reg.add(fog_ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
    reg.add(fog_ety, rcmp.Order { .order = loot.RenderLayers.FOG });
    reg.add(fog_ety, cmp.Fog { .tile = tile_ety });

    return fog_ety;
}

fn createOpenable(
    reg: *ecs.Registry,
    tile_ety: ecs.Entity,
    source_tile_ety: ecs.Entity,
    cfg: *const loot.LootCfg,
    side: loot.Side
) ecs.Entity {
    const image = switch (side) {
        .LEFT => cfg.openable_view.l,
        .UP => cfg.openable_view.u,
        .RIGHT => cfg.openable_view.r,
        .DOWN => cfg.openable_view.d,
    };
    const entity = reg.create();
    reg.add(entity, rcmp.ImageResource {
        .atlas = cfg.openable_view.atlas,
        .image = image,
    });
    reg.add(entity, rcmp.AttachTo {
        .target = tile_ety,
    });
    reg.add(entity, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
    reg.add(entity, rcmp.Order { .order = loot.RenderLayers.OPENER });
    reg.add(entity, cmp.Opener { .tile = tile_ety, .source_tile = source_tile_ety });

    reg.add(entity, gcmp.CreateButton { .animated = false });

    const AxisSetup = struct { rcmp.Axis, f32 };
    const setup: AxisSetup = switch (side) {
        .LEFT => .{ rcmp.Axis.X, -1 },
        .UP => .{ rcmp.Axis.Y, -1 },
        .RIGHT => .{ rcmp.Axis.X, 1 },
        .DOWN => .{ rcmp.Axis.Y, 1 },
    };

    const tween = reg.create();
    reg.add(tween, rcmp.TweenMove { .axis = setup[0] });
    reg.add(tween, rcmp.TweenSetup {
        .from = -2 * setup[1],
        .to = 2 * setup[1],
        .repeat = .RepeatPinpong,
        .duration = 1,
        .entity = entity,
    });

    return entity;
}

fn createCharacterAnim(
    reg: *ecs.Registry,
    char_ety: ecs.Entity,
    visible: bool,
    image: []const u8,
    cfg: *const loot.LootCfg
) ecs.Entity {
    const entity = reg.create();
    reg.add(entity, rcmp.ImageResource {
        .atlas = cfg.hero_view.atlas,
        .image = image,
    });
    reg.add(entity, rcmp.AttachTo {
        .target = char_ety,
    });
    reg.add(entity, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });

    if (!visible) {
        reg.add(entity, rcmp.Hidden {});
    }

    return entity;
}

fn createCharacter(reg: *ecs.Registry, parent_ety: ecs.Entity, tile_ety: ecs.Entity, cfg: *const loot.LootCfg) void {
    const entity = reg.create();
    reg.add(entity, rcmp.AttachTo {
        .target = parent_ety,
    });

    reg.add(entity, rcmp.Order { .order = loot.RenderLayers.PLAYER });
    reg.add(entity, cmp.Character {
        .idle_image = createCharacterAnim(reg, entity, true, cfg.hero_view.idle_image, cfg),
        .l_image = createCharacterAnim(reg, entity, false, cfg.hero_view.left_image, cfg),
        .u_image = createCharacterAnim(reg, entity, false, cfg.hero_view.up_image, cfg),
        .r_image = createCharacterAnim(reg, entity, false, cfg.hero_view.right_image, cfg),
        .d_image = createCharacterAnim(reg, entity, false, cfg.hero_view.down_image, cfg),
        .tile = tile_ety,
    });
}

fn toDirection(dx: f32, dy: f32) ?loot.Side {
    if (dx < 0) {
        return loot.Side.RIGHT;
    }

    if (dx > 0) {
        return loot.Side.LEFT;
    }

    if (dy < 0) {
        return loot.Side.DOWN;
    }

    if (dy > 0) {
        return loot.Side.UP;
    }

    return null;
}

fn showAnimation(etys: []ecs.Entity, idx: usize, reg: *ecs.Registry) void {
    for(etys, 0..) |entity, i| {
        if (i == idx) {
            reg.removeIfExists(rcmp.Hidden, entity);
            if (reg.tryGet(rcmp.Flipbook, entity)) |flipbook| {
                flipbook.time = flipbook.flipbook.duration;
            }
        } else {
            reg.addOrReplace(entity, rcmp.Hidden {});
        }
    }
}

fn createCharacterTween(reg: *ecs.Registry, char_ety: ecs.Entity, from: f32, to: f32, axis: rcmp.Axis) void {
    var tween_view = reg.view(.{ cmp.CharacterMoveTween }, .{ rcmp.CancelTween });
    var tween_iter = tween_view.entityIterator();
    while (tween_iter.next()) |entity| {
        var char_tween = reg.get(cmp.CharacterMoveTween, entity);
        if (char_tween.axis == axis) {
            reg.add(entity, rcmp.CancelTween {});
        } else {
            char_tween.reset_anim = false;
        }
    }

    const tween_ety = reg.create();
    reg.add(tween_ety, rcmp.TweenMove {
        .axis = axis,
    });
    reg.add(tween_ety, rcmp.TweenSetup {
        .from = from,
        .to = to,
        .duration = 1,
        .entity = char_ety,
        .easing = easing.Easing.Ease,
    });
    reg.add(tween_ety, cmp.CharacterMoveTween { .char_entity = char_ety, .axis = axis });
}

const XY = struct { x: i32, y: i32 };

fn getLootAlpha(from: XY, to: XY, cfg: *const loot.LootCfg) ?u8 {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const distance = @abs(dx) + @abs(dy);

    if (@as(f64, @floatFromInt(distance)) > cfg.loot_view_distance) {
        return 0;
    } else if (distance <= 2) {
        return 255;
    } else {
        const max_distance: usize = @intFromFloat(cfg.loot_view_distance);
        return @intCast(255 - distance * 255 / (max_distance + 1));
    }

    return null;
}

fn animateCharacter(
    reg: *ecs.Registry,
    char_ety: ecs.Entity,
    from_tile_ety: ecs.Entity,
    to_tile_ety: ecs.Entity
) void {
    const from_tile_pos = reg.get(rcmp.Position, from_tile_ety);
    const to_tile_pos = reg.get(rcmp.Position, to_tile_ety);
    const dx = from_tile_pos.x - to_tile_pos.x;
    const dy = from_tile_pos.y - to_tile_pos.y;

    if (toDirection(dx, dy)) |dir| {
        const char = reg.get(cmp.Character, char_ety);
        var imgs = [_]ecs.Entity { char.idle_image, char.l_image, char.u_image, char.r_image, char.d_image };
        
        switch (dir) {
            .LEFT => {
                createCharacterTween(reg, char_ety, from_tile_pos.x, to_tile_pos.x, rcmp.Axis.X);
                showAnimation(&imgs, 1, reg);
            },
            .UP => {
                createCharacterTween(reg, char_ety, from_tile_pos.y, to_tile_pos.y, rcmp.Axis.Y);
                showAnimation(&imgs, 2, reg);
            },
            .RIGHT => {
                createCharacterTween(reg, char_ety, from_tile_pos.x, to_tile_pos.x, rcmp.Axis.X);
                showAnimation(&imgs, 3, reg);
            },
            .DOWN => {
                createCharacterTween(reg, char_ety, from_tile_pos.y, to_tile_pos.y, rcmp.Axis.Y);
                showAnimation(&imgs, 4, reg);
            },
        }
    }
}

fn moveCharacter(
    reg: *ecs.Registry,
    from_tile_ety: ecs.Entity,
    to_tile_ety: ecs.Entity,
    cfg: *const loot.LootCfg
) void {
    var iter = reg.entityIterator(cmp.Character);
    while (iter.next()) |entity| {
        animateCharacter(reg, entity, from_tile_ety, to_tile_ety);

        var char = reg.get(cmp.Character, entity);
        char.tile = to_tile_ety;

        const to_tile = reg.get(cmp.Tile, to_tile_ety);
        var loot_view = reg.view(.{ cmp.Loot, rcmp.Color }, .{});
        var loot_iter = loot_view.entityIterator();
        while (loot_iter.next()) |loot_ety| {
            const loot_cmp = reg.get(cmp.Loot, loot_ety);
            const tile = reg.get(cmp.Tile, loot_cmp.tile);
            const color = reg.get(rcmp.Color, loot_ety);
            
            const target_a = getLootAlpha(
                .{ .x = tile.x, .y = tile.y },
                .{ .x = to_tile.x, .y = to_tile.y },
                cfg) orelse color.a;

            var prev_tween_view = reg.view(.{ cmp.LootViewTween, rcmp.TweenSetup }, .{});
            var prev_tween_iter = prev_tween_view.entityIterator();
            while (prev_tween_iter.next()) |tween_ety| {
                const setup = reg.get(rcmp.TweenSetup, tween_ety);
                if (setup.entity == loot_ety) {
                    reg.add(tween_ety, ccmp.Destroyed {});
                }
            }

            const tween_ety = reg.create();
            reg.add(tween_ety, cmp.LootViewTween {});
            reg.add(tween_ety, rcmp.TweenColor { .component = .A });
            reg.add(tween_ety, rcmp.TweenSetup {
                .from = @floatFromInt(color.a),
                .to = @floatFromInt(target_a),
                .duration = 0.5,
                .entity = loot_ety,
            });
        }
    }
}

fn rollLoot(
    reg: *ecs.Registry,
    tile_ety: ecs.Entity,
    items: *itm.Items,
    group: []const u8,
    rnd: *std.Random
) !ecs.Entity {
    if (items.rollGroup(group, rnd) catch null) |item_name| {
        if (items.info(item_name)) |item| {
            const start_ety = rutils.getParent(reg, tile_ety)
                orelse return Error.TileHasNoParent;
            const start = reg.get(cmp.LootStart, start_ety);

            const tile = reg.get(cmp.Tile, tile_ety);

            var char_iter = reg.entityIterator(cmp.Character);
            const char_tile_ety = while (char_iter.next()) |char_ety| {
                const char = reg.get(cmp.Character, char_ety);
                break char.tile;
            } else return Error.CharacterNotFound;
            const char_tile = reg.get(cmp.Tile, char_tile_ety);

            const a = getLootAlpha(
                .{ .x = char_tile.x, .y = char_tile.y },
                .{ .x = tile.x, .y = tile.y },
                &start.cfg_json.value
            ) orelse 0;

            const entity = reg.create();
            reg.add(entity, rcmp.ImageResource {
                .atlas = item.view.atlas,
                .image = item.view.image,
            });
            reg.add(entity, rcmp.AttachTo {
                .target = tile_ety,
            });
            reg.add(entity, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
            reg.add(entity, rcmp.Order { .order = loot.RenderLayers.ITEM });
            reg.add(entity, cmp.Loot { .tile = tile_ety, .item_name = item_name });
            reg.add(entity, rcmp.Color { .a = a });

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

pub fn initGui(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-complete-loot")) {
            reg.add(entity, cmp.CompleteLootButton {});
        }

        if (utils.containsTag(init.tags, "loot-item-collector")) {
            reg.add(entity, cmp.ItemCollector {});
        }
    }
}

pub fn gui(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.CompleteLootButton, gcmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        game.selectNextScene(reg);
    }
}

pub fn initLoot(reg: *ecs.Registry, allocator: std.mem.Allocator, rnd: *std.Random) !void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
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
                .x = @intCast(@divFloor(index.size_x, 2)),
                .y = @intCast(@divFloor(index.size_y, 2)),
                .is_center = true,
                .parent = null,
            };
            var stack = std.ArrayList(Point).init(allocator);
            defer stack.deinit();
            try stack.append(center);
            while (stack.pop()) |at| {
                if (try index.rollTile(at.x, at.y)) |tile_cfg| {
                    if (index.add(at.x, at.y, tile_cfg)) {
                        const tile_ety = reg.create();
                        reg.add(tile_ety, rcmp.ImageResource {
                            .atlas = tile_cfg.atlas,
                            .image = tile_cfg.image,
                        });
                        reg.add(tile_ety, rcmp.Position {
                            .x = @as(f32, @floatFromInt((at.x - center.x) * TileSizeX)),
                            .y = @as(f32, @floatFromInt((at.y - center.y) * TileSizeY)),
                        });
                        reg.add(tile_ety, rcmp.AttachTo {
                            .target = entity,
                        });
                        reg.add(tile_ety, rcmp.Order { .order = loot.RenderLayers.TILE });
                        reg.add(tile_ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });

                        reg.add(tile_ety, cmp.Tile { .x = at.x, .y = at.y });
                        reg.add(tile_ety, cmp.TileFog { 
                            .entity = createFog(reg, tile_ety, &cfg),
                        });

                        if (at.is_center) {
                            reg.add(tile_ety, cmp.Open { .free = true });
                            createCharacter(reg, entity, tile_ety, &cfg);
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

            var loot_iter = cfg.loot.map.iterator();
            while (loot_iter.next()) |loot_kv| {
                const loot_count = loot_kv.value_ptr;
                var cnt = rnd.intRangeAtMost(i32,
                    @as(i32, @intFromFloat(loot_count.min)),
                    @as(i32, @intFromFloat(loot_count.max)));
                
                while (cnt > 0) : (cnt -= 1) {
                    const loot_tile = rr.select(LootRoll, "weight", loot_roll_table.items, rnd);

                    if (loot_tile) |ok_loot_tile| {
                        reg.add(ok_loot_tile.entity, cmp.RollItem { .group = loot_kv.key_ptr.* });

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
}

pub fn character(reg: *ecs.Registry) void {
    var anim_restore_view = reg.view(.{ rcmp.TweenComplete, cmp.CharacterMoveTween }, .{});
    var anim_restore_iter = anim_restore_view.entityIterator();
    while (anim_restore_iter.next()) |entity| {
        const tween = reg.get(cmp.CharacterMoveTween, entity);
        if (tween.reset_anim) {
            const char = reg.get(cmp.Character, tween.char_entity);
            var imgs = [_]ecs.Entity { char.idle_image, char.l_image, char.u_image, char.r_image, char.d_image };
            showAnimation(&imgs, 0, reg);
        }
    }
}

pub fn rollItem(reg: *ecs.Registry, items: *itm.Items, rnd: *std.Random) !void {
    var view = reg.view(.{ cmp.RollItem }, .{ cmp.TileLoot });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const roll = reg.get(cmp.RollItem, entity);
        reg.add(entity, cmp.TileLoot {
            .entity = try rollLoot(reg, entity, items, roll.group, rnd),
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
        const tile = self.reg.get(cmp.Tile, self.tile_ety);
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

    pub fn next(self: *Self) ?struct { entity: ecs.Entity, side: loot.Side } {
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

        const curr = self.current();
        const current_side = self.side;
        self.rotate();
        self.iterations += 1;
        if (curr) |current_ety| {
            return .{ .entity = current_ety, .side = current_side };
        }

        return null;
    }
};

fn cleanupFog(reg: *ecs.Registry, tile_fog: *cmp.TileFog, entity: ecs.Entity) void {
    reg.addOrReplace(tile_fog.entity, ccmp.Destroyed {});

    reg.remove(cmp.TileFog, entity);
}

fn cleanupOpener(reg: *ecs.Registry, tile_opener: *cmp.TileOpener, entity: ecs.Entity) void {
    reg.addOrReplace(tile_opener.entity, ccmp.Destroyed {});

    reg.remove(cmp.TileOpener, entity);
}

fn cleanupLoot(
    reg: *ecs.Registry,
    tile_loot: *cmp.TileLoot,
    entity: ecs.Entity,
    items: *const itm.ItemListCfg
) void {
    if (reg.tryGet(rcmp.GlobalPosition, tile_loot.entity)) |pos| {
        const loot_cmp = reg.get(cmp.Loot, tile_loot.entity);

        var collector_view = reg.view(.{ cmp.ItemCollector, rcmp.GlobalPosition }, .{});
        var collector_iter = collector_view.entityIterator();
        while (collector_iter.next()) |collector_ety| {
            const collector_position = reg.get(rcmp.GlobalPosition, collector_ety);

            if (items.map.get(loot_cmp.item_name)) |item_cfg| {
                const effect = reg.create();
                reg.add(effect, rcmp.ImageResource {
                    .atlas = item_cfg.view.atlas,
                    .image = item_cfg.view.image,
                });
                reg.add(effect, rcmp.Position { .x = pos.x, .y = pos.y });
                reg.add(effect, rcmp.AttachTo { .target = null });
                reg.add(effect, rcmp.Order { .order = game.RenderLayers.GAMEPLLAY_EFFECT });

                const tween_duration = 0.5;
                const tween_x = reg.create();
                reg.add(tween_x, rcmp.TweenMove { .axis = .X });
                reg.add(tween_x, rcmp.TweenSetup {
                    .from = pos.x,
                    .to = collector_position.x,
                    .entity = effect,
                    .duration = tween_duration,
                    .remove_source = true,
                });

                const tween_y = reg.create();
                reg.add(tween_y, rcmp.TweenMove { .axis = .Y });
                reg.add(tween_y, rcmp.TweenSetup {
                    .from = pos.y,
                    .to = collector_position.y,
                    .entity = effect,
                    .duration = tween_duration,
                    .easing = .EaseIn
                });
            }
        }
    }
    
    reg.addOrReplace(tile_loot.entity, ccmp.Destroyed {});

    reg.remove(cmp.TileLoot, entity);
}

pub fn openTile(reg: *ecs.Registry, props: *pr.Properties, items: *itm.Items) !void {
    var click_view = reg.view(.{ gcmp.ButtonClicked, cmp.Opener }, .{});
    var click_iter = click_view.entityIterator();
    while (click_iter.next()) |entity| {
        if (reg.assure(cmp.CharacterMoveTween).len() > 0) {
            continue;
        }

        const opener = reg.getConst(cmp.Opener, entity);
        reg.addOrReplace(opener.tile, cmp.Open {});
    }

    var view = reg.view(.{ cmp.Open, cmp.Tile, rcmp.Parent }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const open = reg.get(cmp.Open, entity);
        const parent = reg.getConst(rcmp.Parent, entity);
        const loot_start = if (reg.tryGetConst(cmp.LootStart, parent.entity)) |loot_start|
            loot_start else continue;
        
        const cfg = loot_start.cfg_json.value;
        const cost_property = cfg.cost.property;
        const stamina = props.get(cost_property);
        const step_cost = cfg.cost.cost;
        
        if (!reg.has(cmp.Visited, entity)) {
            if (stamina < step_cost and !open.free) {
                game.selectNextScene(reg);
                continue;
            }
            
            reg.add(entity, cmp.Visited {});

            if (!open.free) {
                try props.add(cost_property, -step_cost);
            }
        }

        if (reg.tryGet(cmp.TileFog, entity)) |tile_fog| {
            cleanupFog(reg, tile_fog, entity);
        }

        if (reg.tryGet(cmp.TileOpener, entity)) |tile_opener| {
            const opener = reg.getConst(cmp.Opener, tile_opener.entity);
            cleanupOpener(reg, tile_opener, entity);

            var source_connection_iter = ConnectionIterator.init(reg, opener.source_tile);
            while (source_connection_iter.next()) |source_neighbour_entry| {
                if (reg.tryGet(cmp.TileOpener, source_neighbour_entry.entity)) |source_neighbour_opener| {
                    cleanupOpener(reg, source_neighbour_opener, source_neighbour_entry.entity);

                    if (
                        !reg.has(cmp.TileFog, source_neighbour_entry.entity)
                        and !reg.has(cmp.Visited, source_neighbour_entry.entity)
                    ) {
                        reg.add(source_neighbour_entry.entity, cmp.TileFog {
                            .entity = createFog(reg, source_neighbour_entry.entity, &cfg),
                        });
                    }
                }
            }

            moveCharacter(reg, opener.source_tile, entity, &cfg);
        }

        var connection_iter = ConnectionIterator.init(reg, entity);
        while (connection_iter.next()) |neighbour_entry| {
            if (!reg.has(cmp.TileOpener, neighbour_entry.entity)) {
                reg.add(neighbour_entry.entity, cmp.TileOpener {
                    .entity = createOpenable(reg, neighbour_entry.entity, entity, &cfg, neighbour_entry.side),
                });
            }
        }

        if (reg.tryGet(cmp.TileLoot, entity)) |tile_loot| {
            const loot_on_tile = reg.get(cmp.Loot, tile_loot.entity);
            _ = try items.add(loot_on_tile.item_name);

            cleanupLoot(reg, tile_loot, entity, items.item_list_cfg);
        }

        reg.remove(cmp.Open, entity);
    }
}