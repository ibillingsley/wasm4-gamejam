const std = @import("std");
const w4 = @import("wasm4.zig");

const Gamepad = struct {
    ptr: *const u8,
    down: u8 = 0,
    prev: u8 = 0,
    pressed: u8 = 0,
    released: u8 = 0,
    axis: Point(f64) = .{},

    fn update(self: *@This()) void {
        self.prev = self.down;
        self.down = self.ptr.*;
        self.pressed = self.down & (self.down ^ self.prev);
        self.released = self.prev & (self.down ^ self.prev);

        if (!self.isDown(w4.BUTTON_LEFT) and !self.isDown(w4.BUTTON_RIGHT)) {
            self.axis.x = 0;
        } else {
            if (self.isPressed(w4.BUTTON_LEFT) or self.isReleased(w4.BUTTON_RIGHT)) self.axis.x = -1;
            if (self.isPressed(w4.BUTTON_RIGHT) or self.isReleased(w4.BUTTON_LEFT)) self.axis.x = 1;
        }
        if (!self.isDown(w4.BUTTON_UP) and !self.isDown(w4.BUTTON_DOWN)) {
            self.axis.y = 0;
        } else {
            if (self.isPressed(w4.BUTTON_UP) or self.isReleased(w4.BUTTON_DOWN)) self.axis.y = -1;
            if (self.isPressed(w4.BUTTON_DOWN) or self.isReleased(w4.BUTTON_UP)) self.axis.y = 1;
        }
    }

    fn isDown(self: @This(), button: u8) bool {
        return self.down & button != 0;
    }

    fn isPressed(self: @This(), button: u8) bool {
        return self.pressed & button != 0;
    }

    fn isReleased(self: @This(), button: u8) bool {
        return self.released & button != 0;
    }
};

