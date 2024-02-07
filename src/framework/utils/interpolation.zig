const std = @import("std");
const math = @import("../math.zig");

// Based on LibGdx's awesome Interpolation helpers

// Easing functions from LibGdx, https://gizma.com/easing/, and Foster Framework

pub const Interpolation = struct {
    interp_func: *const fn (f32) f32,

    pub fn applyIn(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);
        return start + ((end - start) * self.interp_func(t));
    }

    pub fn applyOut(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);
        return start + ((end - start) * flipInterpFunc(t, self.interp_func));
    }

    pub fn applyInOut(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);
        return start + ((end - start) * doInOut(t, self.interp_func));
    }

    pub fn applyInMirrored(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);

        if (t <= 0.5)
            return self.applyIn(start, end, alpha * 2.0);

        return self.applyIn(start, end, flip(alpha) * 2.0);
    }

    pub fn applyOutMirrored(self: *const Interpolation, start: f32, end: f32, alpha: f32) f32 {
        var t = std.math.clamp(alpha, 0.0, 1.0);

        if (t <= 0.5)
            return self.applyOut(start, end, alpha * 2.0);

        return self.applyOut(start, end, flip(alpha) * 2.0);
    }
};

/// Helper function to flip an interpolation halfway through
fn doInOut(alpha: f32, interp_func: *const fn (f32) f32) f32 {
    if (alpha <= 0.5)
        return interp_func(alpha * 2.0) * 0.5;
    return (flipInterpFunc((alpha * 2.0) - 1.0, interp_func) + 1.0) * 0.5;
}

/// Helper function to flip an interp func to do the out version
fn flipInterpFunc(t: f32, interp_func: *const fn (f32) f32) f32 {
    return flip(interp_func(flip(t)));
}

// ---- Interpolation types ----

pub const Lerp = Interpolation{
    .interp_func = linear,
};

pub const EaseQuad = Interpolation{
    .interp_func = easeQuad,
};

pub const EaseCube = Interpolation{
    .interp_func = easeCube,
};

pub const EaseQuart = Interpolation{
    .interp_func = easeQuart,
};

pub const EaseQuint = Interpolation{
    .interp_func = easeQuint,
};

pub const EaseExpo = Interpolation{
    .interp_func = easeExpo,
};

pub const EaseElastic = Interpolation{
    .interp_func = easeElastic,
};

pub const EaseBounce = Interpolation{
    .interp_func = easeBounce,
};

pub const Pow4 = Interpolation{
    .interp_func = pow4,
};

pub const Circle = Interpolation{
    .interp_func = circle,
};

pub const Sin = Interpolation{
    .interp_func = sin,
};

pub const PerlinSmoothstep = Interpolation{
    .interp_func = perlinSmoothstep,
};

// ---- interp implementation functions ----

pub fn linear(alpha: f32) f32 {
    return alpha;
}

pub fn easeQuad(alpha: f32) f32 {
    return alpha * alpha;
}

pub fn easeCube(alpha: f32) f32 {
    return alpha * alpha * alpha;
}

pub fn easeQuart(alpha: f32) f32 {
    return alpha * alpha * alpha * alpha;
}

pub fn easeQuint(alpha: f32) f32 {
    return alpha * alpha * alpha * alpha;
}

pub fn easeExpo(alpha: f32) f32 {
    if (alpha == 0)
        return 0;

    return std.math.pow(f32, 2, 10.0 * alpha - 10.0);
}

pub fn easeElastic(alpha: f32) f32 {
    const c4 = (2.0 * std.math.pi) / 3.0;
    if (alpha == 0.0)
        return 0.0;
    if (alpha == 1.0)
        return 1.0;

    return -std.math.pow(f32, 2, 10 * alpha - 10) * std.math.sin((alpha * 10 - 10.75) * c4);
}

pub fn easeBounce(alpha: f32) f32 {
    const n1: f32 = 7.5625;
    const d1: f32 = 2.75;
    const t: f32 = flip(alpha);

    if (t < 1.0 / d1) {
        return flip(n1 * t * t);
    } else if (t < 2.0 / d1) {
        const a = t - 1.5 / d1;
        return flip(n1 * a * a + 0.75);
    } else if (t < 2.5 / d1) {
        const a = t - 2.25 / d1;
        return flip(n1 * a * a + 0.9375);
    } else {
        const a = t - 2.625 / d1;
        return flip(n1 * a * a + 0.984375);
    }
}

pub fn pow4(alpha: f32) f32 {
    return std.math.pow(f32, alpha, 4);
}

pub fn circle(alpha: f32) f32 {
    return 1.0 - std.math.sqrt(1.0 - (alpha * alpha));
}

pub fn sin(alpha: f32) f32 {
    return (1.0 - std.math.cos(alpha * std.math.pi)) * 0.5;
}

/// Ken Perlin's improved smoothstep
pub fn perlinSmoothstep(a: f32) f32 {
    return a * a * a * (a * (a * 6 - 15) + 10);
}

/// flip an easing alpha where 0 would be 1, and 1 would be 0
fn flip(t: f32) f32 {
    return 1.0 - t;
}
