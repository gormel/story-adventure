const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("utils.zig");
const utils = @import("../../engine/utils.zig");
const sc = @import("../../engine/scene.zig");
const pr = @import("../../engine/properties.zig");
const rollrate = @import("../../engine/rollrate.zig");
const itm = @import("../../engine/items.zig");
const gui_setup = @import("../../engine/gui_setup.zig");
const mainmenu_utils = @import("mainmenu/mainmenu.zig");
const is = @import("../input/inputstack.zig");

const cmp = @import("components.zig");
const scmp = @import("../scene/components.zig");
const icmp = @import("../input/components.zig");
const rcmp = @import("../render/components.zig");
const ccmp = @import("../core/components.zig");

const mainmenu = @import("mainmenu/systems.zig");
const gameplaystart = @import("gameplaystart/systems.zig");
const hud = @import("hud/systems.zig");
const loot = @import("loot/systems.zig");
const combat = @import("combat/systems.zig");
const gameover = @import("gameover/systems.zig");
const gamestats = @import("gamestats/systems.zig");
const gamemenu = @import("gamemenu/systems.zig");
const iteminfo = @import("iteminfo/systems.zig");
const itemcollection = @import("itemcollection/systems.zig");
const shop = @import("shop/systems.zig");

const BUTTON_ANIM_DELAY = 0.2;
const BUTTON_ANIM_SCALE = 1.1;

fn setupTween(reg: *ecs.Registry, ety: ecs.Entity, from: f32, to: f32, dur: f32, target: ecs.Entity) void {
    reg.add(ety, rcmp.TweenSetup {
        .from = from,
        .to = to,
        .duration = dur,
        .entity = target,
        .repeat = .OncePinpong,
        .easing = .EaseOut,
    });
}

pub fn initButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button")) {
            reg.add(entity, cmp.CreateButton {});
        }

        if (utils.containsTag(init.tags, "button-text")) {
            reg.add(entity, rcmp.SetTextColor { .color = gui_setup.ColorButtonText });
        }
    }
}

pub fn button(reg: *ecs.Registry, dt: f32) void {
    var create_view = reg.view(.{ cmp.CreateButton, rcmp.Sprite }, .{});
    var create_iter = create_view.entityIterator();
    while (create_iter.next()) |entity| {
        const create = reg.get(cmp.CreateButton, entity);

        reg.add(entity, cmp.Button {});
        const sprite = create_view.getConst(rcmp.Sprite, entity);
        
        reg.add(entity, icmp.MousePositionTracker { });
        reg.add(entity, icmp.MouseOverTracker { .rect = sprite.sprite.rect });
        reg.add(entity, icmp.MouseButtonTracker { .button = rl.MouseButton.left });

        if (create.animated) {
            reg.add(entity, cmp.AnimatedButton {});
        }

        reg.remove(cmp.CreateButton, entity);
    }

    var clicked_iter = reg.entityIterator(cmp.ButtonClicked);
    while (clicked_iter.next()) |entity| {
        reg.remove(cmp.ButtonClicked, entity);
    }

    var anim_view = reg.view(.{ icmp.MouseOver, icmp.MouseOverTracker, cmp.AnimatedButton }, .{ cmp.ButtonAnimating });
    var anim_iter = anim_view.entityIterator();
    while (anim_iter.next()) |entity| {
        const tracker = reg.get(icmp.MouseOverTracker, entity);

        const dx: f32 = tracker.rect.width * (BUTTON_ANIM_SCALE - 1) / 2;
        const dy: f32 = tracker.rect.height * (BUTTON_ANIM_SCALE - 1) / 2;

        var px: f32 = 0;
        var py: f32 = 0;
        if (reg.tryGet(rcmp.Position, entity)) |pos| {
            px = pos.x;
            py = pos.y;
        }

        var sx: f32 = 1;
        var sy: f32 = 1;
        if (reg.tryGet(rcmp.Scale, entity)) |scale| {
            sx = scale.x;
            sy = scale.y;
        }

        const sanimx = reg.create();
        reg.add(sanimx, rcmp.TweenScale { .axis = .X });
        setupTween(reg, sanimx, sx, sx * BUTTON_ANIM_SCALE, BUTTON_ANIM_DELAY, entity);

        const sanimy = reg.create();
        reg.add(sanimy, rcmp.TweenScale { .axis = .Y });
        setupTween(reg, sanimy, sy, sy * BUTTON_ANIM_SCALE, BUTTON_ANIM_DELAY, entity);

        const manimx = reg.create();
        reg.add(manimx, rcmp.TweenMove { .axis = .X });
        setupTween(reg, manimx, px, px - dx, BUTTON_ANIM_DELAY, entity);

        const manimy = reg.create();
        reg.add(manimy, rcmp.TweenMove { .axis = .Y });
        setupTween(reg, manimy, py, py - dy, BUTTON_ANIM_DELAY, entity);

        reg.add(entity, cmp.ButtonAnimating { .delay = BUTTON_ANIM_DELAY });
    }

    var animclean_iter = reg.entityIterator(cmp.ButtonAnimating);
    while (animclean_iter.next()) |entity| {
        const anim = reg.get(cmp.ButtonAnimating, entity);
        anim.delay -= dt;
        if (anim.delay <= 0 and !reg.has(icmp.MouseOver, entity)) {
            reg.remove(cmp.ButtonAnimating, entity);
        }
    }

    var view = reg.view(.{ icmp.MouseOver, icmp.InputPressed, cmp.Button }, .{ cmp.ButtonClicked });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.ButtonClicked {});
    }
}

