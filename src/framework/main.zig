// const std = @import("std");
//
// // Delve framework
// const app = @import("app.zig");
//
// var args_gpa = std.heap.GeneralPurposeAllocator(.{}){};
// var args_allocator = args_gpa.allocator();
//
// pub fn main() !void {
//     // Get arguments
//     const args = try std.process.argsAlloc(args_allocator);
//     defer _ = args_gpa.deinit();
//     defer std.process.argsFree(args_allocator, args);
//
//     // Set a different assets path if one is given
//     if (args.len >= 2) {
//         try app.setAssetsPath(args[1]);
//     }
//
//     // Register the simple lua lifecycle that runs assets/main.lua
//     try @import("modules/lua_simple.zig").registerModule();
//
//     // Enable the FPS counter
//     const fps_module = @import("modules/fps_counter.zig");
//     try fps_module.registerModule();
//     fps_module.showFPS(true);
//
//     // Test some example modules
//     try @import("examples/mesh.zig").registerModule();
//     try @import("examples/debugdraw.zig").registerModule();
//     try @import("examples/batcher.zig").registerModule();
//     try @import("examples/audio.zig").registerModule();
//
//     try app.start(app.AppConfig{ .title = "Delve Framework Test" });
// }
