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
    alive: bool = true,
    pos: Point(f64) = .{ .x = screen_size / 2, .y = screen_size / 2 + 15 },
    move_speed: f64 = 2,
    move_dir: Point(f64) = .{},
    look_dir: Point(f64) = .{ .x = 0, .y = -1 },
    dodge_dir: Point(f64) = .{ .x = 0, .y = -1 },
    dodge_timer: i32 = dodge_min,
    attack_timer: i32 = attack_min,
    blocking: bool = false,

    const attack_min = -5;
    const dodge_min = -10;
    const pos_min: f64 = 4;
    const pos_max: f64 = screen_size - 5;

    fn update(self: *@This(), gamepad: Gamepad) void {
        // timers
        if (self.attack_timer > attack_min) self.attack_timer -= 1;
        if (self.dodge_timer > dodge_min) self.dodge_timer -= 1;
        // attack
        if (self.attack_timer <= attack_min and gamepad.isReleased(w4.BUTTON_2)) {
            self.attack_timer = 5;
            sound(toneFreq(150, 600), toneDur(5, 0, 0, 0), sound_vol, w4.TONE_NOISE);
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
            sound(toneFreq(100, 280), toneDur(2, 0, 0, 10), sound_vol, w4.TONE_PULSE1 | w4.TONE_MODE3);
        }
        // block
        self.blocking = self.attack_timer <= 0 and self.dodge_timer <= 0 and gamepad.isDown(w4.BUTTON_2);
        if (self.blocking and gamepad.isPressed(w4.BUTTON_2)) {
            sound(toneFreq(250, 200), toneDur(3, 0, 0, 0), sound_vol * 0.6, w4.TONE_NOISE);
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
            drawCircle(x + round(i32, self.look_dir.x * 5), y + round(i32, self.look_dir.y * 5), 17);
            w4.DRAW_COLORS.* = 0x11;
            drawCircle(x, y, 15 - self.attack_timer);
        }
        // player
        w4.DRAW_COLORS.* = if (self.dodge_timer > 0) 0x31 else 0x33;
        drawCircle(x + round(i32, self.move_dir.x * -4), y + round(i32, self.move_dir.y * -4), 5);
        drawCircle(x, y, 9);
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

    fn collideBody(self: @This(), target: Point(f64), radius: f64) bool {
        if (!self.alive or self.dodge_timer > 0) return false;
        var diff = Point(f64){
            .x = self.pos.x - target.x,
            .y = self.pos.y - target.y,
        };
        return diff.length() < 4.5 + radius;
    }

    fn collideBlock(self: @This(), target: Point(f64), radius: f64) bool {
        if (!self.alive or !self.blocking) return false;
        var diff = Point(f64){
            .x = self.pos.x + self.look_dir.x * 2 - target.x,
            .y = self.pos.y + self.look_dir.y * 2 - target.y,
        };
        return diff.length() < (7.5 + radius) and
            diff.x * self.look_dir.x <= 0 and
            diff.y * self.look_dir.y <= 0;
    }

    fn collideAttack(self: @This(), target: Point(f64), radius: f64) bool {
        if (!self.alive or self.attack_timer <= 0) return false;
        var diff = Point(f64){
            .x = self.pos.x + self.look_dir.x * 5 - target.x,
            .y = self.pos.y + self.look_dir.y * 5 - target.y,
        };
        return diff.length() < 8.5 + radius;
    }

    fn kill(self: *@This()) void {
        self.alive = false;
        end_frame = frame_count;
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 25 }).show();
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 27, .timer = -3 }).show();
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 18, .timer = -8, .color = 0x20 }).show();
        sound(toneFreq(240, 20), toneDur(0, 0, 0, 60), sound_vol, w4.TONE_NOISE);
        sound(440, toneDur(50, 0, 50, 50), sound_vol, w4.TONE_TRIANGLE);
    }
};

