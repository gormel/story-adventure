const std = @import("std");
const rl = @import("raylib");
const sp = @import("sprite.zig");

pub const Resources = struct {
    const Atlas = struct {
        cfg: std.json.Parsed(sp.AtlasCfg),
        tex: rl.Texture2D,
    };

    atlases: std.StringHashMap(Atlas),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Resources {
        return Resources {
            .allocator = allocator,
            .atlases = std.StringHashMap(Atlas).init(allocator)
        };
    }
    
    pub fn load_sprite(self: *Resources, atlas_path: []const u8, sprite_name: []const u8) !sp.Sprite {
        var atlas = self.atlases.get(atlas_path);
        if (atlas == null) {
            const exe_dir = try std.fs.selfExeDirPathAlloc(self.allocator);
            defer self.allocator.free(exe_dir);
            const absolute_atlas_path = try std.fs.path.join(self.allocator, &.{ exe_dir, atlas_path });
            defer self.allocator.free(absolute_atlas_path);

            const file = try std.fs.openFileAbsolute(absolute_atlas_path, .{});
            const text = try file.readToEndAlloc(self.allocator, 1024 * 5);
            defer self.allocator.free(text);
            const json = try std.json.parseFromSlice(sp.AtlasCfg, self.allocator, text, .{});

            const absolute_tex_path = try self.allocator.dupeZ(u8, try std.fs.path.join(self.allocator, &.{ exe_dir, json.value.tex }));
            defer self.allocator.free(absolute_tex_path);
            const tex = rl.LoadTexture(absolute_tex_path.ptr);
            atlas = Atlas {
                .cfg = json,
                .tex = tex,
            };
            try self.atlases.put(atlas_path, atlas.?);
        }

        const ok_atlas = atlas.?;
        for (ok_atlas.cfg.value.sprites) | sprite_cfg | {
            if (std.mem.eql(u8, sprite_cfg.name, sprite_name)) {
                return sp.Sprite {
                    .tex = ok_atlas.tex,
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

    pub fn deinit(self: *Resources) void {
        const it = self.atlases.iterator();
        while (it.next()) | pair | {
            rl.UnloadTexture(pair.value_ptr.tex);
            pair.value_ptr.cfg.deinit();
        }
        self.atlases.deinit();
    }
};

test "resource allocations" {
    const except = std.testing.expect;
    const allocator = std.testing.allocator;
    
    var res = Resources.init(allocator);
    defer res.deinit();

    const path = try std.fs.path.join(allocator, &.{ "resources", "atlases", "star.json" });
    _ = res.load_sprite(path, "star");
    except(false);
}