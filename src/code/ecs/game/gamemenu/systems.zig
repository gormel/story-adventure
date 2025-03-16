const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");
const easing = @import("../../render/easing.zig");
const sp = @import("../../../engine/sprite.zig");
const main_menu = @import("../mainMenu/mainmenu.zig");
const game_stats = @import("../gamestats/gamestats.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const gscmp = @import("../gamestats/components.zig");
const hcmp = @import("../hud/components.zig");

pub fn initGui(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gamemenu-continue-btn")) {
            reg.add(entity, cmp.ContinueBtn { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "gamemenu-title")) {
            reg.add(entity, rcmp.SetTextColor {
                .color = gui_setup.ColorPanelTitle,
            });
        }

        if (utils.containsTag(init.tags, "gamemenu-items-btn")) {
            reg.add(entity, cmp.ItemsBtn {});
        }

        if (utils.containsTag(init.tags, "gamemenu-settings-btn")) {
            reg.add(entity, cmp.SettingsBtn {});
        }

        if (utils.containsTag(init.tags, "gamemenu-exit-btn")) {
            reg.add(entity, cmp.ExitBtn {});
        }
    }
}

pub fn gui(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var continue_view = reg.view(.{ gcmp.ButtonClicked, cmp.ContinueBtn }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const btn = reg.get(cmp.ContinueBtn, entity);

        if (!reg.has(hcmp.CloseGameMenu, btn.owner_scene)) {
            reg.add(btn.owner_scene, hcmp.CloseGameMenu {});
        }
    }

    var mainmenu_view = reg.view(.{ gcmp.ButtonClicked, cmp.ExitBtn }, .{});
    var mainmenu_iter = mainmenu_view.entityIterator();
    while (mainmenu_iter.next()) |_| {
        try game.gameOver(reg, allocator);
    }
}