const Spider = struct {
    id: usize,
    alive: bool = true,
    pos: Point(f64),
    speed: Point(f64) = .{},
    dir: Point(f64) = .{},
    target_offset: Point(f64),
    anim: f64 = 1,

    const accel = 0.05;
    const speed_max = 1.5;
    var buffer = std.BoundedArray(@This(), 100).init(0) catch unreachable;
    var closest: f64 = -1;

    fn init(id: usize) @This() {
        const x = rng.float(f64) * 100;
        const y = rng.float(f64) * 100;
        return .{
            .id = id,
            .pos = .{
                .x = if (x < 50) -50 - x else screen_size + 50 + x,
                .y = if (y < 50) -50 - y else screen_size + 50 + y,
            },
            .target_offset = .{
                .x = rng.float(f64) * 1.2 - 0.6,
                .y = rng.float(f64) * 1.2 - 0.6,
            },
        };
    }

    fn update(self: *@This(), player: *Player) void {
        // collision
        var target = Point(f64){
            .x = player.pos.x - self.pos.x,
            .y = player.pos.y - self.pos.y,
        };
        const distance = target.length();
        if (player.collideAttack(self.pos, 6)) {
            self.kill();
        } else if (player.collideBlock(self.pos, 2.5)) {
            const bump = std.math.max(11 - distance, 1.5);
            self.pos.x += player.look_dir.x * bump;
            self.pos.y += player.look_dir.y * bump;
            self.speed.x += player.look_dir.x * 0.6;
            self.speed.y += player.look_dir.y * 0.6;
            sound(500, toneDur(0, 0, 0, 3), sound_vol * 0.3, w4.TONE_NOISE);
        } else if (player.collideBody(self.pos, 2.5)) {
            player.kill();
        }
        // movement
        target.x += self.target_offset.x * distance;
        target.y += self.target_offset.y * distance;
        // drawPixel(round(i32, self.pos.x + target.x), round(i32, self.pos.y + target.y));
        target.normalize();
        self.speed.x += target.x * accel;
        self.speed.y += target.y * accel;
        if (self.speed.x != 0 or self.speed.y != 0) {
            self.dir = self.speed;
            self.dir.normalize();
            if (self.speed.length() > speed_max) {
                self.speed.x = self.dir.x * speed_max;
                self.speed.y = self.dir.y * speed_max;
            }
        }
        self.pos.x += self.speed.x;
        self.pos.y += self.speed.y;
        // animation
        if ((frame_count + self.id) % 5 == 0) self.anim *= -1;
        if (closest < 0 or distance < closest) closest = distance;
    }

    fn draw(self: @This()) void {
        const x: i32 = round(i32, self.pos.x);
        const y: i32 = round(i32, self.pos.y);
        w4.DRAW_COLORS.* = 4;
        w4.line(
            x + round(i32, self.dir.x * (2 + self.anim) + self.dir.y * 4),
            y + round(i32, self.dir.y * (2 + self.anim) - self.dir.x * 4),
            x - round(i32, self.dir.x * (2 + self.anim) + self.dir.y * 4),
            y - round(i32, self.dir.y * (2 + self.anim) - self.dir.x * 4),
        );
        w4.line(
            x + round(i32, self.dir.x * (2 - self.anim) - self.dir.y * 4),
            y + round(i32, self.dir.y * (2 - self.anim) + self.dir.x * 4),
            x - round(i32, self.dir.x * (2 - self.anim) - self.dir.y * 4),
            y - round(i32, self.dir.y * (2 - self.anim) + self.dir.x * 4),
        );
        drawCircle(x, y, 5);
        drawPixel(
            x + round(i32, self.dir.x * 4 + self.dir.y * 1.5),
            y + round(i32, self.dir.y * 4 - self.dir.x * 1.5),
        );
        drawPixel(
            x + round(i32, self.dir.x * 4 - self.dir.y * 1.5),
            y + round(i32, self.dir.y * 4 + self.dir.x * 1.5),
        );
    }

    fn kill(self: *@This()) void {
        self.alive = false;
        kills += 1;
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 7 }).show();
        sound(toneFreq(200, 60), toneDur(0, 0, 0, 20), sound_vol, w4.TONE_NOISE);
    }
};

