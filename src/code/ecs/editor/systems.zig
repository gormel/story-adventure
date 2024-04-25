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

pub fn newEntityButton(reg: *ecs.Registry) void {
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

            reg.add(new_entity, rcmp.SolidRect { //++++ testing
                .rect = rl.Rectangle { .x = 8, .y = 5, .width = 30, .height = 88 },
                .color = rl.Color { .r = 255, .g = 45, .b = 66, .a = 255 },
            });

            reg.add(new_entity, rcmp.Text { //++++ testing
                .size = 15,
                .text = "BABAHA!",
                .color = rl.Color { .r = 0, .g = 255 - 45, .b = 255 - 66, .a = 255 },
            });
        }
    }
}

inline fn createFieldValue(
        reg: *ecs.Registry,
        parent_ety: ecs.Entity,
        value: []const u8
    ) void
{
    var value_ety = reg.create();
    reg.add(value_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(value_ety, rcmp.AttachTo { .target = parent_ety });
    reg.add(value_ety, gcmp.InitLayoutElement {
        .idx = 2,
        .width = gui_setup.SizeFieldValue.width,
        .height = gui_setup.SizeFieldValue.height,
    });
    reg.add(value_ety, gcmp.InitTextInput {
        .rect = gui_setup.SizeFieldValue,
        .bg_color = gui_setup.ColorLabelBg,
        .text_color = gui_setup.ColorLabelText,
        .text = value,
        .free_text = true,
    });
}

inline fn createField(
        reg: *ecs.Registry,
        parent_ety: ecs.Entity,
        comptime name: []const u8,
        comptime idx: i32,
        comptime offset: f32,
        comptime T: type,
        value: *T,
        allocator: std.mem.Allocator
    ) i32
{
    comptime var ret_idx = idx + 1;
    var field_ety = reg.create();
    reg.add(field_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(field_ety, rcmp.AttachTo { .target = parent_ety });
    reg.add(field_ety, gcmp.InitLayoutElement {
        .idx = idx,
        .width = gui_setup.SizePanelItem.width,
        .height = gui_setup.SizePanelItem.height,
    });
    reg.add(field_ety, gcmp.LinearLayout { .dir = gcmp.LayoutDirection.LEFT_RIGHT });

    var offset_ety = reg.create();
    reg.add(offset_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(offset_ety, rcmp.AttachTo { .target = field_ety });
    reg.add(offset_ety, gcmp.InitLayoutElement {
        .idx = 0,
        .width = offset,
        .height = 0,
    });

    var tile_ety = reg.create();
    reg.add(tile_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(tile_ety, rcmp.AttachTo { .target = field_ety });
    reg.add(tile_ety, gcmp.InitLayoutElement {
        .idx = 1,
        .width = gui_setup.SizeFieldTitle.width - offset,
        .height = gui_setup.SizeFieldTitle.height,
    });
    reg.add(tile_ety, rcmp.Text {
        .color = gui_setup.ColorLabelText,
        .size = gui_setup.SizeText,
        .text = name,
    });

    switch (@typeInfo(T)) {
        .Struct => |info| {
            inline for (info.fields) |field| {
                const field_offset = @offsetOf(T, field.name);
                const field_ptr: *field.type =
                    @ptrFromInt(@intFromPtr(value) + field_offset);
                ret_idx += createField(reg, parent_ety, field.name, ret_idx,
                    offset + gui_setup.SizeFieldOffset, field.type, field_ptr, allocator);
            }
        },
        .Pointer => |info| {
            switch (info.size) {
                .Slice => {
                    if (info.child == u8) {
                        const str_value = std.fmt.allocPrintZ(allocator, "{s}", .{value.*}) catch "<error>";
                        createFieldValue(reg, field_ety, str_value);
                    } else {
                        const str_value = std.fmt.allocPrintZ(allocator, "{any}", .{value.*}) catch "<error>";
                        createFieldValue(reg, field_ety, str_value);
                    }
                },
                else => {
                    const str_value = std.fmt.allocPrintZ(allocator, "{any}", .{value.*}) catch "<error>";
                    createFieldValue(reg, field_ety, str_value);
                }
            }
        },
        else => {
            const str_value = std.fmt.allocPrintZ(allocator, "{any}", .{value.*}) catch "<error>";
            createFieldValue(reg, field_ety, str_value);
        },
    }

    return ret_idx;
}

inline fn createBtn(reg: *ecs.Registry, parent_ety: ecs.Entity, idx: i32, text: []const u8) ecs.Entity {
    var close_ety = reg.create();
    reg.add(close_ety, rcmp.Position { .x = 0, .y = 0 });
    reg.add(close_ety, rcmp.AttachTo { .target = parent_ety });
    reg.add(close_ety, gcmp.InitLayoutElement {
        .idx = idx,
        .width = gui_setup.SizePanelItem.width + gui_setup.MarginPanelItem.w,
        .height = gui_setup.SizePanelItem.height + gui_setup.MarginPanelItem.h,
    });
    reg.add(close_ety, gcmp.InitButton {
        .color = gui_setup.ColorButton,
        .rect = gui_setup.SizePanelItem,
    });
    reg.add(close_ety, rcmp.Text {
        .color = gui_setup.ColorButtonText,
        .size = gui_setup.SizeText,
        .text = text,
    });

    return close_ety;
}

pub fn editComponentWindow(reg: *ecs.Registry, allocator: std.mem.Allocator) std.fmt.AllocPrintError!void {
    var init_view = reg.view(.{ cmp.EditComponentWindow }, .{ cmp.EditComponentWindowReady, rcmp.SolidRect });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const list_ety = reg.create();
        reg.add(list_ety, rcmp.Position { .x = 0, .y = 0 });
        reg.add(list_ety, rcmp.AttachTo { .target = entity });
        reg.add(list_ety, gcmp.LinearLayout {
            .dir = gcmp.LayoutDirection.TOP_DOWN,
        });

        reg.add(entity, rcmp.Scissor {
            .width = gui_setup.SizeWindow.width,
            .height = gui_setup.SizeWindow.height,
        });
        reg.add(entity, gcmp.InitScroll {
            .view_area = gui_setup.SizeWindow,
        });
        reg.add(entity, rcmp.SolidRect {
            .color = gui_setup.ColorPanel,
            .rect = gui_setup.SizeWindow,
        });

        reg.add(entity, cmp.EditComponentWindowReady {
            .list_entity = list_ety,
        });
    }

    var set_view = reg.view(.{ cmp.EditComponentWindowReady, cmp.SetEditingComponent }, .{ });
    var set_iter = set_view.entityIterator();
    while(set_iter.next()) |entity| {
        const ready = set_view.getConst(cmp.EditComponentWindowReady, entity);
        const set = set_view.getConst(cmp.SetEditingComponent, entity);
        if (reg.tryGet(cmp.EditingComponent, entity)) |editing_cmp| {
                editing_cmp.entity = set.entity;
                editing_cmp.component_idx = set.component_idx;
        } else {
            reg.add(entity, cmp.EditingComponent {
                .entity = set.entity,
                .component_idx = set.component_idx,
            });
        }

        if (reg.has(rcmp.Disabled, entity)) {
            reg.remove(rcmp.Disabled, entity);
        }

        if (reg.has(rcmp.Children, ready.list_entity)) {
            const children = reg.get(rcmp.Children, ready.list_entity);
            for (children.children.items) |child_ety| {
                if (!reg.has(ccmp.Destroyed, child_ety)) {
                    reg.add(child_ety, ccmp.Destroyed {});
                }
            }
        }

        if (reg.tryGet(rcmp.Position, ready.list_entity)) |list_pos| {
            list_pos.y = 0;
            if (!reg.has(rcmp.UpdateGlobalTransform, ready.list_entity)){
                reg.add(ready.list_entity, rcmp.UpdateGlobalTransform { });
            }
        }

        var last_field_idx: i32 = 0;
        inline for (scene_systems.scene_components, 0..) |ComponentT, cmp_idx| {
            if (cmp_idx == set.component_idx) {
                const comp_type = @typeInfo(ComponentT);
                inline while (comp_type.Struct.fields.len > 0) {
                    const component_value = reg.get(ComponentT, set.entity);
                    comptime var idx = 0;
                    inline for (comp_type.Struct.fields) |field| {
                        const field_offset = @offsetOf(ComponentT, field.name);
                        const field_ptr: *field.type =
                            @ptrFromInt(@intFromPtr(component_value) + field_offset);
                        idx += createField(reg, ready.list_entity, field.name,
                            idx, 0, field.type, field_ptr, allocator);
                    }
                    last_field_idx = idx;
                    break;
                }
                break;
            }
        }

        var close_ety = createBtn(reg, ready.list_entity, last_field_idx, "close");
        reg.add(close_ety, cmp.ConfirmEditComponentButton { .window_entity = entity });

        reg.remove(cmp.SetEditingComponent, entity);
    }

    var close_view = reg.view(.{ gcmp.ButtonClick, cmp.ConfirmEditComponentButton }, .{});
    var close_iter = close_view.entityIterator();
    while (close_iter.next()) |entity| {
        const btn = close_view.getConst(cmp.ConfirmEditComponentButton, entity);
        if (!reg.has(rcmp.Disabled, btn.window_entity)) {
            reg.add(btn.window_entity, rcmp.Disabled {});
        }

        if (reg.has(cmp.EditingComponent, btn.window_entity)) {
            reg.remove(cmp.EditingComponent, btn.window_entity);
        }
    }
}

pub fn componentPanel(reg: *ecs.Registry) void {
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

pub fn gameObjectPanel(reg: *ecs.Registry, allocator: std.mem.Allocator) error { OutOfMemory }!void {
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

pub fn gameObjectPanelOnDestroy(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.ListedEditorObject, cmp.EditorObject, ccmp.Destroyed }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var listed = view.getConst(cmp.ListedEditorObject, entity);

        reg.add(listed.button_entity, ccmp.DestroyNextFrame {});
    }
}

pub fn componentInstancePanel(reg: *ecs.Registry) void {
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
                    if (reg.tryGetConst(cmp.ComponentInstanceButton, btn_entity)) |inst_btn| {
                        if (inst_btn.entity == unselected_entity) {
                            reg.add(btn_entity, ccmp.Destroyed {});
                        }
                    }
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
                    reg.add(btn_entity, cmp.ComponentInstanceButton {
                        .entity = selected_entity,
                        .component_idx = idx
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

    var click_view = reg.view(.{ gcmp.ButtonClick, cmp.ComponentInstanceButton }, .{});
    var click_iter = click_view.entityIterator();
    while(click_iter.next()) |entity| {
        const btn = click_view.getConst(cmp.ComponentInstanceButton, entity);

        var wnd_view = reg.view(.{ cmp.EditComponentWindowReady }, .{ cmp.SetEditingComponent });
        var wnd_iter = wnd_view.entityIterator();
        while (wnd_iter.next()) |wnd_entity| {
            reg.add(wnd_entity, cmp.SetEditingComponent {
                .entity = btn.entity,
                .component_idx = btn.component_idx,
            });
            break;
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