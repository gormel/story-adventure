const std = @import("std");

pub const Easing = enum {
    Linear,
    Ease,
    EaseIn,
    EaseOut,
    EaseInOut,
};

fn linear(x: f32) f32 {
    return x;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a * (1 - t) + b * t;
}

fn quad(a: f32, b: f32, c: f32, t: f32) f32 {
    return lerp(lerp(a, b, t), lerp(b, c, t), t);
}

fn cubic(a: f32, b: f32, c: f32, d: f32, t: f32) f32 {
    return lerp(quad(a, b, c, t), quad(b, c, d, t), t);
}

fn ease(x: f32) f32 {
    return cubic(0, 0.13, 1, 1, x);
}

fn ease_in(x: f32) f32 {
    return cubic(0, 0, 0.5, 1, x);
}

fn ease_out(x: f32) f32 {
    return cubic(0, 0.5, 1, 1, x);
}

fn ease_in_out(x: f32) f32 {
    return cubic(0, 0, 1, 1, x);
}

const funcs = .{
    .{ .easing = Easing.Linear, .func = linear },
    .{ .easing = Easing.Ease, .func = ease },
    .{ .easing = Easing.EaseIn, .func = ease_in },
    .{ .easing = Easing.EaseOut, .func = ease_out },
    .{ .easing = Easing.EaseInOut, .func = ease_in_out },
};

pub fn getFunc(easing: Easing) *const fn(f32) f32 {
    return switch (easing) {
        .Linear => linear,
        .Ease => ease,
        .EaseIn => ease_in,
        .EaseOut => ease_out,
        .EaseInOut => ease_in_out,
    };
}

// Lerp[A_, B_, t_] := A (1 - t) + B t
// Quad[A_, B_, C_, t_] := Lerp[Lerp[A, B, t], Lerp[B, C, t], t]
// Cube[A_, B_, C_, D_, t_] := Lerp[Quad[A, B, C, t], Quad[B, C, D, t], t]
// Grid[{
//   {Dynamic@
//     Plot[Cube[0, A, B, 1, t], {t, 0, 1}, AspectRatio -> 1, 
//      PlotRange -> { {0, 1}, {0, 1 }}]},
//   { Slider[Dynamic[A], {0, 2}], Dynamic[A]},
//   { Slider[Dynamic[B], {-1, 1}], Dynamic[B]}
//   }]