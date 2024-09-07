const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const ccmp = @import("../../core/components.zig");
const rcmp = @import("../../render/components.zig");
const gcmp = @import("../components.zig");
const Properties = @import("../../../engine/parameters.zig").Properties;

const textSelector = fn (props: *Properties, name: []const u8, allocator: std.mem.Allocator) []const u8;

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

        if (utils.containsTag(init.tags, "armor-view")) {
            reg.add(entity, cmp.ArmorView {});
            reg.add(entity, cmp.SyncView {});
        }

        if (utils.containsTag(init.tags, "attack-view")) {
            reg.add(entity, cmp.AttackView {});
            reg.add(entity, cmp.SyncView {});
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

fn selectValue(props: *Properties, name: []const u8, allocator: std.mem.Allocator) []const u8 {
    var value = props.get(name) catch 0;
    return std.fmt.allocPrintZ(allocator, "{d:.0}", .{ value }) catch "0";
}

fn selectValueOfMax(props: *Properties, name: []const u8, allocator: std.mem.Allocator) []const u8 {
    var value = props.get(name) catch 0;
    var max = props.getInitial(name) catch 0;
    return std.fmt.allocPrintZ(allocator, "{d:.0}/{d:.0}", .{ value, max }) catch "0/0";
}

fn syncProperty(
    comptime ComponentT: type,
    comptime propertyName: []const u8,
    reg: *ecs.Registry,
    props: *Properties,
    allocator: std.mem.Allocator,
    comptime selector: textSelector
) void {
    var view = reg.view(.{ ComponentT, cmp.SyncView }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var value = selector(props, propertyName, allocator);
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

pub fn syncViews(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) void {
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
    syncProperty(cmp.AttackView, "attack", reg, props, allocator, selectValue);
    syncProperty(cmp.ArmorView, "armor", reg, props, allocator, selectValue);
}