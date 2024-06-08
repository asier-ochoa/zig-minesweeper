const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .target = b.graph.host,
        .name = "cursed_minesweeper",
        .root_source_file = b.path("src/main.zig"),
    });
    exe.linkSystemLibrary("ncursesw");
    exe.linkLibC();
    b.installArtifact(exe);

    // Add a convinience step for running
    const run_step = b.step("Run", "Runs program");
    const run_exe = b.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
}
