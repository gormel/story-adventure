const std = @import("std");
const rl = @import("raylib");
const assets = @import("assets");
const sp = @import("sprite.zig");

pub const Error = error {
    AssetFileNotFound,
    UnknownTextureFormat,
    SpriteNotFound,
};

pub const Resources = struct {
    const Atlas = struct {
        cfg: std.json.Parsed(sp.AtlasCfg),
        img: rl.Image,
        tex: rl.Texture2D,
    };

    fonts: std.StringHashMap(std.AutoHashMap(i32, rl.Font)),
    atlases: std.StringHashMap(Atlas),
    assets: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Resources {
        var assetmap = std.StringHashMap([]const u8).init(allocator);
        for (assets.filenames, 0..) |fname, i| {
            try assetmap.put(fname, assets.filedatas[i]);
        }

        return Resources {
            .allocator = allocator,
            .atlases = std.StringHashMap(Atlas).init(allocator),
            .assets = assetmap,
            .fonts = std.StringHashMap(std.AutoHashMap(i32, rl.Font)).init(allocator),
        };
    }

    fn getAssetData(self: *Resources, asset_path: []const u8) ![]const u8 {
        const normalized_asset_path = try self.allocator.dupe(u8, asset_path);
        defer self.allocator.free(normalized_asset_path);
        
        if (std.fs.path.sep == '/') {
            std.mem.replaceScalar(u8, normalized_asset_path, '\\', std.fs.path.sep);
        } else if (std.fs.path.sep == '\\') {
            std.mem.replaceScalar(u8, normalized_asset_path, '/', std.fs.path.sep);
        }

        if (self.assets.get(normalized_asset_path)) |assetdata| {
            return assetdata;
        }

        const err = std.io.getStdErr().writer();
        try err.print("ERROR: Asset \"{s}\" not found.\n", .{ normalized_asset_path });
        return Error.AssetFileNotFound;
    }

    pub fn loadFont(self: *Resources, font_path: []const u8, font_size: i32) !rl.Font {
        if (self.fonts.get(font_path)) |size_map| {
            if (size_map.get(font_size)) |font| {
                return font;
            }
        }
            
        const ext = std.fs.path.extension(font_path);
        const extz = try self.allocator.dupeZ(u8, ext);
        defer self.allocator.free(extz);
        
        const font_data = try self.getAssetData(font_path);
        const font = try rl.loadFontFromMemory(extz, font_data, font_size, null);

        if (self.fonts.getPtr(font_path)) |size_map| {
            try size_map.put(font_size, font);
            return font;
        }

        var size_map = std.AutoHashMap(i32, rl.Font).init(self.allocator);
        try self.fonts.put(font_path, size_map);
        try size_map.put(font_size, font);
        return font;
    }

    fn getAtlas(self: *Resources, atlas_path: []const u8) !Atlas {
        var atlas = self.atlases.get(atlas_path);
        if (atlas == null) {
            const text = try self.getAssetData(atlas_path);
            const json = try std.json.parseFromSlice(sp.AtlasCfg, self.allocator, text, .{ .ignore_unknown_fields = true });

            const tex_path = json.value.tex;
            const ext = std.fs.path.extension(tex_path);
            const extz = try self.allocator.dupeZ(u8, ext);
            defer self.allocator.free(extz);
            const img_data = try self.getAssetData(tex_path);
            const img = try rl.loadImageFromMemory(extz, img_data);
            const tex = try rl.loadTextureFromImage(img);
            
            atlas = Atlas {
                .cfg = json,
                .img = img,
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

        const err = std.io.getStdErr().writer();
        try err.print("ERROR: Cannot load sprite \"{s}\" from atlas \"{s}\"\n", .{ sprite_name, atlas_path });
        return Error.SpriteNotFound;
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
        const atlas_it = self.atlases.iterator();
        while (atlas_it.next()) |kv| {
            rl.unloadTexture(kv.value_ptr.tex);
            rl.unloadImage(kv.value_ptr.img);
            kv.value_ptr.cfg.deinit();
        }

        const font_it = self.fonts.iterator();
        while (font_it.next()) |path_kv| {
            const size_it = path_kv.value_ptr.iterator();
            while (size_it.next()) |font_kv| {
                rl.unloadFont(font_kv.value_ptr.*);
            }
            path_kv.value_ptr.deinit();
        }

        self.atlases.deinit();
        self.assets.deinit();
        self.fonts.deinit();
    }
};