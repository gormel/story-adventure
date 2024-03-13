const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const gcmp = @import("../gui/components.zig");
const scmp = @import("../scene/components.zig");
const ccmp = @import("../core/components.zig");
const scene_systems = @import("../scene/systems.zig");

pub fn shortify(comptime str: []const u8) []const u8 {
    return comptime res: {
        var result: []const u8 = "";
        
        var tokens = std.mem.tokenize(u8, str, ".");
        while (tokens.next()) |token| {
            if (token.len > 0) {
                if (tokens.peek()) |_| {
                    result = result ++ [_] u8 { std.ascii.toLower(token[0]), '.' };
                } else {
                    result = result ++ token;
                }
            }
        }

        break :res result ++ [_] u8 { 0 };
    };
}

pub fn new_entity_button(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.NewEntityButton }, .{ cmp.NewEntityButtonReady, gcmp.Button, gcmp.InitButton });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, gcmp.InitButton {
            .color = rl.Color { .r = 51, .g = 58, .b = 115, .a = 255 },
            .rect = rl.Rectangle { .x = 0, .y = 0, .width = 20, .height = 20 },
        });
        reg.add(entity, cmp.NewEntityButtonReady {});

        const text_entity = reg.create();
        reg.add(text_entity, rcmp.AttachTo {
            .target = entity
        });
        reg.add(text_entity, rcmp.Position { .x = 7, .y = 5 });
        reg.add(text_entity, rcmp.Text {
            .text = "+",
            .size = 10,
            .color = rl.Color { .r = 80, .g = 196, .b = 237, .a = 255 },
        });
    }

    var click_view = reg.view(.{ cmp.NewEntityButton, gcmp.ButtonClick }, .{});
    var click_iter = click_view.entityIterator();
    while (click_iter.next()) |_| {
        var selected_view = reg.view(.{ cmp.EditorObject, cmp.SelectedEditorObject }, .{}); //TODO: selected
        var selected_iter = selected_view.entityIterator();
        while (selected_iter.next()) |selected_entity| {
            var new_entity = reg.create();
            reg.add(new_entity, rcmp.Position { .x = 0, .y = 0 });
            reg.add(new_entity, rcmp.Scale { .x = 1, .y = 1 });
            reg.add(new_entity, rcmp.Rotation { .a = 0 });
            reg.add(new_entity, rcmp.AttachTo { .target = selected_entity });
            reg.add(new_entity, scmp.GameObject { });
            reg.add(new_entity, cmp.EditorObject { });
        }
    }
}

pub fn components_panel(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.ComponentPanel }, .{ cmp.ComponentPanelReady, gcmp.LinearLayout });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, gcmp.LinearLayout {
            .dir = gcmp.LayoutDirection.TOP_DOWN,
        });

        inline for (scene_systems.scene_components, 0..) |cmp_type, idx| {

            const btn_entity = reg.create();
            reg.add(btn_entity, rcmp.AttachTo {
                .target = entity
            });
            reg.add(btn_entity, gcmp.InitLayoutElement { 
                .height = 25,
                .width = 200,
                .idx = idx,
            });
            reg.add(btn_entity, gcmp.InitButton {
                .rect = rl.Rectangle { .x = 0, .y = 0, .width = 200, .height = 20 },
                .color = rl.Color { .r = 51, .g = 58, .b = 115, .a = 255 },
            });

            const text_entity = reg.create();
            reg.add(text_entity, rcmp.AttachTo {
                .target = btn_entity
            });
            reg.add(text_entity, rcmp.Position { .x = 10, .y = 5 });
            reg.add(text_entity, rcmp.Text {
                .text = shortify(@typeName(cmp_type)),
                .size = 10,
                .color = rl.Color { .r = 80, .g = 196, .b = 237, .a = 255 },
            });
        }

        reg.add(entity, cmp.ComponentPanelReady {});
    }
}

pub fn game_object_panel(reg: *ecs.Registry, allocator: std.mem.Allocator) error { OutOfMemory }!void {
    var view = reg.view(.{ cmp.GameObjectPanel }, .{ cmp.GameObjectPanelReady, gcmp.LinearLayout });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, gcmp.LinearLayout {
            .dir = gcmp.LayoutDirection.TOP_DOWN,
        });

        reg.add(entity, cmp.GameObjectPanelReady {});
    }

    var panel_view = reg.view(.{ cmp.GameObjectPanel, cmp.GameObjectPanelReady }, .{});
    var panel_iter = panel_view.entityIterator();
    while (panel_iter.next()) |entity| {
        
        var go_view = reg.view(.{ cmp.EditorObject }, .{ cmp.ListedEditorObject });
        var go_iter = go_view.entityIterator();
        while (go_iter.next()) |go_entity| {
            const btn_entity = reg.create();
            reg.add(btn_entity, rcmp.AttachTo {
                .target = entity
            });
            reg.add(btn_entity, gcmp.InitLayoutElement { 
                .height = 25,
                .width = 200,
            });
            reg.add(btn_entity, gcmp.InitButton {
                .rect = rl.Rectangle { .x = 0, .y = 0, .width = 200, .height = 20 },
                .color = rl.Color { .r = 51, .g = 58, .b = 115, .a = 255 },
            });
            reg.add(btn_entity, cmp.GameObjectButton {
                .entity = go_entity,
            });

            const text_entity = reg.create();
            reg.add(text_entity, rcmp.AttachTo {
                .target = btn_entity
            });
            reg.add(text_entity, rcmp.Position { .x = 10, .y = 5 });
            reg.add(text_entity, rcmp.Text {
                .text = try std.fmt.allocPrint(allocator, "{d}", .{ go_entity }),
                .size = 10,
                .color = rl.Color { .r = 80, .g = 196, .b = 237, .a = 255 },
            });

            reg.add(go_entity, cmp.ListedEditorObject {
                .button_entity = btn_entity,
            });
        }
    }

    var btn_view = reg.view(.{ cmp.GameObjectButton, gcmp.ButtonClick }, .{});
    var btn_iter = btn_view.entityIterator();
    while (btn_iter.next()) |entity| {
        var btn = btn_view.getConst(cmp.GameObjectButton, entity);

        var selected_view = reg.view(.{ cmp.SelectedEditorObject }, .{});
        var selected_iter = selected_view.entityIterator();
        while (selected_iter.next()) |selected_entity| {
            reg.remove(cmp.SelectedEditorObject, selected_entity);
        }

        reg.add(btn.entity, cmp.SelectedEditorObject {});
    }
}

pub fn game_object_panel_on_destroy(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.ListedEditorObject, cmp.EditorObject, ccmp.Destroyed }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var listed = view.getConst(cmp.ListedEditorObject, entity);

        reg.add(listed.button_entity, ccmp.DestroyNextFrame {});
    }
}

pub fn init(reg: *ecs.Registry) void {
    var group = reg.group(.{ cmp.EditorScene }, .{}, .{});
    if (group.len() < 1) {
        const scene_ety = reg.create();
        reg.add(scene_ety, cmp.EditorScene {});
        reg.add(scene_ety, cmp.EditorObject {});
        reg.add(scene_ety, scmp.Scene {});
    }
}