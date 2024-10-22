const std = @import("std");
const rl = @import("raylib");
const sp = @import("sprite.zig");

pub const Resources = struct {
    const Atlas = struct {
        cfg: std.json.Parsed(sp.AtlasCfg),
        tex: rl.Texture2D,
    };

    atlases: std.StringHashMap(Atlas),
    jsons: std.StringHashMap(std.json.Value),
    json_texts: std.ArrayList([]u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Resources {
        return Resources {
            .allocator = allocator,
            .atlases = std.StringHashMap(Atlas).init(allocator),
            .jsons = std.StringHashMap(std.json.Value).init(allocator),
            .json_texts = std.ArrayList([]u8).init(allocator),
        };
    }
    
    pub fn loadJson(self: *Resources, json_path: []const u8) !std.json.Value {
        if (self.jsons.get(json_path)) |json| {
            return json;
        } else {
            const exe_dir = try std.fs.selfExeDirPathAlloc(self.allocator);
            defer self.allocator.free(exe_dir);
            const absolute_json_path = try std.fs.path.join(self.allocator, &.{ exe_dir, json_path });
            defer self.allocator.free(absolute_json_path);

            const file = try std.fs.openFileAbsolute(absolute_json_path, .{});
            defer file.close();
            const text = try file.readToEndAlloc(self.allocator, 1024 * 1024 * 5);
            try self.json_texts.append(text);
            var scanner = std.json.Scanner.initCompleteInput(self.allocator, text);
            defer scanner.deinit();
            const json = try std.json.Value.jsonParse(self.allocator, &scanner, .{});

            try self.jsons.put(json_path, json);

            return json;
        }
        unreachable;
    }

    fn getAtlas(self: *Resources, atlas_path: []const u8) !Atlas {
        var atlas = self.atlases.get(atlas_path);
        if (atlas == null) {
            const exe_dir = try std.fs.selfExeDirPathAlloc(self.allocator);
            defer self.allocator.free(exe_dir);
            const absolute_atlas_path = try std.fs.path.join(self.allocator, &.{ exe_dir, atlas_path });
            defer self.allocator.free(absolute_atlas_path);

            const file = try std.fs.openFileAbsolute(absolute_atlas_path, .{});
            defer file.close();
            const text = try file.readToEndAlloc(self.allocator, 1024 * 1024 * 5);
            defer self.allocator.free(text);
            const json = try std.json.parseFromSlice(sp.AtlasCfg, self.allocator, text, .{ .ignore_unknown_fields = true });

            const absolute_tex_path = try self.allocator.dupeZ(u8, try std.fs.path.join(self.allocator, &.{ exe_dir, json.value.tex }));
            defer self.allocator.free(absolute_tex_path);
            const tex = rl.LoadTexture(absolute_tex_path.ptr);
            atlas = Atlas {
                .cfg = json,
                .tex = tex,
            };
            try self.atlases.put(atlas_path, atlas.?);
        }

        return atlas.?;
    }

    pub fn loadSprite(self: *Resources, atlas_path: []const u8, sprite_name: []const u8) !sp.Sprite {
        const atlas = try self.getAtlas(atlas_path);

        for (atlas.cfg.value.sprites) | sprite_cfg | {
            if (std.mem.eql(u8, sprite_cfg.name, sprite_name)) {
                return sp.Sprite {
                    .tex = atlas.tex,
                    .rect = rl.Rectangle {
                        .x = sprite_cfg.x,
                        .y = sprite_cfg.y,
                        .width = sprite_cfg.w,
                        .height = sprite_cfg.h,
                    }
                };
            }
        }
        unreachable;
    }

    pub fn loadFlipbook(self: *Resources, atlas_path: []const u8, flipbook_name: []const u8) !sp.Flipbook {
        const atlas = try self.getAtlas(atlas_path);

        for (atlas.cfg.value.animations) |flipbook_cfg| {
            if (std.mem.eql(u8, flipbook_cfg.name, flipbook_name)) {
                var frames = try self.allocator.alloc(rl.Rectangle, flipbook_cfg.frames.len);
                for (flipbook_cfg.frames, 0..) |frame_name, idx| {
                    const sprite = try self.loadSprite(atlas_path, frame_name);
                    frames[idx] = sprite.rect;
                }

                return sp.Flipbook {
                    .duration = flipbook_cfg.duration,
                    .tex = atlas.tex,
                    .frames = frames,
                    .allocator = self.allocator,
                };
            }
        }
        unreachable;
    }

    pub fn deinit(self: *Resources) void {
        const it = self.atlases.iterator();
        while (it.next()) | pair | {
            rl.UnloadTexture(pair.value_ptr.tex);
            pair.value_ptr.cfg.deinit();
        }
        self.atlases.deinit();

        self.jsons.deinit();

        for (self.json_texts.items) |str| {
            self.allocator.free(str);
        }
    }
};

test "resource allocations" {
    const except = std.testing.expect;
    const allocator = std.testing.allocator;
    
    var res = Resources.init(allocator);
    defer res.deinit();

    const path = try std.fs.path.join(allocator, &.{ "resources", "atlases", "star.json" });
    _ = res.loadSprite(path, "star");
    except(false);
}