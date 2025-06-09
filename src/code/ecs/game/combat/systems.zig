const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const condition = @import("../../../engine/condition.zig");
const easing = @import("../../render/easing.zig");
const utils = @import("../../../engine/utils.zig");
const rutils = @import("../../render/utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");

const combat = @import("combat.zig");
const cfg_text = @embedFile("../../../assets/cfg/scene_customs/combat.json");

const STRATEGY_ICON_SIZE = 64;
const STRATEGY_ICON_PADDING = 5;

const HIT_EFFECT_DURATION = 0.2;
const DEATH_EFFECT_DURATION = 0.2;

const DEBUG_ALL_STRATEGYS = false;

fn createStrategyBtn(reg: *ecs.Registry, parent: ecs.Entity, cfg: *combat.CombatCfg, strategy: []const u8) ecs.Entity {
    const root_ety = reg.create();
    reg.add(root_ety, rcmp.AttachTo { .target = parent });

    if (cfg.strategy.map.get(strategy)) |strategy_cfg| {
        const icon_ety = reg.create();
        reg.add(icon_ety, rcmp.Position { .x = -STRATEGY_ICON_SIZE, .y = -STRATEGY_ICON_SIZE / 2 });
        reg.add(icon_ety, rcmp.ImageResource {
            .atlas = strategy_cfg.view.icon.atlas,
            .image = strategy_cfg.view.icon.image,
        });
        reg.add(icon_ety, gcmp.CreateButton {});
        reg.add(icon_ety, cmp.StrategyButton { .strategy_id = strategy });
        reg.add(icon_ety, rcmp.AttachTo { .target = root_ety });

        const text_ety = reg.create();
        reg.add(text_ety, rcmp.Position { .x = STRATEGY_ICON_PADDING, .y = -gui_setup.SizeText / 2 });
        reg.add(text_ety, rcmp.Text {
            .size = gui_setup.SizeTextBig,
            .color = gui_setup.ColorLabelText,
            .text = strategy_cfg.view.name,
        });
        reg.add(text_ety, rcmp.AttachTo { .target = root_ety });
    }

    return root_ety;
}

pub fn initStrategy(reg: *ecs.Registry, props: *pr.Properties, allocator: std.mem.Allocator) !void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "combat-strategy-container")) {
            var cfg_json = try std.json.parseFromSlice(combat.CombatCfg, allocator, cfg_text,
                .{ .ignore_unknown_fields = true });
            
            reg.add(entity, cmp.CfgOwner { .cfg_json = cfg_json });
            reg.add(entity, cmp.StrategyRoot {});

            var strategy_iter = cfg_json.value.strategy.map.iterator();
            while (strategy_iter.next()) |kv| {
                if (condition.check(kv.value_ptr.condition, props) or DEBUG_ALL_STRATEGYS) {
                    _ = createStrategyBtn(reg, entity, &cfg_json.value, kv.key_ptr.*);
                }
            }

            reg.add(entity, gcmp.LayoutChildren {
                .axis = gcmp.LayoutAxis.Vertical,
                .pivot = gcmp.LayoutPivot.Center,
                .distance = STRATEGY_ICON_SIZE + STRATEGY_ICON_PADDING,
            });
        }
    }
}

pub fn freeCombat(reg: *ecs.Registry) void {
    var cfg_view = reg.view(.{ cmp.CfgOwner, ccmp.Destroyed }, .{});
    var cfg_iter = cfg_view.entityIterator();
    while (cfg_iter.next()) |entity| {
        var owner = reg.get(cmp.CfgOwner, entity);
        owner.cfg_json.deinit();
    }

    var enemy_view = reg.view(.{ cmp.Enemy, cmp.Character, ccmp.Destroyed }, .{});
    var enemy_iter = enemy_view.entityIterator();
    while (enemy_iter.next()) |entity| {
        var char = reg.get(cmp.Character, entity);
        char.props.deinit();
    }

    var modify_view = reg.view(.{ cmp.CharacterModifyList, ccmp.Destroyed }, .{});
    var modify_iter = modify_view.entityIterator();
    while (modify_iter.next()) |entity| {
        var list = reg.get(cmp.CharacterModifyList, entity);
        list.entities.deinit();
    }
}

