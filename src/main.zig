const std = @import("std");
const w4 = @import("wasm4.zig");

const Gamepad = struct {
    ptr: *const u8,
    down: u8 = 0,
    prev: u8 = 0,
    pressed: u8 = 0,
    released: u8 = 0,
    axis: Vec(f64) = .{},

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
    pos: Vec(f64) = .{ .x = screen_size / 2, .y = screen_size / 2 + 15 },
    move_speed: f64 = 2,
    move_dir: Vec(f64) = .{},
    look_dir: Vec(f64) = .{ .x = 0, .y = -1 },
    dodge_dir: Vec(f64) = .{ .x = 0, .y = -1 },
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

    fn collideBody(self: @This(), target: Vec(f64), radius: f64) bool {
        if (!self.alive or self.dodge_timer > 0) return false;
        return self.pos.distance(target) < 4.5 + radius;
    }

    fn collideBlock(self: @This(), target: Vec(f64), radius: f64) bool {
        if (!self.alive or !self.blocking) return false;
        var diff = Vec(f64){
            .x = self.pos.x + self.look_dir.x * 2 - target.x,
            .y = self.pos.y + self.look_dir.y * 2 - target.y,
        };
        return diff.length() < 7.5 + radius and diff.dot(self.look_dir) <= 0;
    }

    fn collideAttack(self: @This(), target: Vec(f64), radius: f64) bool {
        if (!self.alive or self.attack_timer <= 0) return false;
        var diff = Vec(f64){
            .x = self.pos.x + self.look_dir.x * 5 - target.x,
            .y = self.pos.y + self.look_dir.y * 5 - target.y,
        };
        return diff.length() < 8.5 + radius;
    }

    fn kill(self: *@This()) void {
        self.alive = false;
        end_frame = frame_count;
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 25 }).spawn();
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 27, .timer = -3 }).spawn();
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 18, .timer = -8, .color = 0x20 }).spawn();
        sound(toneFreq(240, 20), toneDur(0, 0, 0, 60), sound_vol, w4.TONE_NOISE);
        sound(440, toneDur(50, 0, 50, 50), sound_vol, w4.TONE_TRIANGLE);
    }
};

const Spider = struct {
    id: usize,
    alive: bool = true,
    pos: Vec(f64),
    speed: Vec(f64) = .{},
    dir: Vec(f64) = .{},
    target_offset: Vec(f64),

    const accel = 0.05;
    const speed_max = 1.5;
    var buffer = std.BoundedArray(@This(), 100).init(0) catch unreachable;
    var closest: f64 = -1;

    fn init(id: usize) @This() {
        const x = rng.float(f64) * 100 - 50;
        const y = rng.float(f64) * 100 - 50;
        return .{
            .id = id,
            .pos = .{
                .x = if (x < 0) -50 + x else screen_size + 50 + x,
                .y = if (y < 0) -50 + y else screen_size + 50 + y,
            },
            .target_offset = .{
                .x = rng.float(f64) * 1.2 - 0.6,
                .y = rng.float(f64) * 1.2 - 0.6,
            },
        };
    }

    fn update(self: *@This(), player: *Player) void {
        // collision
        var target = player.pos.subtract(self.pos);
        const distance = target.length();
        if (closest < 0 or distance < closest) closest = distance;
        if (player.collideAttack(self.pos, 6)) {
            self.kill();
        } else if (player.collideBlock(self.pos, 2.5)) {
            const bump = std.math.max(11 - distance, 1.5);
            self.pos.x += player.look_dir.x * bump;
            self.pos.y += player.look_dir.y * bump;
            self.speed.reflect(player.look_dir);
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
    }

    fn draw(self: @This()) void {
        const x = round(i32, self.pos.x);
        const y = round(i32, self.pos.y);
        const flip: f64 = if ((frame_count / 5 + self.id) % 2 == 0) 1 else -1;
        w4.DRAW_COLORS.* = 4;
        w4.line(
            x + round(i32, self.dir.x * (2 + flip) + self.dir.y * 4),
            y + round(i32, self.dir.y * (2 + flip) - self.dir.x * 4),
            x - round(i32, self.dir.x * (2 + flip) + self.dir.y * 4),
            y - round(i32, self.dir.y * (2 + flip) - self.dir.x * 4),
        );
        w4.line(
            x + round(i32, self.dir.x * (2 - flip) - self.dir.y * 4),
            y + round(i32, self.dir.y * (2 - flip) + self.dir.x * 4),
            x - round(i32, self.dir.x * (2 - flip) - self.dir.y * 4),
            y - round(i32, self.dir.y * (2 - flip) + self.dir.x * 4),
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
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 7 }).spawn();
        sound(toneFreq(200, 60), toneDur(0, 0, 0, 20), sound_vol, w4.TONE_NOISE);
    }
};

