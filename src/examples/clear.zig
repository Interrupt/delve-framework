const delve = @import("delve");
const app = delve.app;

// This example does nothing but open a blank window!

pub fn main() !void {
    try app.start(app.AppConfig{ .title = "Delve Framework - Clear Example" });
}