pub fn initPlayer(reg: *ecs.Registry, allocator: std.mem.Allocator, props: *pr.Properties) !void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "combat-hero-root")) {
            const cfg_json = try std.json.parseFromSlice(combat.CombatCfg, allocator, cfg_text,
                .{ .ignore_unknown_fields = true });
            reg.add(entity, cmp.CfgOwner { .cfg_json = cfg_json });

            const sprite_ety = reg.create();
            reg.add(sprite_ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
            reg.add(sprite_ety, rcmp.ImageResource {
                .atlas = cfg_json.value.hero_view.atlas,
                .image = cfg_json.value.hero_view.idle,
            });
            reg.add(sprite_ety, rcmp.AttachTo { .target = entity });

            reg.add(entity, cmp.Hero {});
            reg.add(entity, cmp.Character { .props = props.*, .view = sprite_ety });
        }
    }
}

pub fn initCharMsgRoot(reg: *ecs.Registry) void {
    var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "combat-charmessage-root")) {
            reg.add(entity, cmp.CreateCharMsgRoot {});
        }
    }
}

pub fn charMessageRoot(reg: *ecs.Registry) void {
    var create_view = reg.view(.{ cmp.CreateCharMsgRoot, rcmp.Parent }, .{});
    var create_iter = create_view.entityIterator();
    while (create_iter.next()) |entity| {
        const parent = reg.get(rcmp.Parent, entity);

        reg.addOrReplace(parent.entity, cmp.CharMsgRoot { .root = entity });
        reg.remove(cmp.CreateCharMsgRoot, entity);
    }
}

pub fn initEnemy(reg: *ecs.Registry, allocator: std.mem.Allocator, props: *pr.Properties, rnd: *std.Random) !void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "combat-enemy-root")) {
            const cfg_json = try std.json.parseFromSlice(combat.CombatCfg, allocator, cfg_text, .{ .ignore_unknown_fields = true });
            reg.add(entity, cmp.CfgOwner { .cfg_json = cfg_json });
            reg.addOrReplace(entity, rcmp.Scale { .x = -1, .y = 1 });
            reg.addOrReplace(entity, rcmp.UpdateGlobalTransform {});

            var to_select_size: usize = 0;
            var to_select = try allocator.alloc(combat.EnemyCfg, cfg_json.value.enemy.len);
            defer allocator.free(to_select);
            for (cfg_json.value.enemy) |enemy_cfg| {
                if (condition.check(enemy_cfg.condition, props)) {
                    to_select[to_select_size] = enemy_cfg;
                    to_select_size += 1;
                }
            }

            if (rr.select(combat.EnemyCfg, "weight", to_select[0..to_select_size], rnd)) |enemy_cfg| {
                var enemy_props = pr.Properties.initSilent(allocator, reg);
                var prop_iter = enemy_cfg.params.map.iterator();
                while (prop_iter.next()) |kv| {
                    try enemy_props.create(kv.key_ptr.*, kv.value_ptr.*);
                }

                const sprite_ety = reg.create();
                reg.add(sprite_ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
                reg.add(sprite_ety, rcmp.ImageResource {
                    .atlas = enemy_cfg.view.atlas,
                    .image = enemy_cfg.view.idle,
                });
                reg.add(sprite_ety, rcmp.AttachTo { .target = entity });

                reg.add(entity, cmp.Enemy { .cfg = enemy_cfg });
                reg.add(entity, cmp.Character { .props = enemy_props, .view = sprite_ety  });
            }
        }
    }
}

fn applyCost(props: *pr.Properties, cost: std.json.ArrayHashMap(f64)) !void {
    var iter = cost.map.iterator();
    while (iter.next()) |kv| {
        try props.add(kv.key_ptr.*, -kv.value_ptr.*);
    }
}