const Cannon = struct {
    id: usize,
    alive: bool = true,
    pos: Vec(f64),
    speed: Vec(f64) = .{},
    dir: Vec(f64) = .{},
    look_dir: Vec(f64) = .{},
    target_offset: Vec(f64),

    const accel = 0.01;
    const speed_max = 0.4;
    var buffer = std.BoundedArray(@This(), 20).init(0) catch unreachable;

    fn init(id: usize) @This() {
        const x = rng.float(f64) * 100 - 50;
        const y = rng.float(f64) * 100 - 50;
        return .{
            .id = id,
            .pos = .{
                .x = if (x < 0) -10 + x else screen_size + 10 + x,
                .y = if (y < 0) -10 + y else screen_size + 10 + y,
            },
            .target_offset = .{
                .x = rng.float(f64) * 1.2 - 0.6,
                .y = rng.float(f64) * 1.2 - 0.6,
            },
        };
    }

    fn update(self: *@This(), player: *Player) void {
        // collision
        var target = player.pos.subtract(self.pos);
        const distance = target.length();
        if (player.collideAttack(self.pos, 7)) {
            self.kill();
        } else if (player.collideBlock(self.pos, 3)) {
            const bump = std.math.max(11 - distance, 1.5);
            self.pos.x += player.look_dir.x * bump;
            self.pos.y += player.look_dir.y * bump;
            self.speed.reflect(player.look_dir);
            sound(500, toneDur(0, 0, 0, 3), sound_vol * 0.3, w4.TONE_NOISE);
        } else if (player.collideBody(self.pos, 3)) {
            player.kill();
        }
        // movement
        var move_target: Vec(f64) = .{
            .x = target.x + self.target_offset.x * distance,
            .y = target.y + self.target_offset.y * distance,
        };
        move_target.normalize();
        self.speed.x += move_target.x * accel;
        self.speed.y += move_target.y * accel;
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
        // shoot
        target.normalize();
        self.look_dir = target;
        if (self.pos.x > 0 and self.pos.x < screen_size and
            self.pos.y > 0 and self.pos.y < screen_size and
            (frame_count + self.id * 10) % 100 == 0)
        {
            (Projectile{
                .pos = .{ .x = self.pos.x + self.look_dir.x * 4, .y = self.pos.y + self.look_dir.y * 4 },
                .speed = .{ .x = target.x * 2, .y = target.y * 2 },
                .duration = 80,
            }).spawn();
            sound(toneFreq(300, 100), toneDur(0, 0, 0, 10), sound_vol * 0.7, w4.TONE_PULSE1 | w4.TONE_MODE2);
        }
    }

    fn draw(self: @This()) void {
        const x = self.pos.x;
        const y = self.pos.y;
        w4.DRAW_COLORS.* = 0x33;
        drawCircleF(x + self.dir.y * 4, y - self.dir.x * 4, 3);
        drawCircleF(x - self.dir.y * 4, y + self.dir.x * 4, 3);
        w4.DRAW_COLORS.* = 4;
        drawLineF(
            x - self.look_dir.x * 3.5,
            y - self.look_dir.y * 3.5,
            x + self.look_dir.x * 4,
            y + self.look_dir.y * 4,
        );
        drawLineF(
            x - self.look_dir.x * 3 - self.look_dir.y * 0.5,
            y - self.look_dir.y * 3 + self.look_dir.x * 0.5,
            x + self.look_dir.x * 5 - self.look_dir.y * 0.5,
            y + self.look_dir.y * 5 + self.look_dir.x * 0.5,
        );
        drawLineF(
            x - self.look_dir.x * 3 + self.look_dir.y * 0.5,
            y - self.look_dir.y * 3 - self.look_dir.x * 0.5,
            x + self.look_dir.x * 5 + self.look_dir.y * 0.5,
            y + self.look_dir.y * 5 - self.look_dir.x * 0.5,
        );
    }

    fn kill(self: *@This()) void {
        self.alive = false;
        kills += 1;
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 8 }).spawn();
        sound(toneFreq(180, 50), toneDur(0, 0, 0, 22), sound_vol, w4.TONE_NOISE);
    }
};