const Explosion = struct {
    alive: bool = true,
    pos: Point(i32),
    duration: i32,
    timer: i32 = 0,
    color: u16 = 0x40,

    var buffer = std.BoundedArray(@This(), 10).init(0) catch unreachable;
    var index: usize = 0;

    fn show(self: @This()) void {
        if (buffer.len < buffer.capacity()) _ = buffer.addOneAssumeCapacity();
        buffer.set(index, self);
        index = if (index < buffer.capacity() - 1) index + 1 else 0;
    }

    fn update(self: *@This()) void {
        self.timer += 1;
        if (self.timer > self.duration) self.alive = false;
    }

    fn draw(self: @This()) void {
        w4.DRAW_COLORS.* = self.color;
        if (self.timer > 0) drawCircle(self.pos.x, self.pos.y, self.timer * 2 - 1);
    }
};

const Scene = enum { title, game, gameover };

fn Point(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,

        fn length(self: @This()) T {
            return std.math.sqrt(self.x * self.x + self.y * self.y);
        }

        fn normalize(self: *@This()) void {
            const len = self.length();
            if (len > 0) {
                self.x /= len;
                self.y /= len;
            }
        }

        fn toInt(self: @This(), comptime T2: type) Point(T2) {
            return .{
                .x = round(T2, self.x),
                .y = round(T2, self.y),
            };
        }
    };
}

const screen_size: f64 = w4.SCREEN_SIZE;
var scene: Scene = .title;
var frame_count: u32 = 0;
var start_frame: u32 = 0;
var end_frame: u32 = 0;
var sound_vol: f64 = 0.6;
var wave: u32 = 0;
var kills: u32 = 0;
var hiscore: u32 = 0;
var prng = std.rand.DefaultPrng.init(0);
var rng: std.rand.Random = undefined;
var gamepad1 = Gamepad{ .ptr = w4.GAMEPAD1 };
var player1 = Player{};

const palette: [4]u32 = .{
    0x000011,
    0xdddd99,
    0x1166cc,
    0xcc1166,
};

export fn start() void {
    w4.PALETTE.* = palette;
    rng = prng.random();
    load();
}

