const delve = @import("delve");
const app = delve.app;

// This example does nothing but open a blank window!

pub fn main() !void {
    const clear_module = delve.modules.Module{
        .name = "clear_example",
        .init_fn = on_init,
    };

    try delve.modules.registerModule(clear_module);

    try app.start(app.AppConfig{ .title = "Delve Framework - Clear Example" });
}

pub fn on_init() void {
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);
}
