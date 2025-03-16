const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const condition = @import("../../../engine/condition.zig");
const easing = @import("../../render/easing.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");

const combat = @import("combat.zig");
const cfg_text = @embedFile("../../../assets/cfg/scene_customs/combat.json");

const STRATEGY_ICON_SIZE = 64;
const STRATEGY_ICON_PADDING = 5;

const CHARACTER_SPRITE_SIZE = 32;
const ATTACK_EFFECT_SIZE = 8;
const ATTACK_EFFECT_DURATION = 1;
const ATTACK_EFFECT_HEIGHT = 40;
const ATTACK_PARTICLE_DELAY = 0.01;
const ATTACK_PARTICLE_LIFETIME = 0.3;

const HIT_EFFECT_DURATION = 0.2;
const DEATH_EFFECT_DURATION = 0.2;

const HP_PROP_NAME = "health";
const ATTACK_PROP_NAME = "attack";
const ARMOR_PROP_NAME = "armor";

fn createStrategyBtn(reg: *ecs.Registry, parent: ecs.Entity, cfg: *combat.CombatCfg, strategy: []const u8) ecs.Entity {
    const root_ety = reg.create();
    reg.add(root_ety, rcmp.AttachTo { .target = parent });

    if (cfg.strategy.map.get(strategy)) |strategy_cfg| {
        const icon_ety = reg.create();
        reg.add(icon_ety, rcmp.Position { .x = -STRATEGY_ICON_SIZE, .y = -STRATEGY_ICON_SIZE / 2 });
        reg.add(icon_ety, rcmp.SpriteResource {
            .atlas = strategy_cfg.view.atlas,
            .sprite = strategy_cfg.view.icon,
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
            var cfg_json = try std.json.parseFromSlice(combat.CombatCfg, allocator, cfg_text, .{ .ignore_unknown_fields = true });
            reg.add(entity, cmp.CfgOwner { .cfg_json = cfg_json });

            reg.add(entity, cmp.StrategyRoot {});

            var strategy_iter = cfg_json.value.strategy.map.iterator();
            while (strategy_iter.next()) |kv| {
                if (condition.check(kv.value_ptr.condition, props)) {
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
            const cfg_json = try std.json.parseFromSlice(combat.CombatCfg, allocator, cfg_text, .{ .ignore_unknown_fields = true });
            reg.add(entity, cmp.CfgOwner { .cfg_json = cfg_json });

            const sprite_ety = reg.create();
            reg.add(sprite_ety, rcmp.Position {
                .x = -CHARACTER_SPRITE_SIZE / 2,
                .y = -CHARACTER_SPRITE_SIZE / 2,
            });
            reg.add(sprite_ety, rcmp.SpriteResource {
                .atlas = cfg_json.value.hero_view.atlas,
                .sprite = cfg_json.value.hero_view.idle,
            });
            reg.add(sprite_ety, rcmp.AttachTo { .target = entity });

            reg.add(entity, cmp.Hero {});
            reg.add(entity, cmp.Character { .props = props.*, .view = sprite_ety });
        }
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
                reg.add(sprite_ety, rcmp.Position {
                    .x = -CHARACTER_SPRITE_SIZE / 2,
                    .y = -CHARACTER_SPRITE_SIZE / 2,
                });
                reg.add(sprite_ety, rcmp.SpriteResource {
                    .atlas = enemy_cfg.view.atlas,
                    .sprite = enemy_cfg.view.idle,
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
    target: ecs.Entity,
    attack_cfg: combat.AttackViewCfg,
    dmg: f64
) void {
    const char_pos = reg.get(rcmp.GlobalPosition, source);
    const target_pos = reg.get(rcmp.GlobalPosition, target);

    const projectile_ety = reg.create();
    reg.add(projectile_ety, rcmp.AttachTo { .target = target });
    reg.add(projectile_ety, rcmp.Position { .x = char_pos.x - target_pos.x, .y = char_pos.y - target_pos.y });
    reg.add(projectile_ety, cmp.AttackEffect {
        .cfg = attack_cfg,
        .delay = ATTACK_PARTICLE_DELAY,
        .target = target,
        .dmg = dmg,
    });

    const image_ety = reg.create();
    reg.add(image_ety, rcmp.Position { .x = -ATTACK_EFFECT_SIZE / 2, .y = -ATTACK_EFFECT_SIZE / 2 });
    reg.add(image_ety, rcmp.AttachTo { .target = projectile_ety });
    reg.add(image_ety, rcmp.SpriteResource {
        .atlas = attack_cfg.atlas,
        .sprite = attack_cfg.effect,
    });

    const x_tween_ety = reg.create();
    reg.add(x_tween_ety, rcmp.TweenMove { .axis = rcmp.Axis.X });
    reg.add(x_tween_ety, rcmp.TweenSetup {
        .entity = projectile_ety,
        .from = char_pos.x - target_pos.x,
        .to = 0,
        .duration = ATTACK_EFFECT_DURATION,
        .remove_source = true,
    });
    reg.add(x_tween_ety, cmp.AttackEffectTween {
        .target_char = target,
        .source_char = source,
        .dmg = dmg,
    });

    const y_tween_ety = reg.create();
    reg.add(y_tween_ety, rcmp.TweenMove { .axis = rcmp.Axis.Y });
    reg.add(y_tween_ety, rcmp.TweenSetup {
        .entity = projectile_ety,
        .from = 0,
        .to = -ATTACK_EFFECT_HEIGHT,
        .duration = ATTACK_EFFECT_DURATION,
        .easing = easing.Easing.EaseOutQuad,
        .repeat = rcmp.TweenRepeat.OncePinpong,
    });
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
        var cfg = reg.get(cmp.CfgOwner, entity);
        var char = reg.get(cmp.Character, entity);
        const attk = reg.get(cmp.Attack, entity);
        var target_char = reg.get(cmp.Character, attk.target);
        
        if (cfg.cfg_json.value.strategy.map.get(attk.strategy)) |strategy_cfg| {
            if (condition.check(strategy_cfg.cost, &char.props)) {
                try applyCost(&char.props, strategy_cfg.cost);

                resetModify(reg, entity, entity);
                resetModify(reg, attk.target, entity);

                try addModify(reg, entity, entity, strategy_cfg.modify, allocator);
                try addModify(reg, attk.target, entity, strategy_cfg.modify_opp, allocator);

                const armor = getPropValue(reg, ARMOR_PROP_NAME, attk.target);
                const raw_dmg = getPropValue(reg, ATTACK_PROP_NAME, entity);
                const dmg = @max(raw_dmg - armor, 1);

                try target_char.props.add(HP_PROP_NAME, -dmg);
                if (!reg.has(cmp.CheckDeath, attk.target)) {
                    reg.add(attk.target, cmp.CheckDeath {});
                }

                const message = reg.create();
                reg.add(message, gcmp.CreateMessage {
                    .parent = entity,
                    .x = -CHARACTER_SPRITE_SIZE / 2,
                    .y = -CHARACTER_SPRITE_SIZE / 2,
                    .text = strategy_cfg.view.name,
                    .free = false,
                });

                createAttackEffect(reg, entity, attk.target, cfg.cfg_json.value.attack_view, dmg); 
            }
        }

        reg.remove(cmp.Attack, entity);
    }
}

fn createParticle(reg: *ecs.Registry, x: f32, y: f32, attack_cfg: combat.AttackViewCfg) void {
    const particle_ety = reg.create();
    reg.add(particle_ety, rcmp.AttachTo { .target = null });
    reg.add(particle_ety, rcmp.Position { .x = x, .y = y });

    const image_ety = reg.create();
    reg.add(image_ety, rcmp.Position { .x = -ATTACK_EFFECT_SIZE / 2, .y = -ATTACK_EFFECT_SIZE / 2 });
    reg.add(image_ety, rcmp.AttachTo { .target = particle_ety });
    reg.add(image_ety, rcmp.SpriteResource {
        .atlas = attack_cfg.atlas,
        .sprite = attack_cfg.effect,
    });

    const x_scale_ety = reg.create();
    reg.add(x_scale_ety, rcmp.TweenScale { .axis = rcmp.Axis.XY });
    reg.add(x_scale_ety, rcmp.TweenSetup {
        .entity = particle_ety,
        .from = 1,
        .to = 0,
        .duration = ATTACK_PARTICLE_LIFETIME,
        .remove_source = true,
    });

    const rotate_ety = reg.create();
    reg.add(rotate_ety, rcmp.TweenRotate {});
    reg.add(rotate_ety, rcmp.TweenSetup {
        .entity = particle_ety,
        .from = 0,
        .to = 360,
        .duration = ATTACK_PARTICLE_LIFETIME / 4.0,
        .repeat = rcmp.TweenRepeat.RepeatForward,
    });
}

pub fn attackEffect(reg: *ecs.Registry, dt: f32) void {
    var effect_view = reg.view(.{ cmp.AttackEffect, rcmp.GlobalPosition }, .{});
    var effect_iter = effect_view.entityIterator();
    while (effect_iter.next()) |entity| {
        var effect = reg.get(cmp.AttackEffect, entity);
        effect.delay -= dt;
        if (effect.delay <= 0) {
            effect.delay = ATTACK_PARTICLE_DELAY;

            const pos = reg.get(rcmp.GlobalPosition, entity);

            createParticle(reg, pos.x, pos.y, effect.cfg);
        }
    }
}

pub fn attackEffectComplete(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var hit_view = reg.view(.{ cmp.AttackEffectTween, rcmp.TweenComplete }, .{});
    var hit_iter = hit_view.entityIterator();
    while (hit_iter.next()) |entity| {
        const tween = reg.get(cmp.AttackEffectTween, entity);
        const char = reg.get(cmp.Character, tween.target_char);


        if (reg.has(cmp.Dead, tween.target_char)) {
            const scale_ety = reg.create();
            reg.add(scale_ety, cmp.DeathTween { .character = tween.target_char });
            reg.add(scale_ety, rcmp.TweenScale { .axis = rcmp.Axis.XY });
            reg.add(scale_ety, rcmp.TweenSetup {
                .entity = tween.target_char,
                .from = 1,
                .to = 0,
                .duration = DEATH_EFFECT_DURATION,
                .easing = easing.Easing.EaseIn,
                .repeat = rcmp.TweenRepeat.OnceForward,
            });

            const rotate_ety = reg.create();
            reg.add(rotate_ety, rcmp.TweenRotate {});
            reg.add(rotate_ety, rcmp.TweenSetup {
                .entity = tween.target_char,
                .from = 0,
                .to = 360,
                .duration = DEATH_EFFECT_DURATION / 2.0,
                .easing = easing.Easing.EaseIn,
                .repeat = rcmp.TweenRepeat.RepeatForward,
            });

        } else {
            const dmg_text = try std.fmt.allocPrintZ(allocator, "-{d:.0} HP", .{ tween.dmg });
            const message = reg.create();
            reg.add(message, gcmp.CreateMessage {
                .parent = tween.target_char,
                .x = -CHARACTER_SPRITE_SIZE / 2,
                .y = -CHARACTER_SPRITE_SIZE / 2,
                .text = dmg_text,
                .free = true,
            });

            const scale_ety = reg.create();
            reg.add(scale_ety, rcmp.TweenScale { .axis = rcmp.Axis.XY });
            reg.add(scale_ety, rcmp.TweenSetup {
                .entity = tween.target_char,
                .from = 1,
                .to = 1.2,
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

        var state_view = reg.view(.{ cmp.CombatState }, .{ });
        var state_iter = state_view.entityIterator();
        while (state_iter.next()) |state_entity| {
            reg.addOrReplace(state_entity, cmp.CombatStateAttackCompleteRequest { .source_char = tween.source_char });
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
    var view = reg.view(.{ cmp.Character, cmp.CheckDeath }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var char = reg.get(cmp.Character, entity);

        const hp = char.props.get(HP_PROP_NAME);
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
            if (!reg.has(rcmp.Disabled, entity)) {
                reg.add(entity, rcmp.Disabled {});
            }
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
        const TableT = struct { weight: f64, strategy: []const u8 };
        var table_size: usize = 0;
        var table = try allocator.alloc(TableT, enemy.cfg.strategy.map.count());
        defer allocator.free(table);

        var strat_iter = enemy.cfg.strategy.map.iterator();
        while (strat_iter.next()) |kv| {
            table[table_size].weight = kv.value_ptr.*;
            table[table_size].strategy = kv.key_ptr.*;
            table_size += 1;
        }

        if (rr.select(TableT, "weight", table[0..table_size], rnd)) |table_item| {
            reg.add(enemy_ety, cmp.Attack {
                .target = hero_ety,
                .strategy = table_item.strategy,
            });

            reg.remove(cmp.CombatStateAttackCompleteRequest, entity);
            reg.remove(cmp.CombatStatePlayerAttack, entity);
            reg.add(entity, cmp.CombatStateEnemyAttack {});
        } else {
            unreachable;
        }
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
}