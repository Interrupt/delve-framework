
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn new(r: f32, g: f32, b: f32, a: f32) Color {
       return Color{.r=r,.g=g,.b=b,.a=a};
    }

    pub fn fromArray(val: [4]f32) Color {
       return Color{.r=val[0],.g=val[1],.b=val[2],.a=val[3]};
    }

    pub fn toInt(self: Color) u32 {
        var c: u32 = 0;
        c |= @intFromFloat(self.r * 0x000000FF);
        c |= @intFromFloat(self.g * 0x0000FF00);
        c |= @intFromFloat(self.b * 0x00FF0000);
        c |= @intFromFloat(self.a * 0xFF000000);
        return c;
    }

    pub fn toArray(self: Color) [4]f32 {
        return [_]f32 { self.r, self.g, self.b, self.a };
    }
};

// Preset colors!
pub const transparent: Color = Color{.r=0.0,.g=0.0,.b=0.0,.a=0.0};
pub const white: Color = Color{.r=1.0,.g=1.0,.b=1.0,.a=1.0};
pub const black: Color = Color{.r=0.0,.g=0.0,.b=0.0,.a=1.0};
pub const grey: Color = Color{.r=0.5,.g=0.5,.b=0.5,.a=1.0};
pub const red: Color = Color{.r=1.0,.g=0.0,.b=0.0,.a=1.0};
pub const green: Color = Color{.r=0.0,.g=1.0,.b=0.0,.a=1.0};
pub const blue: Color = Color{.r=0.0,.g=0.0,.b=1.0,.a=1.0};
