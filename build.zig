const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const lib = b.addSharedLibrary(.{
        .name = "cart",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });

    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    b.installArtifact(lib);

    const out = "dist/one-slime-army";
    const opt = b.addSystemCommand(&[_][]const u8{
        "wasm-opt",
        "-O3",
        "--strip-debug",
        "--zero-filled-memory",
        "--output",
        out ++ ".wasm",
    });
    opt.addArtifactArg(lib);

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
    bundle_step.dependOn(&lib.step);
    bundle_step.dependOn(&opt.step);
    bundle_step.dependOn(&bundle.step);
}
