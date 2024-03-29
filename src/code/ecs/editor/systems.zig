const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const gcmp = @import("../gui/components.zig");
const scmp = @import("../scene/components.zig");
const ccmp = @import("../core/components.zig");
const scene_systems = @import("../scene/systems.zig");
const gui_setup = @import("../../engine/gui_setup.zig");

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
            .color = gui_setup.ColorButton,
            .rect = gui_setup.SizeButtonSmall,
        });
        reg.add(entity, cmp.NewEntityButtonReady {});

        const text_entity = reg.create();
        reg.add(text_entity, rcmp.AttachTo {
            .target = entity
        });
        reg.add(text_entity, rcmp.Position { .x = gui_setup.MarginText.l, .y = gui_setup.MarginText.t });
        reg.add(text_entity, rcmp.Text {
            .text = "+",
            .size = gui_setup.SizeText,
            .color = gui_setup.ColorButtonText,
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
                .height = gui_setup.SizePanelItem.height + gui_setup.MarginPanelItem.h,
                .width = gui_setup.SizePanelItem.width + gui_setup.MarginPanelItem.w,
                .idx = idx,
            });
            reg.add(btn_entity, gcmp.InitButton {
                .rect = gui_setup.SizePanelItem,
                .color = gui_setup.ColorButton,
            });

            const text_entity = reg.create();
            reg.add(text_entity, rcmp.AttachTo {
                .target = btn_entity
            });
            reg.add(text_entity, rcmp.Position { .x = gui_setup.MarginText.l, .y = gui_setup.MarginText.t });
            reg.add(text_entity, rcmp.Text {
                .text = shortify(@typeName(cmp_type)),
                .size = gui_setup.SizeText,
                .color = gui_setup.ColorButtonText,
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
                .height = gui_setup.SizePanelItem.height + gui_setup.MarginPanelItem.h,
                .width = gui_setup.SizePanelItem.width + gui_setup.MarginPanelItem.w,
            });
            reg.add(btn_entity, gcmp.InitButton {
                .rect = gui_setup.SizePanelItem,
                .color = gui_setup.ColorButton,
            });
            reg.add(btn_entity, cmp.GameObjectButton {
                .entity = go_entity,
            });

            const text_entity = reg.create();
            reg.add(text_entity, rcmp.AttachTo {
                .target = btn_entity
            });
            reg.add(text_entity, rcmp.Position { .x = gui_setup.MarginText.l, .y = gui_setup.MarginText.t });
            reg.add(text_entity, rcmp.Text {
                .text = try std.fmt.allocPrint(allocator, "{d}", .{ go_entity }),
                .size = gui_setup.SizeText,
                .color = gui_setup.ColorButtonText,
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

pub fn component_instance_panel(reg: *ecs.Registry) void {
    //init panel
    var init_view = reg.view(.{ cmp.ComponentInstancePanel }, .{ cmp.ComponentInstancePanelReady, gcmp.LinearLayout });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        reg.add(entity, gcmp.LinearLayout {
            .dir = gcmp.LayoutDirection.TOP_DOWN,
        });

        reg.add(entity, cmp.ComponentInstancePanelReady {});
    }

    var view = reg.view(.{ cmp.ComponentInstancePanel, cmp.ComponentInstancePanelReady }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        if (reg.has(rcmp.Children, entity)) {
            var buttons = view.get(rcmp.Children, entity);
            var unselected_view = reg.view(.{ cmp.DisplayedOnComponentInstancePanel }, .{ cmp.SelectedEditorObject });
            var unselected_iter = unselected_view.entityIterator();
            while (unselected_iter.next()) |unselected_entity| {
                for (buttons.children.items) |btn_entity| {
                    reg.add(btn_entity, ccmp.Destroyed {});
                }
                reg.remove(cmp.DisplayedOnComponentInstancePanel, unselected_entity);
            }
        }

        var selected_view = reg.view(.{ cmp.SelectedEditorObject }, .{ cmp.DisplayedOnComponentInstancePanel });
        var selected_iter = selected_view.entityIterator();
        while (selected_iter.next()) |selected_entity| {
            inline for (scene_systems.scene_components, 0..) |cmp_type, idx| {
                if (reg.has(cmp_type, selected_entity)) {
                    const btn_entity = reg.create();
                    reg.add(btn_entity, rcmp.AttachTo {
                        .target = entity
                    });
                    reg.add(btn_entity, gcmp.InitLayoutElement { 
                        .height = gui_setup.SizePanelItem.height + gui_setup.MarginPanelItem.h,
                        .width = gui_setup.SizePanelItem.width + gui_setup.MarginPanelItem.w,
                        .idx = idx,
                    });
                    reg.add(btn_entity, gcmp.InitButton {
                        .rect = gui_setup.SizePanelItem,
                        .color = gui_setup.ColorButton,
                    });

                    const text_entity = reg.create();
                    reg.add(text_entity, rcmp.AttachTo {
                        .target = btn_entity
                    });
                    reg.add(text_entity, rcmp.Position { .x = gui_setup.MarginText.l, .y = gui_setup.MarginText.t });
                    reg.add(text_entity, rcmp.Text {
                        .text = shortify(@typeName(cmp_type)),
                        .size = gui_setup.SizeText,
                        .color = gui_setup.ColorButtonText,
                    });
                }
            }

            reg.add(selected_entity, cmp.DisplayedOnComponentInstancePanel {});
        }
    }
}

pub fn init(reg: *ecs.Registry) void {
    var group = reg.group(.{ cmp.EditorScene }, .{}, .{});
    if (group.len() < 1) {
        const scene_ety = reg.create();
        reg.add(scene_ety, cmp.EditorScene {});
        reg.add(scene_ety, cmp.EditorObject {});
        reg.add(scene_ety, scmp.Scene {});
        reg.add(scene_ety, rcmp.UpdateGlobalTransform {});
    }
}