export fn update() void {
    frame_count += 1;
    switch (scene) {
        .game => {
            // player
            gamepad1.update();
            if (player1.alive) {
                player1.update(gamepad1);
                player1.draw();
            }
            // enemies
            var wave_clear = true;
            Spider.closest = -1;
            for (Spider.buffer.slice()) |*spider| {
                if (spider.alive) {
                    wave_clear = false;
                    spider.update(&player1);
                    spider.draw();
                }
            }
            if (Spider.closest >= 0 and Spider.closest < 100 and frame_count % 10 == 0) {
                sound(60, toneDur(5, 0, 0, 5), sound_vol * (100 - Spider.closest) / 100, w4.TONE_PULSE2);
            }
            if (wave_clear) {
                wave += 1;
                Spider.buffer.len = 0;
                var id: usize = 0;
                while (id < wave and id < Spider.buffer.capacity()) {
                    Spider.buffer.appendAssumeCapacity(Spider.init(id));
                    id += 1;
                }
            }
            // effects
            for (Explosion.buffer.slice()) |*explosion| {
                if (explosion.alive) {
                    explosion.update();
                    explosion.draw();
                }
            }
            if (!player1.alive and frame_count - end_frame > 120) {
                scene = .gameover;
            }
        },
        .title => {
            gamepad1.update();
            if (gamepad1.isReleased(w4.BUTTON_1) or gamepad1.isReleased(w4.BUTTON_2)) {
                prng.seed(frame_count);
                start_frame = frame_count;
                wave = 0;
                kills = 0;
                scene = .game;
                player1 = Player{};
                Spider.buffer.len = 0;
                sound(440, toneDur(0, 0, 0, 20), sound_vol, w4.TONE_TRIANGLE);
            }
            if (gamepad1.isReleased(w4.BUTTON_LEFT)) {
                sound_vol = std.math.clamp(sound_vol - 0.2, 0, 1);
                sound(toneFreq(200, 40), 10, sound_vol, w4.TONE_PULSE1);
                save();
            }
            if (gamepad1.isReleased(w4.BUTTON_RIGHT)) {
                sound_vol = std.math.clamp(sound_vol + 0.2, 0, 1);
                sound(toneFreq(40, 200), 10, sound_vol, w4.TONE_PULSE1);
                save();
            }
            w4.DRAW_COLORS.* = 0x33;
            w4.oval(41, 42, 77, 79);
            w4.DRAW_COLORS.* = 1;
            w4.rect(40, 80, 80, 50);
            w4.DRAW_COLORS.* = 0x33;
            w4.oval(41, 66, 77, 27);
            w4.DRAW_COLORS.* = 4;
            w4.text("ONE SLIME ARMY", 24, 20);
            w4.DRAW_COLORS.* = 2;
            w4.text("START", 84, 105);
            w4.DRAW_COLORS.* = 3;
            w4.text("\x81\x80", 60, 105);
            w4.text("HISCORE", 20, 120);
            w4.text("VOLUME \x84     \x85", 28, 135);
            w4.rect(92, 135, 39, 7);
            w4.DRAW_COLORS.* = 2;
            drawInt(hiscore, 84, 120, 9);
            w4.rect(93, 136, round(u32, sound_vol * 37), 5);
        },
        .gameover => {
            gamepad1.update();
            if (gamepad1.isReleased(w4.BUTTON_1) or gamepad1.isReleased(w4.BUTTON_2)) {
                scene = .title;
                sound(440, toneDur(0, 0, 0, 20), sound_vol, w4.TONE_TRIANGLE);
            }
            if (kills > hiscore) {
                hiscore = kills;
                save();
            }
            w4.DRAW_COLORS.* = 4;
            w4.text("GAME OVER", 44, 45);
            w4.DRAW_COLORS.* = 3;
            w4.text("WAVE", 44, 75);
            w4.text("KILLS", 36, 95);
            w4.text("TIME", 44, 115);
            w4.DRAW_COLORS.* = 2;
            drawInt(wave, 84, 75, 9);
            drawInt(kills, 84, 95, 9);
            drawInt((end_frame - start_frame) / 60, 84, 115, 9);
        },
    }
}

fn save() void {
    var data: [2]u32 = .{
        round(u32, sound_vol * 100),
        hiscore,
    };
    _ = w4.diskw(@ptrCast([*]u8, &data), @sizeOf(@TypeOf(data)));
}

fn load() void {
    var data: [2]u32 = .{ 0, 0 };
    const bytes = w4.diskr(@ptrCast([*]u8, &data), @sizeOf(@TypeOf(data)));
    if (bytes > 0) {
        sound_vol = @intToFloat(f64, data[0]) / 100;
        hiscore = data[1];
    }
}

fn drawPixel(x: i32, y: i32) void {
    w4.rect(x, y, 1, 1);
}

fn drawCircle(x: i32, y: i32, size: i32) void {
    w4.oval(x - @divFloor(size, 2), y - @divFloor(size, 2), size, size);
}

fn drawInt(value: anytype, x: i32, y: i32, len: comptime_int) void {
    var buffer: [len]u8 = undefined;
    w4.text(std.fmt.bufPrintIntToSlice(buffer[0..], value, 10, .lower, .{}), x, y);
}

fn sound(frequency: u32, duration: u32, volume: f64, flags: u32) void {
    const vol = std.math.clamp(round(u32, volume * 100), 1, 100);
    w4.tone(frequency, duration, toneVol(vol, vol), flags);
}

fn toneFreq(freq1: u32, freq2: u32) u32 {
    return freq1 | (freq2 << 16);
}

fn toneDur(attack: u32, decay: u32, sustain: u32, release: u32) u32 {
    return (attack << 24) | (decay << 16) | sustain | (release << 8);
}

fn toneVol(peak: u32, volume: u32) u32 {
    return (peak << 8) | volume;
}

fn round(comptime T: type, float: anytype) T {
    return @floatToInt(T, std.math.round(float));
}
