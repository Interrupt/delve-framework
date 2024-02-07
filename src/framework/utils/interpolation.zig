const std = @import("std");
const math = @import("../math.zig");

// Based on LibGdx's awesome Interpolation helpers

pub const Interpolation = struct {
    func: *const fn (f32) f32,

    pub fn apply(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);
        return start + ((end - start) * self.func(t));
    }

    pub fn applyUnclamped(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        return start + ((end - start) * self.func(alpha));
    }

    pub fn applyMirrored(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);

        if (t <= 0.5)
            return self.apply(start, end, alpha * 2.0);

        return self.apply(start, end, flip(alpha) * 2.0);
    }
};

pub const Lerp = Interpolation{
    .func = linear,
};

pub const EaseIn = Interpolation{
    .func = easeIn,
};

pub const EaseOut = Interpolation{
    .func = easeOut,
};

pub const EaseInOut = Interpolation{
    .func = easeInOut,
};

pub const CircleIn = Interpolation{
    .func = circleIn,
};

pub const CircleOut = Interpolation{
    .func = circleOut,
};

pub const CircleInOut = Interpolation{
    .func = circleInOut,
};

pub const Sin = Interpolation{
    .func = sin,
};

pub const PerlinSmoothstep = Interpolation{
    .func = perlinSmoothstep,
};

/// Helper function to flip an interpolatino halfway through
fn applyInOut(alpha: f32, in: *const fn (f32) f32, out: *const fn (f32) f32) f32 {
    if (alpha <= 0.5)
        return in(alpha * 2.0) * 0.5;
    return (out((alpha * 2.0) - 1.0) + 1.0) * 0.5;
}

// ---- interp implementation functions ----

pub fn linear(alpha: f32) f32 {
    return alpha;
}

pub fn easeIn(alpha: f32) f32 {
    return alpha * alpha;
}

pub fn easeOut(alpha: f32) f32 {
    const v = flip(alpha);
    return flip(v * v);
}

pub fn easeInOut(alpha: f32) f32 {
    return applyInOut(alpha, easeIn, easeOut);
}

pub fn circleIn(alpha: f32) f32 {
    return 1.0 - std.math.sqrt(1.0 - alpha * alpha);
}

pub fn circleOut(alpha: f32) f32 {
    var a = flip(alpha);
    return std.math.sqrt(1.0 - a * a);
}

pub fn circleInOut(alpha: f32) f32 {
    return applyInOut(alpha, circleIn, circleOut);
}

pub fn sin(alpha: f32) f32 {
    return (1.0 - std.math.cos(alpha * std.math.pi)) * 0.5;
}

/// Ken Perlin's improved smoothstep
pub fn perlinSmoothstep(a: f32) f32 {
    return a * a * a * (a * (a * 6 - 15) + 10);
}

fn flip(t: f32) f32 {
    return 1.0 - t;
}