pub fn hover(reg: *ecs.Registry) void {
    var show_view = reg.view(.{ icmp.MouseOver, cmp.Hover }, .{ cmp.Hovered });
    var show_iter = show_view.entityIterator();
    while (show_iter.next()) |entity| {
        const hover_ety = reg.get(cmp.Hover, entity);

        reg.removeIfExists(rcmp.Disabled, hover_ety.entity);

        reg.add(entity, cmp.Hovered {});
    }

    var hide_view = reg.view(.{ cmp.Hover, cmp.Hovered }, .{ icmp.MouseOver });
    var hide_iter = hide_view.entityIterator();
    while (hide_iter.next()) |entity| {
        const hover_ety = reg.get(cmp.Hover, entity);

        reg.addOrReplace(hover_ety.entity, rcmp.Disabled {});
        reg.remove(cmp.Hovered, entity);
    }
}

pub fn inputCapture(reg: *ecs.Registry, input_stack: *is.InputStack) !void {
    var set_iter = reg.entityIterator(cmp.SetInputCaptureScene);
    while (set_iter.next()) |entity| {
        reg.remove(cmp.SetInputCaptureScene, entity);

        reg.addOrReplace(entity, cmp.InputCaptureScene {});
        try input_stack.push(entity);
    }
}

pub fn freeInputCapture(reg: *ecs.Registry, input_stack: *is.InputStack) void {
    var free_view = reg.view(.{ ccmp.Destroyed, cmp.InputCaptureScene }, .{});
    var free_iter = free_view.entityIterator();
    while (free_iter.next()) |entity| {
        input_stack.remove(entity);
    }
}

pub fn initProperties(reg: *ecs.Registry, json: std.json.ObjectMap, props: *pr.Properties) !void {
    _ = reg;
    var it = json.iterator();
    while (it.next()) |entry| {
        try props.create(entry.key_ptr.*, entry.value_ptr.float);
    }

    try props.load();
}

pub fn properties(reg: *ecs.Registry) void {
    var cleanup_view = reg.view(.{ cmp.PlayerPropertyChanged }, .{});
    var cleanup_iter = cleanup_view.entityIterator();
    while (cleanup_iter.next()) |entity| {
        reg.remove(cmp.PlayerPropertyChanged, entity);
        reg.add(entity, ccmp.Destroyed {});
    }

    var set_view = reg.view(.{ cmp.TriggerPlayerPropertyChanged }, .{});
    var set_iter = set_view.entityIterator();
    while (set_iter.next()) |entity| {
        const trigger = reg.get(cmp.TriggerPlayerPropertyChanged, entity);
        reg.add(entity, cmp.PlayerPropertyChanged { .name = trigger.name });
        reg.remove(cmp.TriggerPlayerPropertyChanged, entity);
    }
}

fn checkNames(a_n: ?[]const u8, b_n: ?[]const u8) bool {
    if (a_n) |a| {
        if (b_n) |b| {
            return std.mem.eql(u8, a, b);
        } else {
            return false;
        }
    } else {
        if (b_n) |_| {
            return false;
        } else {
            return true;
        }
    }
}

