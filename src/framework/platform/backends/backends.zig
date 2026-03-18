const build_options = @import("delve_options");

// Sokol
pub const sokol_app = @import("sokol/app.zig");
pub const sokol_graphics = @import("sokol/graphics.zig");

// Null
pub const null_app = @import("null/app.zig");
pub const null_graphics = @import("null/graphics.zig");

// Headless
pub const headless_app = @import("headless/app.zig");

pub fn GetPickedBackend() build_options.Backend {
    return build_options.backend;
}

pub fn GetAppBackend() type {
    comptime {
        return switch (build_options.backend) {
            .sokol => sokol_app.App,
            .headless => headless_app.App,
            .null => null_app.App,
        };
    }
}

pub fn GetGraphicsBackend() type {
    comptime {
        return switch (build_options.backend) {
            .sokol => sokol_graphics,
            .headless => null_graphics,
            .null => null_graphics,
        };
    }
}
