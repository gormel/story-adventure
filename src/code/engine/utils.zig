const std = @import("std");
const rl = @import("raylib");

pub const ParseError = error {
    ExpectedCloseBracket,
};

pub fn rotate(x: *f32, y: *f32, a: f32) void {
    const rad = std.math.degreesToRadians(-a);
    const cos = std.math.cos(rad);
    const sin = std.math.sin(rad);

    const _x = x.*;
    const _y = y.*;

    x.* = _x * cos + _y * sin;
    y.* = -_x * sin + _y * cos;
}

pub fn containsTag(tags: [][]const u8, tag: []const u8) bool {
    for (tags) |mb_tag| {
        if (std.mem.eql(u8, mb_tag, tag)) {
            return true;
        }
    }

    return false;
}

pub fn matchParams(allocator: std.mem.Allocator, template: []const u8, params: *const std.json.ArrayHashMap(f64)) ![:0]const u8 {
    const parse_state = enum { LOOK, COLLECT };
    var state: parse_state = .LOOK;
    var caret: usize = 0;
    var pieces = std.ArrayList([]const u8).init(allocator);
    defer pieces.deinit();
    var tofree = std.ArrayList([]const u8).init(allocator);
    defer tofree.deinit();
    while (true) {
        switch (state) {
            .LOOK => {
                if (std.mem.indexOfPos(u8, template, caret, "${")) |found_caret| {
                    try pieces.append(template[caret..found_caret]);
                    state = .COLLECT;
                    caret = found_caret + 2;
                } else {
                    if (caret < template.len) {
                        try pieces.append(template[caret..]);
                    }
                    break;
                }
            },
            .COLLECT => {
                if (std.mem.indexOfPos(u8, template, caret, "}")) |found_caret| {
                    const param = template[caret..found_caret];
                    if (params.map.get(param)) |pvalue| {
                        const strvalue = try std.fmt.allocPrint(allocator, "{d}", .{ pvalue });
                        try pieces.append(strvalue);
                        try tofree.append(strvalue);
                    } else {
                        const strvalue = try std.mem.concat(allocator, u8, &.{ "${", param, "}" });
                        try pieces.append(strvalue);
                        try tofree.append(strvalue);
                    }

                    state = .LOOK;
                    caret = found_caret + 1;
                } else {
                    return ParseError.ExpectedCloseBracket;
                }
            },
        }
    }

    const result = try std.mem.joinZ(allocator, "", pieces.items);

    for (tofree.items) |str| {
        allocator.free(str);
    }

    return result;
}