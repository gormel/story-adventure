const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const gcmp = @import("../components.zig");

const Properties = @import("../../../engine/parameters.zig").Properties;

pub fn initHpView(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) !void {
    var ph_iter = reg.entityIterator(scmp.InitGameObject);
    while (ph_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "view-hp")) {
            reg.add(entity, cmp.ViewCurrentHp {});
            
            var hp = try props.get("health");
            reg.add(entity, rcmp.SetTextValue {
                .text = try std.fmt.allocPrintZ(allocator, "{d}", .{ hp }),
                .free = true,
            });
        }
    }
}

pub fn initNextButton(reg: *ecs.Registry) void {
    var iter = reg.entityIterator(scmp.InitGameObject);
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-next-level")) {
            reg.add(entity, cmp.NextLevelButton {});
        }
    }
}

pub fn nextLevel(reg: *ecs.Registry, props: *Properties) !void {
    var view = reg.view(.{ cmp.NextLevelButton, gcmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        var hp = try props.get("health");
        try props.set("health", hp - 10);

        game.selectNextScene(reg);
    }
}

pub fn updateHealth(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) !void {
    var hp_prop_iter = reg.entityIterator(gcmp.PlayerPropertyChanged);
    while (hp_prop_iter.next()) |entity| {
        const changed = reg.get(gcmp.PlayerPropertyChanged, entity);
        if (std.mem.eql(u8, changed.name, "health")) {
            var view_view = reg.view(.{ rcmp.Text, cmp.ViewCurrentHp }, .{ rcmp.SetTextValue });
            var hp = try props.get("health");
            var view_iter = view_view.entityIterator();
            while (view_iter.next()) |view_entity| {
                if (reg.tryGet(rcmp.SetTextValue, view_entity)) |set| {
                    if (set.free) {
                        allocator.free(set.text);
                    }
                    set.text = try std.fmt.allocPrintZ(allocator, "{d}", .{ hp });
                    set.free = true;
                } else {
                    reg.add(view_entity, rcmp.SetTextValue {
                        .text = try std.fmt.allocPrintZ(allocator, "{d}", .{ hp }),
                        .free = true,
                    });
                }
            }
        }
    }
}