fn createAttackEffect(
    reg: *ecs.Registry,
    source: ecs.Entity,
    attack_cfg: combat.AttackViewCfg,
) void {
    var state = reg.get(cmp.AttackSatate, source);

    if (attack_cfg.begin) |begin_view| {
        const ety = reg.create();
        reg.add(ety, rcmp.AttachTo { .target = source });
        reg.add(ety, rcmp.FlipbookSetup { .repeat = .OnceRemove });
        reg.add(ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
        reg.add(ety, rcmp.ImageResource {
            .atlas = begin_view.atlas,
            .image = begin_view.image,
        });

        state.begin = ety;
    }

    if (attack_cfg.particles) |projectiles| {
        const target_pos = reg.get(rcmp.GlobalPosition, state.target);

        for (projectiles) |proj_view| {
            const ety = reg.create();
            reg.add(ety, rcmp.AttachTo { .target = source });
            reg.add(ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
            reg.add(ety, rcmp.ImageResource {
                .atlas = proj_view.view.atlas,
                .image = proj_view.view.image,
            });

            if (proj_view.scale) |scale| {
                reg.add(ety, rcmp.Scale { .x = @floatCast(scale), .y = @floatCast(scale) });
            }

            if (proj_view.color) |color| {
                reg.add(ety, rcmp.Color {
                    .r = @intFromFloat(color.r),
                    .g = @intFromFloat(color.g),
                    .b = @intFromFloat(color.b),
                    .a = @intFromFloat(color.a orelse 255),
                });
            }

            if (proj_view.offset) |offset| {
                reg.add(ety, rcmp.HideUntilTimer { .time = @floatCast(offset) });
            }

            var local_x = target_pos.x;
            var local_y = target_pos.y;
            rutils.worldToLocalXY(reg, source, &local_x, &local_y);

            const tween_x = reg.create();
            reg.add(tween_x, rcmp.TweenMove { .axis = .X });
            reg.add(tween_x, rcmp.TweenSetup {
                .from = 0,
                .to = local_x,
                .entity = ety,
                .duration = @floatCast(proj_view.time orelse attack_cfg.delay),
                .offset = @floatCast(proj_view.offset orelse 0),
                .remove_source = true,
            });

            const tween_y = reg.create();
            reg.add(tween_y, rcmp.TweenMove { .axis = .Y });
            reg.add(tween_y, rcmp.TweenSetup {
                .from = 0,
                .to = local_y,
                .entity = ety,
                .duration = @floatCast(proj_view.time orelse attack_cfg.delay),
                .offset = @floatCast(proj_view.offset orelse 0),
            });
        }

    }
}

fn resetModify(reg: *ecs.Registry, owner: ecs.Entity, source: ecs.Entity) void {
    if (reg.tryGet(cmp.CharacterModifyList, owner)) |modify_list| {
        var i: i32 = 0;
        while (i < modify_list.entities.items.len) : (i += 1) {
            const modify_entity = modify_list.entities.items[@intCast(i)];
            if (reg.tryGet(cmp.CharacterModify, modify_entity)) |modify| {
                if (modify.source_character == source) {
                    reg.add(modify_entity, ccmp.Destroyed {});
                    _ = modify_list.entities.orderedRemove(@intCast(i));
                    i -= 1;
                }
            } else {
                _ = modify_list.entities.orderedRemove(@intCast(i));
                i -= 1;
            }
        }
    }
}

fn createModify(reg: *ecs.Registry, source: ecs.Entity, modify: std.json.ArrayHashMap(f64)) ecs.Entity {
    const entity = reg.create();

    reg.add(entity, cmp.CharacterModify {
        .source_character = source,
        .props = modify,
    });

    return entity;
}

fn addModify(reg: *ecs.Registry, target: ecs.Entity, source: ecs.Entity, modify: std.json.ArrayHashMap(f64), allocator: std.mem.Allocator) !void {
    if (reg.tryGet(cmp.CharacterModifyList, target)) |modify_list| {
        try modify_list.entities.append(createModify(reg, source, modify));
    } else {
        var entities = std.ArrayList(ecs.Entity).init(allocator);
        try entities.append(createModify(reg, source, modify));

        reg.add(target, cmp.CharacterModifyList {
            .entities = entities
        });
    }
}

fn getPropValue(reg: *ecs.Registry, property: []const u8, character: ecs.Entity) f64 {
    const char = reg.get(cmp.Character, character);
    var value = char.props.get(property);

    if (reg.tryGet(cmp.CharacterModifyList, character)) |modify_list| {
        for (modify_list.entities.items) |modify_entity| {
            if (reg.tryGet(cmp.CharacterModify, modify_entity)) |modify| {
                if (modify.props.map.get(property)) |mul| {
                    value *= mul;
                }
            }
        }
    }

    return value;
}

pub fn attack(reg: *ecs.Registry, allocator:std.mem.Allocator) !void {
    var attack_view = reg.view(.{ cmp.Character, cmp.Attack, cmp.CfgOwner }, .{ cmp.Dead });
    var attack_iter = attack_view.entityIterator();
    while (attack_iter.next()) |entity| {
        const cfg = reg.get(cmp.CfgOwner, entity);
        var char = reg.get(cmp.Character, entity);
        const attk = reg.get(cmp.Attack, entity);
        var target_char = reg.get(cmp.Character, attk.target);

        const cfg_json = cfg.cfg_json.value;
        
        if (cfg_json.strategy.map.get(attk.strategy)) |strategy_cfg| {
            if (condition.check(strategy_cfg.cost, &char.props)) {
                try applyCost(&char.props, strategy_cfg.cost);

                resetModify(reg, entity, entity);
                resetModify(reg, attk.target, entity);

                try addModify(reg, entity, entity, strategy_cfg.modify, allocator);
                try addModify(reg, attk.target, entity, strategy_cfg.modify_opp, allocator);

                const armor = getPropValue(reg, cfg_json.armor_prop, attk.target);
                const raw_dmg = getPropValue(reg, cfg_json.attack_prop, entity);
                const dmg = @max(raw_dmg - armor, 1);

                try target_char.props.add(cfg_json.hp_prop, -dmg);
                reg.addOrReplace(attk.target, cmp.CheckDeath {});

                if (reg.tryGet(cmp.CharMsgRoot, entity)) |root| {
                    const message = reg.create();
                    reg.add(message, gcmp.CreateMessage {
                        .parent = root.root,
                        .x = 0,
                        .y = 0,
                        .text = strategy_cfg.view.name,
                        .free = false,
                    });
                }

                reg.addOrReplace(entity, cmp.AttackSatate {
                    .dmg = dmg,
                    .time = strategy_cfg.view.attack.delay,
                    .target = attk.target,
                    .strategy = attk.strategy,
                });

                createAttackEffect(reg, entity, strategy_cfg.view.attack); 
            } else {
                var state_iter = reg.entityIterator(cmp.CombatState);
                while (state_iter.next()) |state_entity| {
                    reg.addOrReplace(state_entity, cmp.CombatStateAttackFailedRequest {});
                }

                if (reg.tryGet(cmp.CharMsgRoot, entity)) |root| {
                    const message = reg.create();
                    reg.add(message, gcmp.CreateMessage {
                        .parent = root.root,
                        .x = 0,
                        .y = 0,
                        .text = "Cannot pay attack cost!",
                        .free = false,
                    });
                }
            }
        }

        reg.remove(cmp.Attack, entity);
    }
}

fn createDeathEffect(reg: *ecs.Registry, char: ecs.Entity) void {
    const scale_ety = reg.create();
    reg.add(scale_ety, cmp.DeathTween { .character = char });
    reg.add(scale_ety, rcmp.TweenScale { .axis = rcmp.Axis.XY });
    reg.add(scale_ety, rcmp.TweenSetup {
        .entity = char,
        .from = 1,
        .to = 0,
        .duration = DEATH_EFFECT_DURATION,
        .easing = easing.Easing.EaseIn,
        .repeat = rcmp.TweenRepeat.OnceForward,
    });

    const rotate_ety = reg.create();
    reg.add(rotate_ety, rcmp.TweenRotate {});
    reg.add(rotate_ety, rcmp.TweenSetup {
        .entity = char,
        .from = 0,
        .to = 360,
        .duration = DEATH_EFFECT_DURATION / 2.0,
        .easing = easing.Easing.EaseIn,
        .repeat = rcmp.TweenRepeat.RepeatForward,
    });
}

fn createDamageEffect(reg: *ecs.Registry, char_ety: ecs.Entity, dmg: f64, allocator: std.mem.Allocator) !void {
    const char = reg.get(cmp.Character, char_ety);
    const scale = reg.get(rcmp.GlobalScale, char_ety);

    if (reg.tryGet(cmp.CharMsgRoot, char_ety)) |root| {
        const dmg_text = try std.fmt.allocPrintZ(allocator, "-{d:.0} HP", .{ dmg });
        const message = reg.create();
        reg.add(message, gcmp.CreateMessage {
            .parent = root.root,
            .x = 0,
            .y = 0,
            .text = dmg_text,
            .free = true,
        });
    }

    const scale_x_ety = reg.create();
    reg.add(scale_x_ety, rcmp.TweenScale { .axis = rcmp.Axis.X });
    reg.add(scale_x_ety, rcmp.TweenSetup {
        .entity = char_ety,
        .from = scale.x,
        .to = scale.x * 1.2,
        .duration = HIT_EFFECT_DURATION,
        .easing = easing.Easing.EaseOut,
        .repeat = rcmp.TweenRepeat.OncePinpong,
    });

    const scale_y_ety = reg.create();
    reg.add(scale_y_ety, rcmp.TweenScale { .axis = rcmp.Axis.Y });
    reg.add(scale_y_ety, rcmp.TweenSetup {
        .entity = char_ety,
        .from = scale.y,
        .to = scale.y * 1.2,
        .duration = HIT_EFFECT_DURATION,
        .easing = easing.Easing.EaseOut,
        .repeat = rcmp.TweenRepeat.OncePinpong,
    });

    const gb_color_ety = reg.create();
    reg.add(gb_color_ety, rcmp.TweenColor { .component = rcmp.ColorComponent.GB });
    reg.add(gb_color_ety, rcmp.TweenSetup {
        .entity = char.view,
        .from = 255,
        .to = 0,
        .duration = HIT_EFFECT_DURATION,
        .easing = easing.Easing.EaseOut,
        .repeat = rcmp.TweenRepeat.OncePinpong,
    });
}

pub fn attackEffectComplete(reg: *ecs.Registry, allocator: std.mem.Allocator, dt: f32) !void {
    var attk_view = reg.view(.{ cmp.AttackSatate, cmp.CfgOwner, cmp.Character }, .{});
    var attk_iter = attk_view.entityIterator();
    while (attk_iter.next()) |entity| {
        var state = reg.get(cmp.AttackSatate, entity);
        state.time -= dt;
        if (state.time <= 0) {
            const cfg = reg.get(cmp.CfgOwner, entity);
            if (cfg.cfg_json.value.strategy.map.get(state.strategy)) |strategy_cfg| {
                if (strategy_cfg.view.attack.end) |end| {
                    const ety = reg.create();
                    reg.add(ety, rcmp.ImageResource {
                        .atlas = end.atlas,
                        .image = end.image,
                    });
                    reg.add(ety, rcmp.FlipbookSetup { .repeat = .OnceRemove });
                    reg.add(ety, rcmp.AttachTo { .target = state.target });
                    reg.add(ety, rcmp.ImagePivot { .x = 0.5, .y = 0.5 });
                }
            }
            
            if (state.begin) |begin| {
                if (reg.valid(begin)) {
                    reg.addOrReplace(begin, ccmp.Destroyed {});
                }
            }

            if (reg.has(cmp.Dead, state.target)) {
                createDeathEffect(reg, state.target);
            } else {
                try createDamageEffect(reg, state.target, state.dmg, allocator);
            }

            var state_iter = reg.entityIterator(cmp.CombatState);
            while (state_iter.next()) |state_entity| {
                reg.addOrReplace(state_entity, cmp.CombatStateAttackCompleteRequest {
                    .source_char = entity
                });
            }

            reg.remove(cmp.AttackSatate, entity);
        }
    }
}

pub fn deathEffectComplete(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.DeathTween, rcmp.TweenComplete }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {        
        var state_view = reg.view(.{ cmp.CombatState }, .{ cmp.CombatStateDeathCompleteRequest });
        var state_iter = state_view.entityIterator();
        while (state_iter.next()) |state_entity| {
            reg.add(state_entity, cmp.CombatStateDeathCompleteRequest {});
        }
    }
}

pub fn checkDeath(reg: *ecs.Registry) !void {
    var view = reg.view(.{ cmp.Character, cmp.CheckDeath, cmp.CfgOwner }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var char = reg.get(cmp.Character, entity);
        const cfg = reg.get(cmp.CfgOwner, entity);

        const hp = char.props.get(cfg.cfg_json.value.hp_prop);
        if (hp <= 0) {
            reg.add(entity, cmp.Dead {});
        }

        reg.remove(cmp.CheckDeath, entity);
    }
}

pub fn initState(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "combat-logic")) {
            reg.add(entity, cmp.CombatState {});
            reg.add(entity, cmp.CombatStatePlayerIdle {});
        }
    }
}

