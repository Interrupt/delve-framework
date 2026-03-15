// Sokol
pub const sokol_app = @import("sokol/app.zig");
pub const sokol_graphics = @import("sokol/graphics.zig");

// Null
pub const null_app = @import("null/app.zig");
pub const null_graphics = @import("null/graphics.zig");

pub const AppBackends = enum {
    Sokol,
    Null,
};

pub const GraphicsBackends = enum {
    Sokol,
    Null,
};

const picked_app_backend: AppBackends = .Sokol;
const picked_gfx_backend: GraphicsBackends = .Null;

pub fn GetAppBackend() type {
    comptime {
        return switch (picked_app_backend) {
            .Sokol => sokol_app.App,
            .Null => null_app.App,
        };
    }
}

pub fn GetGraphicsBackend() type {
    comptime {
        return switch (picked_gfx_backend) {
            .Sokol => sokol_graphics,
            .Null => null_graphics,
        };
    }
}
