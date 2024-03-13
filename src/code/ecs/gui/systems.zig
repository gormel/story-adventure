const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const icmp = @import("../input/components.zig");
const ccmp = @import("../core/components.zig");

const BTN_CLICK_MUL = 0.8;

pub fn button(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ cmp.InitButton }, .{ cmp.Button });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = init_view.getConst(cmp.InitButton, entity);

        reg.add(entity, cmp.Button { .color = init.color });
        reg.add(entity, rcmp.SolidRect {
            .rect = init.rect,
            .color = init.color,
        });
        reg.add(entity, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
        reg.add(entity, icmp.MouseOverTracker { .rect = init.rect });
        reg.add(entity, icmp.MousePositionTracker {});

        reg.remove(cmp.InitButton, entity);
    }

    var clear_pressed_view = reg.view(.{ cmp.ButtonClick }, .{});
    var clear_pressed_iter = clear_pressed_view.entityIterator();
    while (clear_pressed_iter.next()) |entity| {
        reg.remove(cmp.ButtonClick, entity);
    }

    var pressed_view = reg.view(.{ cmp.Button, icmp.MouseOver, icmp.InputPressed }, .{ rcmp.SetSolidRectColor });
    var pressed_iter = pressed_view.entityIterator();
    while (pressed_iter.next()) |entity| {
        const btn = pressed_view.getConst(cmp.Button, entity);
        reg.add(entity, rcmp.SetSolidRectColor {
            .color = .{ 
                .r = @intFromFloat(@as(f32, @floatFromInt(btn.color.r)) * BTN_CLICK_MUL),
                .g = @intFromFloat(@as(f32, @floatFromInt(btn.color.g)) * BTN_CLICK_MUL),
                .b = @intFromFloat(@as(f32, @floatFromInt(btn.color.b)) * BTN_CLICK_MUL),
                .a = btn.color.a,
            }
        });
    }

    var released_view = reg.view(.{ cmp.Button, icmp.InputReleased }, .{ rcmp.SetSolidRectColor });
    var released_iter = released_view.entityIterator();
    while (released_iter.next()) |entity| {
        const btn = pressed_view.getConst(cmp.Button, entity);
        reg.add(entity, rcmp.SetSolidRectColor {
            .color = .{ .r = btn.color.r, .g = btn.color.g, .b = btn.color.b, .a = btn.color.a }
        });

        if (reg.has(icmp.MouseOver, entity)) {
            reg.add(entity, cmp.ButtonClick {});
        }
    }
}

pub const ChildEntry = struct { ety: ecs.Entity, idx: i32 };
fn compare_entry(_: void, a: ChildEntry, b: ChildEntry) bool {
    switch (std.math.clamp(b.idx - a.idx, -1, 1)) {
        -1 => return false,
         0 => return false,
         1 => return true,
         else => unreachable()
    }

    unreachable();
}