const Snake = struct {
    id: usize,
    alive: bool = true,
    pos: Vec(f64),
    speed: Vec(f64) = .{},
    dir: Vec(f64) = .{},
    size: f64,

    const speed_max = 2;
    var buffer = std.BoundedArray(@This(), 50).init(0) catch unreachable;
    var closest: f64 = -1;

    fn init(id: usize) @This() {
        const pos: Vec(f64) = blk: {
            if (id > 0) {
                const previous = buffer.get(id - 1);
                break :blk previous.pos;
            }
            const x = rng.float(f64) * 100 - 50;
            const y = rng.float(f64) * 100 - 50;
            break :blk .{
                .x = if (x < 0) -50 + x else screen_size + 50 + x,
                .y = if (y < 0) -50 + y else screen_size + 50 + y,
            };
        };
        return .{
            .id = id,
            .pos = pos,
            .size = std.math.max(17 - @intToFloat(f64, id), 9),
        };
    }

    fn update(self: *@This(), player: *Player) void {
        // collision
        var target = player.pos.subtract(self.pos);
        const distance = target.length();
        if (closest < 0 or distance < closest) closest = distance;
        const radius = self.size / 2;
        if (player.collideAttack(self.pos, radius)) {
            self.kill();
        } else if (player.collideBlock(self.pos, radius)) {
            const bump = std.math.max(11 - distance, 1.5);
            self.pos.x += player.look_dir.x * bump;
            self.pos.y += player.look_dir.y * bump;
            self.speed.reflect(player.look_dir);
            sound(500, toneDur(0, 0, 0, 3), sound_vol * 0.3, w4.TONE_NOISE);
        } else if (player.collideBody(self.pos, radius)) {
            player.kill();
        }
        // movement
        var move_target = target;
        var accel: f64 = std.math.max((100 - distance) * 0.003, 0.05);
        if (self.id > 0) {
            const previous = buffer.get(self.id - 1);
            if (previous.alive) {
                move_target = previous.pos.subtract(self.pos);
                const dist = move_target.length();
                accel = dist * dist * 0.025;
            }
        }
        move_target.normalize();
        self.speed.x += move_target.x * accel;
        self.speed.y += move_target.y * accel;
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
    }

    fn draw(self: @This()) void {
        const x = self.pos.x;
        const y = self.pos.y;
        const flip: f64 = if ((frame_count / 5 + self.id) % 2 == 0) 1 else -1;
        w4.DRAW_COLORS.* = 4;
        drawLineF(
            x + (self.dir.x * (2.5 + flip) * 0.1 + self.dir.y * 0.8) * self.size,
            y + (self.dir.y * (2.5 + flip) * 0.1 - self.dir.x * 0.8) * self.size,
            x - (self.dir.x * (2.5 + flip) * 0.1 + self.dir.y * 0.8) * self.size,
            y - (self.dir.y * (2.5 + flip) * 0.1 - self.dir.x * 0.8) * self.size,
        );
        drawLineF(
            x + (self.dir.x * (2.5 - flip) * 0.1 - self.dir.y * 0.8) * self.size,
            y + (self.dir.y * (2.5 - flip) * 0.1 + self.dir.x * 0.8) * self.size,
            x - (self.dir.x * (2.5 - flip) * 0.1 - self.dir.y * 0.8) * self.size,
            y - (self.dir.y * (2.5 - flip) * 0.1 + self.dir.x * 0.8) * self.size,
        );
        drawLineF(
            x + (self.dir.x * 0.50 - self.dir.y * 0.1) * self.size,
            y + (self.dir.y * 0.50 + self.dir.x * 0.1) * self.size,
            x + (self.dir.x * 0.65 - self.dir.y * 0.2) * self.size,
            y + (self.dir.y * 0.65 + self.dir.x * 0.2) * self.size,
        );
        drawLineF(
            x + (self.dir.x * 0.50 + self.dir.y * 0.1) * self.size,
            y + (self.dir.y * 0.50 - self.dir.x * 0.1) * self.size,
            x + (self.dir.x * 0.65 + self.dir.y * 0.2) * self.size,
            y + (self.dir.y * 0.65 - self.dir.x * 0.2) * self.size,
        );
        w4.DRAW_COLORS.* = 0x41;
        drawCircleF(x, y, self.size);
    }

    fn kill(self: *@This()) void {
        self.alive = false;
        kills += 1;
        (Explosion{ .pos = self.pos.toInt(i32), .duration = 9 }).spawn();
        sound(toneFreq(170, 40), toneDur(0, 0, 0, 25), sound_vol, w4.TONE_NOISE);
    }
};

