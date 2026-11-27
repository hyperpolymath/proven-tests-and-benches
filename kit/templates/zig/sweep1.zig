// SPDX-License-Identifier: MPL-2.0
// Sweep-1 template for Zig: UT, SMK, BLD, P2P. ADAPT: replace parseKv.
// Run: zig test sweep1.zig. NOT EXECUTED in the foundation container (no zig).
const std = @import("std");
const t = std.testing;

const ParseError = error{ NoSeparator, EmptyKey };
fn parseKv(s: []const u8) ParseError!struct { k: []const u8, v: []const u8 } {
    const i = std.mem.indexOfScalar(u8, s, '=') orelse return ParseError.NoSeparator;
    const k = std.mem.trim(u8, s[0..i], " ");
    if (k.len == 0) return ParseError.EmptyKey;
    return .{ .k = k, .v = s[i + 1 ..] };
}

test "UT splits on first equals" {
    const r = try parseKv("a=b=c");
    try t.expectEqualStrings("a", r.k);
    try t.expectEqualStrings("b=c", r.v);
}
test "UT error branches" {
    try t.expectError(ParseError.NoSeparator, parseKv("kv"));
    try t.expectError(ParseError.EmptyKey, parseKv(" =v"));
}
test "SMK comptime/runtime agree on a known answer" { // ADAPT: exec your binary via std.process.Child
    try t.expectEqual(@as(usize, 3), "abc".len);
}
test "BLD this file compiled under test, which is the build gate; CI also runs `zig build --summary all`" {
    try t.expect(@import("builtin").is_test);
}
test "P2P two ends of an in-memory stream (one seam)" {
    var buf: [16]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try fbs.writer().writeAll("name\n");
    fbs.reset();
    var line: [16]u8 = undefined;
    const got = try fbs.reader().readUntilDelimiter(&line, '\n');
    try t.expectEqualStrings("name", got);
}
