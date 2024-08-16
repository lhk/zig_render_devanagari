const std = @import("std");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const font_assets = @import("font-assets");

const rl = @import("raylib");
const rg = @import("raygui");

pub fn main() !void {
    // raylib setup
    const screenWidth = 800;
    const screenHeight = 400;
    rl.initWindow(screenWidth, screenHeight, "devanagari text");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Normally I use the GPA allocator, but it seems incompatible with raylib.
    // See further below for a comment on this issue.
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     _ = gpa.deinit();
    // }
    const allocator = std.heap.c_allocator;

    const text = "मेरा नाम लार्स है";
    //const text = "मेर";

    // set up harfbuzz buffer, feed it the Devanagari text
    var hb_buffer = harfbuzz.Buffer.init() orelse return;
    hb_buffer.setDirection(harfbuzz.Direction.ltr);
    hb_buffer.setScript(harfbuzz.Script.devanagari);
    hb_buffer.addUTF8(text, 0, text.len);

    // set up freetype face, convert to harfbuzz face, and shape the buffer
    const lib = try freetype.Library.init();
    defer lib.deinit();
    const ft_face = try lib.createFaceMemory(@embedFile("NotoSerifDevanagari_Condensed-Bold.ttf"), 0);

    // ToDo: understand these magic numbers
    try ft_face.setCharSize(0, 5000, 9, 35);

    const hb_face = harfbuzz.Face.fromFreetypeFace(ft_face);
    const hb_font = harfbuzz.Font.init(hb_face);
    hb_font.shape(hb_buffer, null);

    // glyph infos and positions, that's what we need to render the text
    const glyphInfos = hb_buffer.getGlyphInfos();
    const glyphPositions = hb_buffer.getGlyphPositions() orelse return;

    var textureHashMap = std.hash_map.AutoHashMap(u32, rl.Texture2D).init(std.heap.page_allocator);
    defer textureHashMap.deinit();

    while (!rl.windowShouldClose()) {

        // some raylib boilerplate
        // the blendMode is important:
        // harfbuzz and freetype ultimately give me bitmaps and positions
        // the positions overlap
        // if I'm drawing white text on a black background, then I can just use blend_additive to draw the glyphs
        // ultimately I would like to get black text on white background, but I think that will require a more complex setup
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);
        rl.beginBlendMode(rl.BlendMode.blend_additive);
        defer rl.endBlendMode();

        // start position for the text
        const b = rl.Vector2{ .x = 100, .y = 100 };
        var p = b;

        for (glyphInfos, glyphPositions) |info, pos| {
            std.debug.print("codepoint: {d}\n", .{info.codepoint});
            std.debug.print("{any}\n", .{pos});

            // get a bitmap for the current glyph
            // we need the glyph for the metrics, not just for the bitmap
            try ft_face.loadGlyph(info.codepoint, .{ .render = true });
            const glyph = ft_face.glyph();
            const bm = glyph.bitmap();
            std.debug.print("bitmap: {d}x{d}\n", .{ bm.width(), bm.rows() });

            const maybeTexture = textureHashMap.get(info.codepoint);
            var texture: rl.Texture2D = undefined;
            if (maybeTexture == null) {

                // create an image from the bitmap data
                // this block is raylib specific
                var image: rl.Image = undefined;
                image.width = @intCast(bm.width());
                image.height = @intCast(bm.rows());
                image.mipmaps = 1;
                image.format = rl.PixelFormat.pixelformat_uncompressed_grayscale;

                // Do I need to create this copy?
                // using the bitmap data directly requires a @constCast(bm.buffer().?.ptr) which looks like it can't possibly be correct.
                const buffer = bm.buffer();
                if (buffer == null) {
                    continue;
                }
                const bitmapBuffer = try allocator.dupe(u8, buffer.?);

                // quite strange: If I uncomment this line, I get a double free error
                // does raylib free some texture buffer itself?
                // I'm not using raylib unloadImage or unloadTexture
                // to me this looks like a big memory leak
                // but: If I don't use the c_allocator, I get a "freed pointer wasn't allocated" error
                // so I guess raylib is trying to free this buffer and if it was allocated with a different allocator, then it fails to do so
                //defer allocator.free(bitmapBuffer);
                image.data = bitmapBuffer.ptr;
                defer rl.unloadImage(image);

                // to draw, we need to convert the image into a texture
                texture = rl.loadTextureFromImage(image);
                try textureHashMap.put(info.codepoint, texture);
            } else {
                texture = maybeTexture.?;
            }

            const xa = @as(f32, @floatFromInt(pos.x_advance)) / 64;
            const ya = @as(f32, @floatFromInt(pos.y_advance)) / 64;
            const xo = @as(f32, @floatFromInt(pos.x_offset)) / 64;
            const yo = @as(f32, @floatFromInt(pos.y_offset)) / 64;

            const metrics = glyph.metrics();
            const bearing_x = @as(f32, @floatFromInt(metrics.horiBearingX)) / 64;
            const bearing_y = -@as(f32, @floatFromInt(metrics.horiBearingY)) / 64;
            const x0 = p.x + xo + bearing_x;
            const y0 = @floor(p.y + yo + bearing_y);

            const p0 = rl.Vector2{ .x = x0, .y = y0 };
            rl.drawTextureEx(texture, b.add(p0), 0, 1, rl.Color.white);
            p = p.add(rl.Vector2{ .x = xa, .y = ya });
        }
    }
}
