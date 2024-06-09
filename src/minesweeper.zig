const std = @import("std");

const Cell = struct {
    const State = enum {
        undiscovered,
        discovered,
        flagged,
    };
    state: State,
    has_mine: bool,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const symbol: u8 = if (self.has_mine) '*' else '_';
        try writer.print("{c}", .{symbol});
    }
};

const MinesweeperError = error {
    MineAlreadyPresent,
};

pub const Board = struct {
    const Self = @This();
    const max_size = 256;

    width: u8,
    height: u8,
    rand: std.rand.Random,
    minefield: []Cell = undefined,

    // Initializes the board using a static array as cell storage
    // Each cell starts as undiscovered with no mine
    pub fn init(self: *Self) void {
        std.debug.assert(self.width * self.height <= Self.max_size);
        const field_storage = struct {
            var minefield: [max_size]Cell = undefined;
        };
        self.minefield = field_storage.minefield[0..self.width * self.height];
        @memset(self.minefield, Cell{.has_mine = false, .state = .undiscovered});
    }

    pub fn placeMine(self: *Self, x: u32, y: u32) !void {
        try placeMine1D(self, y * self.width + x);
    }

    fn placeMine1D(self: *Self, pos: u32) !void {
        std.debug.assert(pos < self.minefield.len);
        var cell = &self.minefield[pos];
        if (cell.has_mine) {
            return MinesweeperError.MineAlreadyPresent;
        } else {
            cell.has_mine = true;
        }
    }

    pub fn generateMinefield(self: *Self, proportion: f32) void {
        std.debug.assert(proportion < 1);
        const minefield_len: f32 = @floatFromInt(self.minefield.len);
        var remaining_mines: u32 = @intFromFloat(minefield_len * proportion);

        // Place mines until the amount computed with the proportion is 0
        while (remaining_mines != 0) {
            const attempted_pos = self.rand.intRangeLessThan(u32, 0, @intCast(self.minefield.len));
            if (placeMine1D(self, attempted_pos)) {
                remaining_mines -= 1;
            } else |_| {}
        }
    }
};

test "Initialization" {
    var board = Board{.width = 10, .height = 10};
    try board.init();
    const test_data = &[_]Cell{Cell{.state = .undiscovered, .has_mine = false}} ** 100;

    try std.testing.expectEqual(board.minefield.len, test_data.len);
    for (0..board.minefield.len) |i| {
        try std.testing.expect(std.meta.eql(
            board.minefield[i],
            test_data[i],
        ));
    }
}