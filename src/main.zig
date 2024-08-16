const std = @import("std");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const font_assets = @import("font-assets");

const rl = @import("raylib");
const rg = @import("raygui");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 200;
    const screenHeight = 100;

    rl.initWindow(screenWidth, screenHeight, "devanagari text");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    const lib = try freetype.Library.init();
    defer lib.deinit();

    //const ft_face = try lib.createFaceMemory(font_assets.fira_sans_regular_ttf, 0);

    const text = "मेरा नाम लार्स है";

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

    for (glyphInfos, glyphPositions) |info, pos| {
        std.debug.print("codepoint: {d}\n", .{info.codepoint});
        std.debug.print("{any}\n", .{pos});
        try ft_face.loadGlyph(info.codepoint, .{ .render = true });
    }

    //try ft_face.loadChar('A', .{ .render = true });
    try ft_face.loadChar('आ', .{ .render = true });
    var bitmap = ft_face.glyph().bitmap();

    std.debug.print("bitmap width: {d}\n", .{bitmap.width()});
    std.debug.print("bitmap rows: {d}\n", .{bitmap.rows()});

    var i: usize = 0;
    while (i < bitmap.rows()) : (i += 1) {
        var j: usize = 0;
        while (j < bitmap.width()) : (j += 1) {
            const char: u8 = switch (bitmap.buffer().?[i * bitmap.width() + j]) {
                0 => ' ',
                1...128 => ';',
                else => '#',
            };
            std.debug.print("{c}", .{char});
        }
        std.debug.print("\n", .{});
    }

    // Create an image from the bitmap data
    var image: rl.Image = undefined;
    image.width = 50;
    image.height = 36;
    image.mipmaps = 1;
    image.format = rl.PixelFormat.pixelformat_uncompressed_grayscale;
    // const ptr: *anyopaque = bitmap.buffer().?.ptr;
    image.data = @constCast(bitmap.buffer().?.ptr);

    // Load the image into a texture
    const texture: rl.Texture2D = rl.loadTextureFromImage(image);

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------

        // Draw

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);

        rl.drawTexture(texture, 50, 25, rl.Color.white);
    }
}