fn checkCondition(params: []sc.RuleParam, props: *pr.Properties) bool {
    if (params.len == 0) {
        return true;
    }

    for (params) |param| {
        const value = props.get(param.name);
        switch (param.operator) {
            .LT => { if (value >= param.value) { return false; } },
            .LE => { if (value > param.value) { return false; } },
            .EQ => { if (value != param.value) { return false; } },
            .GE => { if (value < param.value) { return false; } },
            .GT => { if (value <= param.value) { return false; } },
        }
    }
    return true;
}

pub fn initScene(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    const state_entity = reg.create();
    reg.add(state_entity, cmp.GameState {});

    try mainmenu_utils.loadScene(reg, allocator);
}

pub fn message(reg: *ecs.Registry, dt: f32) void {
    var delay_view = reg.view(.{ cmp.MessageDelay }, .{});
    var delay_iter = delay_view.entityIterator();
    while (delay_iter.next()) |entity| {
        var delay = reg.get(cmp.MessageDelay, entity);
        delay.time -= dt;
        if (delay.time <= 0) {
            reg.remove(cmp.MessageDelay, entity);
        }
    }

    var create_view = reg.view(.{ cmp.CreateMessage }, .{});
    var create_iter = create_view.entityIterator();
    while (create_iter.next()) |entity| {
        const create = reg.get(cmp.CreateMessage, entity);
        if (create.parent) |parent| {
            if (reg.has(cmp.MessageDelay, parent)) {
                continue;
            }

            reg.add(parent, cmp.MessageDelay {
                .time = gui_setup.MessageDelay,
            });
        }

        reg.add(entity, rcmp.Position { .x = create.x, .y = create.y });
        reg.add(entity, rcmp.AttachTo { .target = create.parent });
        reg.add(entity, rcmp.Text {
            .color = gui_setup.ColorLabelText,
            .size = gui_setup.SizeText,
            .text = create.text,
            .free = create.free,
        });

        const move_ety = reg.create();
        reg.add(move_ety, rcmp.TweenMove { .axis = rcmp.Axis.Y });
        reg.add(move_ety, rcmp.TweenSetup {
            .entity = entity,
            .from = create.y,
            .to = create.y - gui_setup.MessageShift,
            .duration = gui_setup.MessageDuration,
            .remove_source = true,
        });

        const opacity_ety = reg.create();
        reg.add(opacity_ety, rcmp.TweenColor { .component = rcmp.ColorComponent.A });
        reg.add(opacity_ety, rcmp.TweenSetup {
            .entity = entity,
            .from = 255,
            .to = 0,
            .duration = gui_setup.MessageDuration,
        });

        reg.remove(cmp.CreateMessage, entity);
    }
}

fn applyExitChangeProps(cfg: game.ScenePropChangeItemCfg, props: *pr.Properties) !void {
    var change_iter = cfg.exit.map.iterator();
    while (change_iter.next()) |change_kv| {
        try props.add(change_kv.key_ptr.*, change_kv.value_ptr.*);
    }
}

pub fn changeScene(
    reg: *ecs.Registry,
    props: *pr.Properties,
    rules: *sc.Rules,
    change: *game.ScenePropChangeCfg,
    rnd: *std.Random,
    allocator: std.mem.Allocator
) !void {
    var view = reg.view(.{ cmp.GameplayScene, cmp.NextGameplayScene }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const scene = reg.get(cmp.GameplayScene, entity);
        const scene_name = scene.name;

        var rule_count: usize = 0;
        var rules_to_roll = try allocator.alloc(sc.Rule, rules.*.len);
        defer allocator.free(rules_to_roll);
        for (rules.*) |rule| {
            if (
                checkNames(rule.current_scene, scene_name)
                and checkCondition(rule.params, props)
            ) {
                rules_to_roll[rule_count] = rule;
                rule_count += 1;
            }
        }

        if (rule_count > 0) {
            const roll = rollrate.select(sc.Rule, "weight", rules_to_roll[0..rule_count], rnd);
            if (roll) |ok_roll| {
                reg.add(entity, ccmp.Destroyed {});

                if (change.map.get(game.ALL_SCENES_PROPERTY_CHANGE_NAME)) |change_item| {
                    try applyExitChangeProps(change_item, props);
                }

                if (change.map.get(scene_name)) |change_item| {
                    try applyExitChangeProps(change_item, props);
                }

                _ = try game.loadScene(reg, allocator, ok_roll.result_scene, .{
                    .props = props,
                    .change = change,
                });
            }
        }
        
        reg.remove(cmp.NextGameplayScene, entity);
    }
}

