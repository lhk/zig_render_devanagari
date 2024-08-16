const std = @import("std");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const font_assets = @import("font-assets");

const rl = @import("raylib");
const rg = @import("raygui");

pub fn main() !void {
    const screenWidth = 400;
    const screenHeight = 200;
    rl.initWindow(screenWidth, screenHeight, "devanagari text");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(1); // Set our game to run at 60 frames-per-second

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     _ = gpa.deinit();
    // }
    const allocator = std.heap.c_allocator;

    const lib = try freetype.Library.init();
    defer lib.deinit();

    const text = "मेरा नाम लार्स है";
    //const text = "मेर";

    // set up harfbuzz buffer, feed it the Devanagari text
    var hb_buffer = harfbuzz.Buffer.init() orelse return;
    hb_buffer.setDirection(harfbuzz.Direction.ltr);
    hb_buffer.setScript(harfbuzz.Script.devanagari);
    hb_buffer.addUTF8(text, 0, text.len);

    // set up freetype face, convert to harfbuzz face, and shape the buffer
    const ft_face = try lib.createFaceMemory(@embedFile("NotoSerifDevanagari_Condensed-Bold.ttf"), 0);
    try ft_face.setCharSize(100 * 50, 0, 50, 0);
    const hb_face = harfbuzz.Face.fromFreetypeFace(ft_face);
    const hb_font = harfbuzz.Font.init(hb_face);
    hb_font.shape(hb_buffer, null);

    // glyph infos and positions, that's what we need to render the text
    const glyphInfos = hb_buffer.getGlyphInfos();
    const glyphPositions = hb_buffer.getGlyphPositions() orelse return;

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        for (glyphInfos, glyphPositions) |info, pos| {
            // this output looks ok-ish
            // except that the offsets and advances in pos are quite large
            // it's not clear to me how to interpret them
            std.debug.print("codepoint: {d}\n", .{info.codepoint});
            std.debug.print("{any}\n", .{pos});

            // get a bitmap for the current glyph
            try ft_face.loadGlyph(info.codepoint, .{ .render = true });
            const glyph = ft_face.glyph();
            const bm = glyph.bitmap();

            std.debug.print("bitmap: {d}x{d}\n", .{ bm.width(), bm.rows() });

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
            // but: If I don't use the c_allocator, I get a "pointer wasn't allocated" error
            // so I guess raylib is trying to free this buffer and if it was allocated with a different buffer, then it fails to do so
            //defer allocator.free(bitmapBuffer);
            image.data = bitmapBuffer.ptr;

            // by default it's white text on black background
            // I'd like to draw black on white
            image.invert();

            // to draw, we need to convert the image into a texture
            const texture: rl.Texture2D = rl.loadTextureFromImage(image);
            const center_x = 200;
            const center_y = 100;
            // ToDo: the positioning is off
            // the offsets are much too large, and I've not yet figured out what to do with pos.advance
            rl.drawTexture(texture, center_x + pos.x_offset, center_y + pos.y_offset, rl.Color.white);
        }
    }
}