fn tryGetEntity(comptime Component: type, reg: *ecs.Registry) ?ecs.Entity {
    var iter = reg.entityIterator(Component);
    while (iter.next()) |entity| {
        return entity;
    }

    return null;
}

fn setHidden(comptime Component: type, reg: *ecs.Registry, hidden: bool) void {
    var iter = reg.entityIterator(Component);
    while (iter.next()) |entity| {
        if (hidden) {
            reg.addOrReplace(entity, rcmp.Disabled {});
        } else {
            reg.removeIfExists(rcmp.Disabled, entity);
        }
    }
}

pub fn combatState(
    reg: *ecs.Registry,
    props: *pr.Properties,
    rnd: *std.Random,
    allocator: std.mem.Allocator
) !void {
    var idle_view = reg.view(.{ cmp.CombatState, cmp.CombatStatePlayerIdle }, .{ cmp.CombatStatePlayerAttack });
    var idle_iter = idle_view.entityIterator();
    while (idle_iter.next()) |entity| {
        var click_view = reg.view(.{ gcmp.ButtonClicked, cmp.StrategyButton }, .{});
        var click_iter = click_view.entityIterator();
        while (click_iter.next()) |btn_entity| {
            const btn = reg.get(cmp.StrategyButton, btn_entity);
            
            const hero_ety = tryGetEntity(cmp.Hero, reg) orelse continue;
            const enemy_ety = tryGetEntity(cmp.Enemy, reg) orelse continue;
            
            reg.add(hero_ety, cmp.Attack {
                .target = enemy_ety,
                .strategy = btn.strategy_id,
            });

            setHidden(cmp.StrategyRoot, reg, true);

            reg.remove(cmp.CombatStatePlayerIdle, entity);
            reg.add(entity, cmp.CombatStatePlayerAttack {});
        }
    }

    var player_attk_view = reg.view(.{ cmp.CombatState, cmp.CombatStatePlayerAttack, cmp.CombatStateAttackCompleteRequest }, .{ cmp.CombatStateEnemyAttack });
    var player_attk_iter = player_attk_view.entityIterator();
    while (player_attk_iter.next()) |entity| {
        const hero_ety = tryGetEntity(cmp.Hero, reg) orelse continue;
        const enemy_ety = tryGetEntity(cmp.Enemy, reg) orelse continue;

        if (reg.has(cmp.Dead, enemy_ety)) {
            reg.remove(cmp.CombatStateAttackCompleteRequest, entity);
            reg.remove(cmp.CombatStatePlayerAttack, entity);
            reg.add(entity, cmp.CombatStateEnemyDead { .enemy = enemy_ety });
            continue;
        }
        
        var enemy = reg.get(cmp.Enemy, enemy_ety);
        const cfg = reg.get(cmp.CfgOwner, enemy_ety);
        var char = reg.get(cmp.Character, enemy_ety);
        const TableT = struct { weight: f64, strategy: []const u8 };
        var table_size: usize = 0;
        var table = try allocator.alloc(TableT, enemy.cfg.strategy.map.count());
        defer allocator.free(table);

        var strat_iter = enemy.cfg.strategy.map.iterator();
        while (strat_iter.next()) |kv| {
            if (cfg.cfg_json.value.strategy.map.get(kv.key_ptr.*)) |strat_cfg| {
                if (condition.check(strat_cfg.cost, &char.props)) {
                    table[table_size].weight = kv.value_ptr.*;
                    table[table_size].strategy = kv.key_ptr.*;
                    table_size += 1;
                }
            }
        }

        if (rr.select(TableT, "weight", table[0..table_size], rnd)) |table_item| {
            reg.add(enemy_ety, cmp.Attack {
                .target = hero_ety,
                .strategy = table_item.strategy,
            });
        } else {
            reg.add(entity, cmp.CombatStateAttackFailedRequest {});
        }

        reg.remove(cmp.CombatStatePlayerAttack, entity);
        reg.remove(cmp.CombatStateAttackCompleteRequest, entity);
        reg.add(entity, cmp.CombatStateEnemyAttack {});
    }

    var enemy_attk_view = reg.view(.{ cmp.CombatState, cmp.CombatStateEnemyAttack, cmp.CombatStateAttackCompleteRequest }, .{ cmp.CombatStatePlayerIdle });
    var enemy_attk_iter = enemy_attk_view.entityIterator();
    while (enemy_attk_iter.next()) |entity| {
        const hero_ety = tryGetEntity(cmp.Hero, reg) orelse continue;

        if (reg.has(cmp.Dead, hero_ety)) {
            reg.remove(cmp.CombatStateAttackCompleteRequest, entity);
            reg.remove(cmp.CombatStateEnemyAttack, entity);
            reg.add(entity, cmp.CombatStatePlayerDead {});
            continue;
        }

        setHidden(cmp.StrategyRoot, reg, false);

        reg.remove(cmp.CombatStateAttackCompleteRequest, entity);
        reg.remove(cmp.CombatStateEnemyAttack, entity);
        reg.add(entity, cmp.CombatStatePlayerIdle {});
    }

    var player_dead_view = reg.view(.{ cmp.CombatState, cmp.CombatStatePlayerDead, cmp.CombatStateDeathCompleteRequest }, .{});
    var player_dead_iter = player_dead_view.entityIterator();
    while (player_dead_iter.next()) |entity| {
        reg.remove(cmp.CombatStateDeathCompleteRequest, entity);

        try game.gameOver(reg, allocator);
    }

    var enemy_dead_view = reg.view(.{ cmp.CombatState, cmp.CombatStateEnemyDead, cmp.CombatStateDeathCompleteRequest }, .{});
    var enemy_dead_iter = enemy_dead_view.entityIterator();
    while (enemy_dead_iter.next()) |entity| {
        const state = reg.get(cmp.CombatStateEnemyDead, entity);
        var enemy = reg.get(cmp.Enemy, state.enemy);

        var iter = enemy.cfg.reward.map.iterator();
        while (iter.next()) |kv| {
            try props.add(kv.key_ptr.*, kv.value_ptr.*);
        }

        reg.remove(cmp.CombatStateDeathCompleteRequest, entity);

        game.selectNextScene(reg);
    }

    var enemyattackfailed_view = reg.view(.{ cmp.CombatState, cmp.CombatStateEnemyAttack, cmp.CombatStateAttackFailedRequest }, .{});
    var enemyattackfailed_iter = enemyattackfailed_view.entityIterator();
    while (enemyattackfailed_iter.next()) |entity| {
        setHidden(cmp.StrategyRoot, reg, false);

        reg.remove(cmp.CombatStateAttackFailedRequest, entity);
        reg.remove(cmp.CombatStateEnemyAttack, entity);
        reg.add(entity, cmp.CombatStatePlayerIdle {});
    }

    var playerattackfailed_view = reg.view(.{ cmp.CombatState, cmp.CombatStatePlayerAttack, cmp.CombatStateAttackFailedRequest }, .{});
    var playerattackfailed_iter = playerattackfailed_view.entityIterator();
    while (playerattackfailed_iter.next()) |entity| {
        setHidden(cmp.StrategyRoot, reg, false);

        reg.remove(cmp.CombatStateAttackFailedRequest, entity);
        reg.remove(cmp.CombatStatePlayerAttack, entity);
        reg.add(entity, cmp.CombatStatePlayerIdle {});
    }
}