const Player = struct {
    pos: Point(f64) = .{ .x = w4.SCREEN_SIZE / 2, .y = w4.SCREEN_SIZE / 2 + 15 },
    size: i32 = 9,
    move_speed: f64 = 2,
    move_dir: Point(f64) = .{},
    look_dir: Point(f64) = .{ .x = 0, .y = -1 },
    dodge_dir: Point(f64) = .{ .x = 0, .y = -1 },
    dodge_timer: i32 = dodge_min,
    attack_timer: i32 = attack_min,
    blocking: bool = false,

    const attack_min = -5;
    const dodge_min = -10;
    const pos_min = 4;
    const pos_max = @intToFloat(f64, w4.SCREEN_SIZE) - 5;

    fn update(self: *@This(), gamepad: Gamepad) void {
        // timers
        if (self.attack_timer > attack_min) self.attack_timer -= 1;
        if (self.dodge_timer > dodge_min) self.dodge_timer -= 1;
        // attack
        if (self.attack_timer <= attack_min and gamepad.isReleased(w4.BUTTON_2)) {
            self.attack_timer = 5;
            w4.tone(tFreq(150, 600), tDur(5, 0, 0, 0), sound_vol, w4.TONE_NOISE);
        }
        // direction
        self.move_dir = gamepad.axis;
        if (self.move_dir.x != 0 or self.move_dir.y != 0) {
            self.move_dir.normalize();
            if (self.dodge_timer <= 0) self.dodge_dir = self.move_dir;
            if (self.attack_timer <= 0 and !gamepad.isDown(w4.BUTTON_2)) self.look_dir = self.move_dir;
        }
        // dodge
        if (self.dodge_timer <= dodge_min and gamepad.isPressed(w4.BUTTON_1)) {
            self.dodge_timer = 15;
            w4.tone(tFreq(100, 280), tDur(2, 0, 0, 10), sound_vol, w4.TONE_PULSE1 | w4.TONE_MODE3);
        }
        // block
        self.blocking = self.attack_timer <= 0 and self.dodge_timer <= 0 and gamepad.isDown(w4.BUTTON_2);
        if (self.blocking and gamepad.isPressed(w4.BUTTON_2)) {
            w4.tone(tFreq(250, 200), tDur(3, 0, 0, 3), sound_vol / 2, w4.TONE_NOISE);
        }
        // movement
        const speed = if (self.dodge_timer > 0) @intToFloat(f64, self.dodge_timer) / 3.0 else self.move_speed;
        const dir = if (self.dodge_timer > 0) self.dodge_dir else self.move_dir;
        self.pos.x = std.math.clamp(self.pos.x + dir.x * speed, pos_min, pos_max);
        self.pos.y = std.math.clamp(self.pos.y + dir.y * speed, pos_min, pos_max);
    }

    fn draw(self: @This()) void {
        const x: i32 = round(i32, self.pos.x);
        const y: i32 = round(i32, self.pos.y);
        // attack
        if (self.attack_timer > 0) {
            w4.DRAW_COLORS.* = 0x22;
            drawCircle(x + round(i32, self.look_dir.x * 5), y + round(i32, self.look_dir.y * 5), 15);
            w4.DRAW_COLORS.* = 0x11;
            drawCircle(x, y, 15 - self.attack_timer);
        }
        // player
        w4.DRAW_COLORS.* = if (self.dodge_timer > 0) 0x31 else 0x33;
        drawCircle(x + round(i32, self.move_dir.x * -4), y + round(i32, self.move_dir.y * -4), 5);
        drawCircle(x, y, self.size);
        w4.DRAW_COLORS.* = 2;
        drawPixel(
            x + round(i32, self.look_dir.x * 3 + self.look_dir.y * 1.5),
            y + round(i32, self.look_dir.y * 3 - self.look_dir.x * 1.5),
        );
        drawPixel(
            x + round(i32, self.look_dir.x * 3 - self.look_dir.y * 1.5),
            y + round(i32, self.look_dir.y * 3 + self.look_dir.x * 1.5),
        );
        // block
        if (self.blocking) {
            w4.DRAW_COLORS.* = 2;
            w4.line(
                x + round(i32, self.look_dir.x * 5 - self.look_dir.y * 7),
                y + round(i32, self.look_dir.y * 5 + self.look_dir.x * 7),
                x + round(i32, self.look_dir.x * 5 + self.look_dir.y * 7),
                y + round(i32, self.look_dir.y * 5 - self.look_dir.x * 7),
            );
            w4.line(
                x + round(i32, self.look_dir.x * 6 - self.look_dir.y * 4),
                y + round(i32, self.look_dir.y * 6 + self.look_dir.x * 4),
                x + round(i32, self.look_dir.x * 6 + self.look_dir.y * 4),
                y + round(i32, self.look_dir.y * 6 - self.look_dir.x * 4),
            );
        }
    }
};

fn Point(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,

        fn normalize(self: *@This()) void {
            const len = std.math.sqrt(self.x * self.x + self.y * self.y);
            if (len > 0) {
                self.x /= len;
                self.y /= len;
            }
        }
    };
}

var frame_count: u32 = 0;
var sound_vol: u32 = 40;
var gamepad1 = Gamepad{ .ptr = w4.GAMEPAD1 };
var player1 = Player{};

const palette: [4]u32 = .{
    0x001111,
    0xdddd99,
    0x1166bb,
    0xbb1166,
};

export fn start() void {
    w4.PALETTE.* = palette;
}

export fn update() void {
    frame_count += 1;
    gamepad1.update();
    player1.update(gamepad1);
    player1.draw();
}

fn drawPixel(x: i32, y: i32) void {
    w4.rect(x, y, 1, 1);
}

fn drawCircle(x: i32, y: i32, size: i32) void {
    w4.oval(x - @divFloor(size, 2), y - @divFloor(size, 2), size, size);
}

fn tFreq(freq1: u32, freq2: u32) u32 {
    return freq1 | (freq2 << 16);
}

fn tDur(attack: u32, decay: u32, sustain: u32, release: u32) u32 {
    return (attack << 24) | (decay << 16) | sustain | (release << 8);
}

fn tVol(peak: u32, volume: u32) u32 {
    return (peak << 8) | volume;
}

fn round(comptime T: type, float: anytype) T {
    return @floatToInt(T, std.math.round(float));
}
