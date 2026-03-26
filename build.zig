const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const merjs_dep = b.dependency("merjs", .{});
    const mer_mod = merjs_dep.module("mer");

    const main_mod = b.createModule(.{
        .root_source_file = merjs_dep.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = if (optimize != .Debug) true else null,
    });
    main_mod.addImport("mer", mer_mod);
    addDirModules(b, main_mod, mer_mod, "app", "app");
    addDirModules(b, main_mod, mer_mod, "api", "api");

    // Wire up the routes module (ssr.zig imports "routes")
    const routes_mod = b.createModule(.{
        .root_source_file = b.path("src/generated/routes.zig"),
    });
    routes_mod.addImport("mer", mer_mod);
    addDirModules(b, routes_mod, mer_mod, "app", "app");
    addDirModules(b, routes_mod, mer_mod, "api", "api");
    main_mod.addImport("routes", routes_mod);

    const exe = b.addExecutable(.{ .name = "app", .root_module = main_mod });
    b.installArtifact(exe);

    // zig build serve
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_exe.addArgs(args);
    b.step("serve", "Start the dev server").dependOn(&run_exe.step);

    // zig build codegen
    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = merjs_dep.path("tools/codegen.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const run_codegen = b.addRunArtifact(codegen_exe);
    run_codegen.setCwd(b.path("."));
    b.step("codegen", "Regenerate src/generated/routes.zig").dependOn(&run_codegen.step);
}

fn addDirModules(b: *std.Build, mod: *std.Build.Module, mer_mod: *std.Build.Module, dir: []const u8, prefix: []const u8) void {
    const layout_path = b.fmt("{s}/layout.zig", .{dir});
    const layout_mod: ?*std.Build.Module = blk: {
        std.fs.cwd().access(layout_path, .{}) catch break :blk null;
        const m = b.createModule(.{ .root_source_file = b.path(layout_path) });
        m.addImport("mer", mer_mod);
        mod.addImport(b.fmt("{s}/layout", .{prefix}), m);
        break :blk m;
    };
    var d = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch return;
    defer d.close();
    var walker = d.walk(b.allocator) catch return;
    defer walker.deinit();
    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;
        if (std.mem.eql(u8, entry.path, "layout.zig")) continue;
        const file_path = b.fmt("{s}/{s}", .{ dir, entry.path });
        const import_name = b.fmt("{s}/{s}", .{ prefix, entry.path[0 .. entry.path.len - 4] });
        const route_mod = b.createModule(.{ .root_source_file = b.path(file_path) });
        route_mod.addImport("mer", mer_mod);
        if (layout_mod) |lm| route_mod.addImport(b.fmt("{s}/layout", .{prefix}), lm);
        mod.addImport(import_name, route_mod);
    }
}
