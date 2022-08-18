const std = @import("std");
const w4 = @import("wasm4.zig");

const Options = struct {
    volume: u32 = 25,
};

const Gamepad = struct {
    down: u8 = 0,
    pressed: u8 = 0,
    released: u8 = 0,
    prev: u8 = 0,

    fn update(self: *@This(), down: u8) void {
        self.pressed = down & (down ^ self.prev);
        self.released = self.prev & (down ^ self.prev);
        self.prev = self.down;
        self.down = down;
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
    pos: Point(f64) = .{ .x = 50, .y = 30 },
    move_dir: Point(f64) = .{},
    move_speed: f64 = 2,

    fn update(self: *@This()) void {
        if (!gamepad.isDown(w4.BUTTON_LEFT) and !gamepad.isDown(w4.BUTTON_RIGHT)) {
            self.move_dir.x = 0;
        } else {
            if (gamepad.isPressed(w4.BUTTON_LEFT) or gamepad.isReleased(w4.BUTTON_RIGHT)) self.move_dir.x = -1;
            if (gamepad.isPressed(w4.BUTTON_RIGHT) or gamepad.isReleased(w4.BUTTON_LEFT)) self.move_dir.x = 1;
        }
        if (!gamepad.isDown(w4.BUTTON_UP) and !gamepad.isDown(w4.BUTTON_DOWN)) {
            self.move_dir.y = 0;
        } else {
            if (gamepad.isPressed(w4.BUTTON_UP) or gamepad.isReleased(w4.BUTTON_DOWN)) self.move_dir.y = -1;
            if (gamepad.isPressed(w4.BUTTON_DOWN) or gamepad.isReleased(w4.BUTTON_UP)) self.move_dir.y = 1;
        }
        self.move_dir.normalize();
        self.pos.x += self.move_dir.x * self.move_speed;
        self.pos.y += self.move_dir.y * self.move_speed;
    }

    fn draw(self: @This()) void {
        const x: i32 = @floatToInt(i32, std.math.round(self.pos.x));
        const y: i32 = @floatToInt(i32, std.math.round(self.pos.y));
        w4.DRAW_COLORS.* = 0x33;
        w4.oval(x - 4, y - 4, 9, 9);
        w4.DRAW_COLORS.* = 2;
        w4.rect(
            x + @floatToInt(i32, std.math.round(self.move_dir.x * 3)),
            y + @floatToInt(i32, std.math.round(self.move_dir.y * 3)),
            1,
            1,
        );
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

var options = Options{};
var gamepad = Gamepad{};
var player = Player{};

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
    gamepad.update(w4.GAMEPAD1.*);
    player.update();
    player.draw();
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
