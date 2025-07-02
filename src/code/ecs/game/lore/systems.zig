const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const astar = @import("zig-astar");
const game = @import("../utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");
const easing = @import("../../render/easing.zig");
const rutils = @import("../../render/utils.zig");
const utils = @import("../../../engine/utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const lore = @import("lore.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const icmp = @import("../../input/components.zig");

pub fn initGui(reg: *ecs.Registry) void {
    var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "lore-text")) {
            reg.add(entity, cmp.LoreText { .scene = init.scene, .block = 0 });
            reg.add(entity, cmp.LoadLoreBlock { .block = 0 });
            reg.add(entity, rcmp.SetTextColor { .color = gui_setup.ColorDialogueText });

            reg.add(entity, icmp.MouseButtonTracker { .button = .left });
        }

        if (utils.containsTag(init.tags, "lore-mouse-icon")) {
            const tween = reg.create();
            reg.add(tween, rcmp.TweenMove { .axis = .Y });
            reg.add(tween, rcmp.TweenSetup {
                .entity = entity,
                .duration = 1,
                .from = 0,
                .to = 8,
                .repeat = .RepeatPinpong,
                .easing = .Ease,
            });
        }
    }
}

pub fn loreText(reg: *ecs.Registry, allocator: std.mem.Allocator, dt: f32) !void {
    var loadblock_view = reg.view(.{ cmp.LoreText, cmp.LoadLoreBlock }, .{});
    var loadblock_iter = loadblock_view.entityIterator();
    while (loadblock_iter.next()) |entity| {
        const load = reg.get(cmp.LoadLoreBlock, entity);
        const block = load.block;
        reg.remove(cmp.LoadLoreBlock, entity);
        var text = reg.get(cmp.LoreText, entity);

        const scene = reg.tryGet(cmp.LoreScene, text.scene) orelse continue;
        if (scene.cfg.text.len <= block) {
            continue;
        }

        text.block = block;

        reg.addOrReplace(entity, cmp.LoreBlockState {
            .last_char = 0,
            .timer = 0,
            .full_text = scene.cfg.text[load.block],
        });
        reg.addOrReplace(entity, cmp.ForwardLoreBlock {});
    }

    var timer_iter = reg.entityIterator(cmp.LoreBlockState);
    while (timer_iter.next()) |entity| {
        var state = reg.get(cmp.LoreBlockState, entity);
        state.timer -= dt;
        if (state.timer > 0) {
            continue;
        }

        state.timer = lore.WORD_TIME;
        reg.addOrReplace(entity, cmp.ForwardLoreBlock {});
    }

    var click_view = reg.view(.{ icmp.InputPressed, cmp.LoreBlockState, cmp.LoreText }, .{});
    var click_iter = click_view.entityIterator();
    while (click_iter.next()) |entity| {
        const text = reg.get(cmp.LoreText, entity);
        const scene = reg.get(cmp.LoreScene, text.scene);
        var state = reg.get(cmp.LoreBlockState, entity);

        if (state.last_char == state.full_text.len) {
            if (text.block >= scene.cfg.text.len - 1) {
                reg.addOrReplace(text.scene, cmp.Continue {});
                continue;
            }

            reg.addOrReplace(entity, cmp.LoadLoreBlock { .block = text.block + 1 });
            continue;
        }

        state.last_char = state.full_text.len;
        reg.addOrReplace(entity, cmp.RefreshBlockText {});
    }

    var forward_view = reg.view(.{ cmp.ForwardLoreBlock, cmp.LoreBlockState }, .{});
    var forward_iter = forward_view.entityIterator();
    while (forward_iter.next()) |entity| {
        reg.remove(cmp.ForwardLoreBlock, entity);

        var state = reg.get(cmp.LoreBlockState, entity);

        const whitespace = .{ 9, 10, 11, 12, 13, 32 };
        if (std.mem.indexOfNonePos(u8, state.full_text, state.last_char, &whitespace)) |word_idx| {
            if (std.mem.indexOfAnyPos(u8, state.full_text, word_idx, &whitespace)) |space_idx| {
                state.last_char = space_idx;
                reg.addOrReplace(entity, cmp.RefreshBlockText {});
                continue;
            }
        }

        state.last_char = state.full_text.len;
        reg.addOrReplace(entity, cmp.RefreshBlockText {});
    }

    var refreshtext_view = reg.view(.{ cmp.RefreshBlockText }, .{ rcmp.SetTextValue });
    var refreshtext_iter = refreshtext_view.entityIterator();
    while (refreshtext_iter.next()) |entity| {
        reg.remove(cmp.RefreshBlockText, entity);

        const state = reg.get(cmp.LoreBlockState, entity);

        const new_slice = state.full_text[0..state.last_char];
        const new_text = try std.fmt.allocPrintZ(allocator, "{s}", .{ new_slice });
        reg.add(entity, rcmp.SetTextValue { .text = new_text, .free = true });
    }
}