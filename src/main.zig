const std = @import("std");
const w4 = @import("wasm4.zig");

const Global = struct {
    volume: u32 = 25,
    frame: u32 = 0,
};

var global = Global{};

export fn start() void {
    w4.PALETTE.* = .{
        0x000022,
        0xbbeebb,
        0xdd9911,
        0xaa1166,
    };
}

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

fn drawPixel(x: i32, y: i32) void {
    const idx = (@intCast(usize, y) * 160 + @intCast(usize, x)) >> 2;
    const shift = @intCast(u3, (x & 0b11) * 2);
    const mask = @as(u8, 0b11) << shift;
    const palette_color = @intCast(u8, w4.DRAW_COLORS.* & 0b1111);
    if (palette_color == 0) return;
    const color = (palette_color - 1) & 0b11;
    w4.FRAMEBUFFER[idx] = (color << shift) | (w4.FRAMEBUFFER[idx] & ~mask);
}

fn drawInt(value: anytype, x: i32, y: i32, len: comptime_int) void {
    var buffer: [len]u8 = undefined;
    w4.text(std.fmt.bufPrintIntToSlice(buffer[0..], value, 10, .lower, .{}), x, y);
}

fn toneFrequency(freq1: u32, freq2: u32) u32 {
    return freq1 | (freq2 << 16);
}

fn toneDuration(attack: u32, decay: u32, sustain: u32, release: u32) u32 {
    return (attack << 24) | (decay << 16) | sustain | (release << 8);
}

fn toneVolume(peak: u32, volume: u32) u32 {
    return (peak << 8) | volume;
}

export fn update() void {
    global.frame += 1;

    w4.DRAW_COLORS.* = 2;
    w4.text("color 2", 10, 10);
    w4.DRAW_COLORS.* = 3;
    w4.text("color 3", 10, 20);
    w4.DRAW_COLORS.* = 4;
    w4.text("color 4", 10, 30);

    w4.DRAW_COLORS.* = 2;
    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 3;
        w4.tone(262, 60, global.volume, w4.TONE_PULSE1 | w4.TONE_PAN_RIGHT);
    }
    if (gamepad & w4.BUTTON_2 != 0) {
        w4.DRAW_COLORS.* = 4;
        w4.tone(262, 60, global.volume, w4.TONE_PULSE1 | w4.TONE_MODE3 | w4.TONE_PAN_LEFT);
    }

    w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    w4.text("Press \x80\x81 to blink", 10, 90);
    w4.text("\x84\x85\x86\x87", 10, 100);

    drawPixel(150, 10);
    drawInt(global.frame, 10, 110, 12);

    const mouse = w4.MOUSE_BUTTONS.*;
    const mouseX = w4.MOUSE_X.*;
    const mouseY = w4.MOUSE_Y.*;

    if (mouse & w4.MOUSE_LEFT != 0) {
        w4.DRAW_COLORS.* = 3;
        w4.tone(toneFrequency(262, 523), 60, global.volume, w4.TONE_PULSE1);
    }
    if (mouse & w4.MOUSE_RIGHT != 0) {
        w4.DRAW_COLORS.* = 4;
    }
    w4.rect(mouseX - 4, mouseY - 4, 8, 8);
}