pub fn initGameplayCustoms(
    reg: *ecs.Registry,
    props: *pr.Properties,
    allocator: std.mem.Allocator,
    rnd: *std.Random
) !void {
    mainmenu.initGui(reg);

    try gameplaystart.initSwitch(reg, allocator);

    hud.initViews(reg);

    try loot.initLoot(reg, allocator, rnd);
    loot.initGui(reg);

    try combat.initStrategy(reg, props, allocator);
    try combat.initPlayer(reg, allocator, props);
    try combat.initEnemy(reg, allocator, props, rnd);
    combat.initState(reg);

    try shop.initShop(reg, allocator);
    try shop.initStall(reg);
    try shop.initItem(reg);

    gamestats.initGui(reg);
    gameover.initGui(reg);
    gamemenu.initGui(reg);
    iteminfo.initGui(reg);
    itemcollection.initGui(reg);
}

pub fn updateGameplayCustoms(
    reg: *ecs.Registry,
    props: *pr.Properties,
    change: *game.ScenePropChangeCfg,
    allocator: std.mem.Allocator,
    items: *itm.Items,
    rnd: *std.Random,
    dt: f32
) !void {
    try mainmenu.gui(reg, props, change, allocator);
    gameplaystart.doSwitch(reg);
    hud.syncViews(reg, props, allocator);
    try hud.gui(reg, allocator);

    try loot.rollItem(reg, items, rnd);
    try loot.openTile(reg, props, items);
    loot.character(reg);
    loot.gui(reg);

    try combat.attack(reg, allocator);
    combat.attackEffect(reg, dt);
    try combat.attackEffectComplete(reg, allocator);
    combat.deathEffectComplete(reg);
    try combat.checkDeath(reg);
    try combat.combatState(reg, props, rnd, allocator);

    shop.scene(reg);
    try shop.stall(reg, allocator, items, rnd, props);
    try shop.item(reg, allocator, items, props);

    try gamestats.gui(reg, props, items.item_list_cfg, allocator);
    try gameover.gui(reg, props, allocator);
    try gamemenu.gui(reg, allocator);
    try iteminfo.gui(reg, items.item_list_cfg, allocator);
    try itemcollection.gui(reg, items.item_list_cfg, items.item_progress_cfg, props, allocator);
}

pub fn freeGameplayCustoms(reg: *ecs.Registry) !void {
    loot.freeLootStart(reg);
    combat.freeCombat(reg);
    shop.free(reg);
    gamestats.free(reg);
    itemcollection.free(reg);
}

fn lessThanLayoutChild(reg: *ecs.Registry, a: ecs.Entity, b: ecs.Entity) bool {
    const a_pos = if (reg.tryGet(cmp.LayoutPosition, a)) |pos| pos.position else std.math.maxInt(usize);
    const b_pos = if (reg.tryGet(cmp.LayoutPosition, b)) |pos| pos.position else std.math.maxInt(usize);

    return a_pos < b_pos;
}

pub fn layoutChildren(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.LayoutChildren, rcmp.Children }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const layout = reg.get(cmp.LayoutChildren, entity);
        const children = reg.get(rcmp.Children, entity);

        var dx: f32 = 0;
        var dy: f32 = 0;

        switch (layout.axis) {
            .Horizontal => { dx = layout.distance; },
            .Vertical => { dy = layout.distance; },
        }

        const children_count = @as(f32, @floatFromInt(children.children.items.len));

        var origin_x: f32 = 0;
        var origin_y: f32 = 0;
        switch (layout.pivot) {
            .Begin => {},
            .Center => {
                origin_x = -dx * (children_count - 1) / 2.0;
                origin_y = -dy * (children_count - 1) / 2.0;
            },
            .End => {
                origin_x = -dx * (children_count - 1);
                origin_y = -dy * (children_count - 1);
            },
        }

        const sorted_children = try allocator.alloc(ecs.Entity, children.children.items.len);
        std.mem.copyForwards(ecs.Entity, sorted_children, children.children.items);
        std.sort.heap(ecs.Entity, sorted_children, reg, lessThanLayoutChild);

        for (sorted_children, 0..) |child_entity, i| {
            var position = reg.getOrAdd(rcmp.Position, child_entity);
            position.x = origin_x + dx * @as(f32, @floatFromInt(i));
            position.y = origin_y + dy * @as(f32, @floatFromInt(i));

            reg.addOrReplace(child_entity, rcmp.UpdateGlobalTransform {});
        }
    }
}