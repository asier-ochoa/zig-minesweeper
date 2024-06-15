const std = @import("std");
const builtin = @import("builtin");

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

const Condition = enum {
    in_game,
    win,
    lose,
};

const MinesweeperError = error {
    MineAlreadyPresent,
};

pub const Board = struct {
    const Self = @This();
    const max_size = 4096;

    width: u16,
    height: u16,
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

    pub fn discoverCell(self: *Self, pos: i32) void {
        std.debug.assert(pos >= 0 and pos < self.minefield.len);
        if (self.minefield[@intCast(pos)].state != .flagged) {
            self.discoverFloodFill(pos);
        }
    }

    pub fn flagCell(self: *Self, pos: i32) void {
        std.debug.assert(pos >= 0 and pos < self.minefield.len);
        const state = &self.minefield[@intCast(pos)].state;
        switch (state.*) {
            .undiscovered => |*s| {s.* = .flagged;},
            .flagged => |*s| {s.* = .undiscovered;},
            .discovered => {},
        }
    }

    fn discoverFloodFill(self: Self, pos: i32) void {
        // std.debug.print("Trying x:{} y:{}\n", .{@mod(pos, self.width), @divTrunc(pos, self.width)});
        if (self.safeGetMut(@intCast(pos))) |cell| {
            if (cell.state != .discovered) {
                cell.state = .discovered;
            } else {
                return;
            }
        } else {
            return;
        }
        if (self.countAdjacentMines(@intCast(pos)) == 0) {
            const iwidth: i16 = @intCast(self.width);
            // Up
            self.discoverFloodFill(pos - iwidth);
            // Down
            self.discoverFloodFill(pos + iwidth);
            // Left
            if (@mod(pos, iwidth) - 1 >= 0) self.discoverFloodFill(pos - 1);
            // Right
            if (@mod(pos, iwidth) + 1 < iwidth) self.discoverFloodFill(pos + 1);
        }
    }

    fn safeGet(self: Self, pos: i32) ?*const Cell {
        return @constCast(self.safeGetMut(pos));
    }

    fn safeGet2D(self: Self, x: i32, y: i32) ?*const Cell {
        return if (x >= 0 and x < self.width and y >= 0 and y < self.height)
            self.safeGet(y * self.width + x)
        else
            null;
    }

    fn safeGetMut(self: Self, pos: i32) ?*Cell {
        return if (pos < 0 or pos >= self.minefield.len)
            null
        else
            &self.minefield[@intCast(pos)];
    }

    pub fn countAdjacentMines(self: Self, pos: i32) u8 {
        const x = @mod(pos, self.width);
        const y = @divTrunc(pos, self.width);
        const adjacent = [_]?*const Cell{
            self.safeGet2D(x - 1, y - 1), self.safeGet2D(x, y - 1), self.safeGet2D(x + 1, y - 1),
            self.safeGet2D(x - 1, y)    , null                         , self.safeGet2D(x + 1, y),
            self.safeGet2D(x - 1, y + 1), self.safeGet2D(x, y + 1), self.safeGet2D(x + 1, y + 1),
        };
        if (builtin.is_test) {
            std.debug.print("Adjacent mines:\n{any}\n", .{adjacent});
        }
        var count: u8 = 0;
        for (adjacent) |cell| {
            if (cell) |c| {
                count += if (c.has_mine) 1 else 0;
            }
        }
        return count;
    }

    pub fn checkCondition(self: Self) Condition {
        var undiscovered_empty = false;
        for (self.minefield) |cell| {
            switch (cell.state) {
                .discovered => {
                    if (cell.has_mine) return .lose;
                },
                .undiscovered, .flagged => {
                    if (!cell.has_mine) {
                        undiscovered_empty = true;
                    }
                },
            }
        }
        return if (undiscovered_empty) .in_game else .win;
    }

    pub fn revealMines(self: *Self) void {
        for (self.minefield) |*cell| {
            if (cell.has_mine) cell.state = .discovered;
        }
    }
};

fn getTestingRand() std.rand.Random {
    const static = struct {
        var testing_rand: std.rand.DefaultPrng = undefined;
        var initialized = false;
    };
    if (static.initialized) {
        return static.testing_rand.random();
    } else {
        static.testing_rand = std.rand.DefaultPrng.init(0);
        static.initialized = true;
        return static.testing_rand.random();
    }
}

inline fn emptyCell() Cell {
    return .{
        .state = .undiscovered,
        .has_mine = false,
    };
}

inline fn mineCell() Cell {
    return .{
        .state = .undiscovered,
        .has_mine = true,
    };
}

test "Initialization" {
    var board = Board{.width = 10, .height = 10, .rand = getTestingRand()};
    board.init();
    const test_data = &[_]Cell{Cell{.state = .undiscovered, .has_mine = false}} ** 100;

    try std.testing.expectEqual(board.minefield.len, test_data.len);
    for (0..board.minefield.len) |i| {
        std.testing.expect(std.meta.eql(
            board.minefield[i],
            test_data[i],
        )) catch |err| {
            std.debug.print("Failed board:\n{any}\n", .{test_data});
            return err;
        };
    }
}

test "Mine Adjacency" {
    var test_data = [_]Cell{
        emptyCell(), emptyCell(), emptyCell(), emptyCell(), emptyCell(),
        emptyCell(), emptyCell(), emptyCell(), emptyCell(), mineCell(),
        mineCell(), emptyCell(), emptyCell(), emptyCell(), emptyCell(),
        emptyCell(), mineCell(), emptyCell(), emptyCell(), emptyCell(),
        mineCell(), emptyCell(), mineCell(), mineCell(), emptyCell(),
    };

    var board = Board{.width = 5, .height = 5, .rand = getTestingRand()};
    board.minefield = &test_data;
    
    std.testing.expectEqual(1, board.countAdjacentMines(12)) catch |err| {
        std.debug.print("Failed board:\n{any}\n", .{test_data});
        return err;
    };
}