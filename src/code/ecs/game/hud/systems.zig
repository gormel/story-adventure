const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const pr = @import("../../../engine/properties.zig");
const utils = @import("../../../engine/utils.zig");
const gamemenu = @import("../gamemenu/gamemenu.zig");
const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const ccmp = @import("../../core/components.zig");
const rcmp = @import("../../render/components.zig");
const gcmp = @import("../components.zig");

const textSelector = fn (props: *pr.Properties, name: []const u8, allocator: std.mem.Allocator) [:0]const u8;

pub fn initViews(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "health-view")) {
            reg.add(entity, cmp.HealthView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "stamina-view")) {
            reg.add(entity, cmp.StaminaView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "gold-view")) {
            reg.add(entity, cmp.GoldView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "store-reroll-view")) {
            reg.add(entity, cmp.StoreRerollView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "armor-view")) {
            reg.add(entity, cmp.ArmorView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "attack-view")) {
            reg.add(entity, cmp.AttackView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "hud-gamemenu-btn")) {
            reg.add(entity, cmp.GameMenuButton {});
        }

        if (utils.containsTag(init.tags, "hud-popup-root")) {
            reg.add(entity, cmp.PopupRoot {});
        }
    }
}

fn addSync(comptime ComponentT: type, reg: *ecs.Registry) void {
    var view = reg.view(.{ ComponentT }, .{ cmp.SyncView });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.SyncView {});
    }
}

fn selectValue(props: *pr.Properties, name: []const u8, allocator: std.mem.Allocator) [:0]const u8 {
    const value = props.get(name);
    return std.fmt.allocPrintZ(allocator, "{d:.0}", .{ value }) catch "0" ++ .{ 0 };
}

fn selectValueOfMax(props: *pr.Properties, name: []const u8, allocator: std.mem.Allocator) [:0]const u8 {
    const value = props.get(name);
    var max = props.getInitial(name);
    if (props.setup) |setup| {
        max = setup.max.map.get(name) orelse max;
    }
    
    return std.fmt.allocPrintZ(allocator, "{d:.0} / {d:.0}", .{ value, max }) catch "0 / 0" ++ .{ 0 };
}

fn syncProperty(
    comptime ComponentT: type,
    comptime propertyName: []const u8,
    reg: *ecs.Registry,
    props: *pr.Properties,
    allocator: std.mem.Allocator,
    comptime selector: textSelector
) void {
    var view = reg.view(.{ ComponentT, cmp.SyncView }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.remove(cmp.SyncView, entity);
        const value = selector(props, propertyName, allocator);
        if (reg.tryGet(rcmp.SetTextValue, entity)) |set_text| {
            if (set_text.free) {
                allocator.free(set_text.text);
            }

            set_text.text = value;
            set_text.free = true;
        } else {
            reg.add(entity, rcmp.SetTextValue {
                .text = value,
                .free = true,
            });
        }
    }
}

pub fn syncViews(reg: *ecs.Registry, props: *pr.Properties, allocator: std.mem.Allocator) void {
    var iter = reg.entityIterator(gcmp.PlayerPropertyChanged);
    while (iter.next()) |entity| {
        const changed = reg.getConst(gcmp.PlayerPropertyChanged, entity);
        if (std.mem.eql(u8, changed.name, "health")) {
            addSync(cmp.HealthView, reg);
        }

        if (std.mem.eql(u8, changed.name, "stamina")) {
            addSync(cmp.StaminaView, reg);
        }
        
        if (std.mem.eql(u8, changed.name, "gold")) {
            addSync(cmp.GoldView, reg);
        }
        
        if (std.mem.eql(u8, changed.name, "store-reroll")) {
            addSync(cmp.StoreRerollView, reg);
        }
        
        if (std.mem.eql(u8, changed.name, "attack")) {
            addSync(cmp.AttackView, reg);
        }
        
        if (std.mem.eql(u8, changed.name, "armor")) {
            addSync(cmp.ArmorView, reg);
        }
    }

    syncProperty(cmp.HealthView, "health", reg, props, allocator, selectValueOfMax);
    syncProperty(cmp.StaminaView, "stamina", reg, props, allocator, selectValueOfMax);
    syncProperty(cmp.GoldView, "gold", reg, props, allocator, selectValue);
    syncProperty(cmp.StoreRerollView, "store-reroll", reg, props, allocator, selectValue);
    syncProperty(cmp.AttackView, "attack", reg, props, allocator, selectValue);
    syncProperty(cmp.ArmorView, "armor", reg, props, allocator, selectValue);
}

pub fn gui(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var gamemenu_btn_view = reg.view(.{ cmp.GameMenuButton, gcmp.ButtonClicked }, .{});
    var gamemenu_btn_iter = gamemenu_btn_view.entityIterator();
    while (gamemenu_btn_iter.next()) |_| {

        var root_iter = reg.entityIterator(cmp.PopupRoot);
        while (root_iter.next()) |root_ety| {
            const scene_ety = try gamemenu.loadScene(reg, allocator);
            reg.addOrReplace(scene_ety, rcmp.AttachTo { .target = root_ety });
            reg.add(scene_ety, cmp.GameMenuScene {});
        }
    }

    var close_gamemenu_view = reg.view(.{ cmp.CloseGameMenu, cmp.GameMenuScene }, .{});
    var close_gamemenu_iter = close_gamemenu_view.entityIterator();
    while (close_gamemenu_iter.next()) |entity| {
        reg.addOrReplace(entity, ccmp.Destroyed {});
    }
}