pub fn linear_layout(reg: *ecs.Registry, children_buffer: *std.ArrayList(ChildEntry)) !void {
    var init_view = reg.view(.{ cmp.InitLayoutElement, rcmp.Parent }, .{ cmp.LayoutElement });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const parent = init_view.getConst(rcmp.Parent, entity);

        if (reg.has(cmp.LinearLayout, parent.entity)) {
            const init = init_view.getConst(cmp.InitLayoutElement, entity);

            reg.add(entity, cmp.LayoutElement {
                .width = init.width,
                .height = init.height,
                .idx = init.idx,
            });

            if (!reg.has(cmp.RefreshLinearLayout, parent.entity)) {
                reg.add(parent.entity, cmp.RefreshLinearLayout {});
            }
        }

        reg.remove(cmp.InitLayoutElement, entity);
    }

    var refresh_view = reg.view(.{ cmp.RefreshLinearLayout, cmp.LinearLayout, rcmp.Children }, .{});
    var refresh_iter = refresh_view.entityIterator();
    while (refresh_iter.next()) |entity| {
        var layout = refresh_view.get(cmp.LinearLayout, entity);
        const children = refresh_view.getConst(rcmp.Children, entity);
        var last_idx = layout.size;

        children_buffer.clearRetainingCapacity();
        for (children.children.items) |child_entity| {
            if (!reg.has(cmp.Collapsed, child_entity)) {
                if (reg.tryGet(cmp.LayoutElement, child_entity)) |element| {
                    if (element.idx == -1) {
                        element.idx = last_idx;
                        last_idx += 1;
                    }

                    try children_buffer.append(ChildEntry {
                        .idx = element.idx,
                        .ety = child_entity
                    });
                }
            }
        }

        var offset: f32 = 0.0;
        std.sort.pdq(ChildEntry, children_buffer.items, {}, compare_entry);
        for (children_buffer.items) |entry| {
            if (!reg.has(rcmp.Position, entry.ety)) {
                reg.add(entry.ety, rcmp.Position { .x = 0, .y = 0 });
            }

            var position = reg.get(rcmp.Position, entry.ety);
            if (reg.tryGetConst(cmp.LayoutElement, entry.ety)) |element| {
                switch (layout.dir) {
                    .TOP_DOWN => {
                        position.x = 0;
                        position.y = offset;
                        offset += element.height;
                    },
                    .LEFT_RIGHT => {
                        position.x = offset;
                        position.y = 0;
                        offset += element.height;
                    },
                    .DOWN_TOP => {
                        position.x = 0;
                        position.y = offset;
                        offset -= element.height;
                    },
                    .RIGHT_LEFT => {
                        position.x = offset;
                        position.y = 0;
                        offset -= element.height;
                    }
                }

                if (!reg.has(rcmp.UpdateGlobalTransform, entry.ety)) {
                    reg.add(entry.ety, rcmp.UpdateGlobalTransform {});
                }
            }
        }

        layout.size = last_idx;
        reg.remove(cmp.RefreshLinearLayout, entity);
    }
}

pub fn linear_layout_on_destroy(reg: *ecs.Registry) void {
    var del_view = reg.view(.{ ccmp.Destroyed, cmp.LayoutElement, rcmp.Parent }, .{});
    var del_iter = del_view.entityIterator();
    while (del_iter.next()) |entity| {
        const parent = del_view.getConst(rcmp.Parent, entity);
        if (!reg.has(cmp.RefreshLinearLayout, parent.entity)) {
            reg.add(parent.entity, cmp.RefreshLinearLayout {});
        }
    }
}

pub fn process_scroll(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ cmp.InitScroll, rcmp.Children }, .{ cmp.Scroll });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = init_view.getConst(cmp.InitScroll, entity);

        reg.add(entity, cmp.Scroll {
            .view_area = init.view_area,
            .dir = init.dir,
            .speed = init.speed,
        });

        reg.add(entity, icmp.MouseOverTracker { .rect = init.view_area });
        reg.add(entity, icmp.MouseWheelTracker { });
        reg.add(entity, icmp.MousePositionTracker {});

        reg.remove(cmp.InitScroll, entity);
    }

    var process_view = reg.view(.{ cmp.Scroll, icmp.InputWheel, rcmp.Children, icmp.MouseOver }, .{});
    var process_iter = process_view.entityIterator();
    while (process_iter.next()) |entity| {
        const scroll = process_view.getConst(cmp.Scroll, entity);
        const input = process_view.getConst(icmp.InputWheel, entity);
        const children = process_view.getConst(rcmp.Children, entity);

        if (children.children.getLastOrNull()) |content_entity| {
            if (!reg.has(rcmp.Position, content_entity)) {
                reg.add(content_entity, rcmp.Position { .x = 0, .y = 0 });
            }

            var pos = reg.get(rcmp.Position, content_entity);
            pos.y += -scroll.speed * input.delta;

            if (!reg.has(rcmp.UpdateGlobalTransform, content_entity)) {
                reg.add(content_entity, rcmp.UpdateGlobalTransform {});
            }
        }
    }
}