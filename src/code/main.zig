const std = @import("std");

pub fn main() void {
    var a: i32 = 44;
    a += 3;
    std.debug.print("Hello World", .{});
}
