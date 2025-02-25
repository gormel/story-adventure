const std = @import("std");
const pr = @import("properties.zig");

pub fn check(condition: std.json.ArrayHashMap(f64), props: *pr.Properties) bool {
    var iter = condition.map.iterator();
    while (iter.next()) |kv| {
        const cnd = kv.value_ptr.*;
        const act = props.get(kv.key_ptr.*);
        if (cnd > act) {
            return false;
        }
    }

    return true;
}