const Projectile = struct {
    alive: bool = true,
    pos: Vec(f64),
    speed: Vec(f64),
    duration: i32,
    timer: i32 = 0,
    hostile: bool = true,

    var buffer = std.BoundedArray(@This(), 20).init(0) catch unreachable;
    var index: usize = 0;

    fn spawn(self: @This()) void {
        if (buffer.len < buffer.capacity()) _ = buffer.addOneAssumeCapacity();
        buffer.set(index, self);
        index = (index + 1) % buffer.capacity();
    }

    fn update(self: *@This(), player: *Player) void {
        self.timer += 1;
        if (self.timer > self.duration) self.alive = false;
        // collision
        if (self.hostile) {
            if (player.collideAttack(self.pos, 3)) {
                self.alive = false;
            } else if (player.collideBlock(self.pos, 3)) {
                self.hostile = false;
                self.timer = 0;
                self.speed.reflect(player.look_dir);
                sound(500, toneDur(0, 0, 0, 3), sound_vol * 0.7, w4.TONE_NOISE);
            } else if (player.collideBody(self.pos, 1)) {
                player.kill();
            }
        } else {
            for (Spider.buffer.slice()) |*spider| {
                if (spider.alive and self.pos.distance(spider.pos) < 5) {
                    spider.kill();
                }
            }
            for (Cannon.buffer.slice()) |*cannon| {
                if (cannon.alive and self.pos.distance(cannon.pos) < 6) {
                    cannon.kill();
                }
            }
            for (Snake.buffer.slice()) |*snake| {
                if (snake.alive and self.pos.distance(snake.pos) < snake.size / 2) {
                    snake.kill();
                }
            }
        }
        // movement
        self.pos.x += self.speed.x;
        self.pos.y += self.speed.y;
    }

    fn draw(self: @This()) void {
        const x = self.pos.x;
        const y = self.pos.y;
        w4.DRAW_COLORS.* = if (self.hostile) 0x22 else 0x21;
        drawCircleF(x, y, 3);
    }
};

