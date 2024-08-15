const std = @import("std");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const font_assets = @import("font-assets");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();

    const lib = try freetype.Library.init();
    defer lib.deinit();

    //const face = try lib.createFaceMemory(font_assets.fira_sans_regular_ttf, 0);
    const face = try lib.createFaceMemory(@embedFile("NotoSerifDevanagari_Condensed-Bold.ttf"), 0);
    try face.setCharSize(100 * 50, 0, 50, 0);

    //try face.loadChar('A', .{ .render = true });
    try face.loadChar('आ', .{ .render = true });
    const bitmap = face.glyph().bitmap();

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
}
