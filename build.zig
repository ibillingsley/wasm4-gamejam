const std = @import("std");

pub fn build(b: *std.Build) !void {
    const exe = b.addExecutable(.{
        .name = "cart",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall }),
    });

    exe.entry = .disabled;
    exe.root_module.export_symbol_names = &[_][]const u8{ "start", "update" };
    exe.import_memory = true;
    exe.initial_memory = 65536;
    exe.max_memory = 65536;
    exe.stack_size = 14752;

    b.installArtifact(exe);

    const out = "dist/one-slime-army";
    const opt = b.addSystemCommand(&[_][]const u8{
        "wasm-opt",
        "-O3",
        "--strip-debug",
        "--zero-filled-memory",
        "--output",
        out ++ ".wasm",
    });
    opt.addArtifactArg(exe);

    const bundle = b.addSystemCommand(&[_][]const u8{
        "w4",
        "bundle",
        "--title",
        "One Slime Army",
        "--html",
        out ++ ".html",
        "--windows",
        out ++ ".exe",
        "--mac",
        out ++ "-mac",
        "--linux",
        out ++ "-linux",
        out ++ ".wasm",
    });

    const bundle_step = b.step("bundle", "Build, optimize, bundle");
    bundle_step.dependOn(&exe.step);
    bundle_step.dependOn(&opt.step);
    bundle_step.dependOn(&bundle.step);
}