const Explosion = struct {
    alive: bool = true,
    pos: Vec(i32),
    duration: i32,
    timer: i32 = 0,
    color: u16 = 0x40,

    var buffer = std.BoundedArray(@This(), 10).init(0) catch unreachable;
    var index: usize = 0;

    fn spawn(self: @This()) void {
        if (buffer.len < buffer.capacity()) _ = buffer.addOneAssumeCapacity();
        buffer.set(index, self);
        index = (index + 1) % buffer.capacity();
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

fn Vec(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T = 0,
        y: T = 0,

        fn length(self: Self) T {
            return std.math.sqrt(self.x * self.x + self.y * self.y);
        }

        fn dot(self: Self, vec: Self) T {
            return self.x * vec.x + self.y * vec.y;
        }

        fn add(self: Self, vec: Self) Self {
            return .{ .x = self.x + vec.x, .y = self.y + vec.y };
        }

        fn subtract(self: Self, vec: Self) Self {
            return .{ .x = self.x - vec.x, .y = self.y - vec.y };
        }

        fn distance(self: Self, vec: Self) T {
            return self.subtract(vec).length();
        }

        fn normalize(self: *Self) void {
            const len = self.length();
            if (len > 0) {
                self.x /= len;
                self.y /= len;
            }
        }

        fn reflect(self: *Self, normal: Self) void {
            const d = self.dot(normal);
            self.x -= 2 * d * normal.x;
            self.y -= 2 * d * normal.y;
        }

        fn toInt(self: Self, comptime T2: type) Vec(T2) {
            return .{
                .x = round(T2, self.x),
                .y = round(T2, self.y),
            };
        }
    };
}

const screen_size: f64 = w4.SCREEN_SIZE;
const Scene = enum { title, game, gameover };
var scene: Scene = .title;
var frame_count: u32 = 0;
var start_frame: u32 = 0;
var end_frame: u32 = 0;
var sound_vol: f64 = 0.8;
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

fn startGame() void {
    prng.seed(frame_count);
    start_frame = frame_count;
    wave = 0;
    kills = 0;
    player1 = Player{};
    Spider.buffer.len = 0;
    Cannon.buffer.len = 0;
    Snake.buffer.len = 0;
    Projectile.buffer.len = 0;
    Projectile.index = 0;
    Explosion.buffer.len = 0;
    Explosion.index = 0;
    scene = .game;
}

export fn update() void {
    frame_count += 1;
    gamepad1.update();
    switch (scene) {
        .game => updateGame(),
        .title => updateTitle(),
        .gameover => updateGameover(),
    }
}

fn updateGame() void {
    // player
    if (player1.alive) {
        player1.update(gamepad1);
        player1.draw();
    }
    if (!player1.alive and frame_count - end_frame > 120) {
        scene = .gameover;
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
    for (Cannon.buffer.slice()) |*cannon| {
        if (cannon.alive) {
            wave_clear = false;
            cannon.update(&player1);
            cannon.draw();
        }
    }
    Snake.closest = -1;
    {
        var i = Snake.buffer.len;
        while (i > 0) {
            i -= 1;
            var snake = &Snake.buffer.buffer[i];
            if (snake.alive) {
                wave_clear = false;
                snake.update(&player1);
                snake.draw();
            }
        }
    }
    if (Snake.closest >= 0 and Snake.closest < 200 and frame_count % 12 == 0) {
        sound(toneFreq(90, 60), toneDur(5, 0, 0, 5), sound_vol * (200 - Snake.closest) / 200, w4.TONE_PULSE2 | w4.TONE_MODE3);
    }
    for (Projectile.buffer.slice()) |*projectile| {
        if (projectile.alive) {
            projectile.update(&player1);
            projectile.draw();
        }
    }
    // effects
    for (Explosion.buffer.slice()) |*explosion| {
        if (explosion.alive) {
            explosion.update();
            explosion.draw();
        }
    }
    // spawn wave
    if (wave_clear) {
        wave += 1;
        const boss = wave % 10 == 0;
        const num_snake = std.math.min(
            if (boss) wave else 0,
            Snake.buffer.capacity(),
        );
        const num_cannons = std.math.min(
            (if (boss) (wave -| 10) / 4 else wave) / 3,
            Cannon.buffer.capacity(),
        );
        const num_spiders = std.math.min(
            (if (boss) (wave -| 10) / 4 else wave) -| num_cannons,
            Spider.buffer.capacity(),
        );
        {
            Spider.buffer.len = 0;
            var id: usize = 0;
            while (id < num_spiders) : (id += 1) {
                Spider.buffer.appendAssumeCapacity(Spider.init(id));
            }
        }
        {
            Cannon.buffer.len = 0;
            var id: usize = 0;
            while (id < num_cannons) : (id += 1) {
                Cannon.buffer.appendAssumeCapacity(Cannon.init(id));
            }
        }
        {
            Snake.buffer.len = 0;
            var id: usize = 0;
            while (id < num_snake) : (id += 1) {
                Snake.buffer.appendAssumeCapacity(Snake.init(id));
            }
        }
    }
}

fn updateTitle() void {
    if (gamepad1.isReleased(w4.BUTTON_1) or gamepad1.isReleased(w4.BUTTON_2)) {
        startGame();
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
}

fn updateGameover() void {
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

fn drawCircleF(x: f64, y: f64, size: f64) void {
    const s = round(i32, size);
    w4.oval(round(i32, x - (size / 2)), round(i32, y - (size / 2)), s, s);
}

fn drawLineF(x1: f64, y1: f64, x2: f64, y2: f64) void {
    w4.line(round(i32, x1), round(i32, y1), round(i32, x2), round(i32, y2));
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
