const std = @import("std");
const minesweeper = @import("minesweeper.zig");
const curses = @cImport({
    @cInclude("curses.h");
});
const signal = @cImport(@cInclude("signal.h"));
const locale = @cImport(@cInclude("locale.h"));

const CursesError = error{
    Return,
};

// Creates static cchar_t objects
// Lazily added at call-site
fn cchar_tOf(comptime symbol: comptime_int) CursesError!curses.cchar_t {
    const static = struct {
        const s = symbol;
        var cchar_t: ?curses.cchar_t = null;
    };

    // According to man setcchar, symbol must be null terminated
    const term_symbol = [_]c_int{symbol, 0};
    if (static.cchar_t) |_| {
        return static.cchar_t.?;
    } else {
        static.cchar_t = .{};
        switch (curses.setcchar(
            &(static.cchar_t.?),
            &term_symbol,
            0, 0, null
        )) {
            curses.ERR => return CursesError.Return,
            else => {}
        }
        return static.cchar_t.?;
    }
}

const drawing = struct {
    const v_line = '│';
    const h_line = '─';
    const tl_corner = '┌';
    const tr_corner = '┐';
    const bl_corner = '└';
    const br_corner = '┘';
    const mine = '*';
    const undiscovered = '■';
    const discovered = [_]u8{' ', '1', '2', '3', '4', '5', '6', '7', '8'};
    const flagged = '□';
};

inline fn between(a: anytype, val: anytype, b: anytype) bool {
    return a >= val and b <= val;
}

pub fn drawBox(x: i32, y: i32, width: u32, height: u32) !void{
    const iheight: i32 = @intCast(height);
    const iwidth: i32 = @intCast(width);
    _ = curses.mvhline_set(y, x + 1, &(try cchar_tOf(drawing.h_line)), iwidth - 2);
    _ = curses.mvhline_set(y + iheight - 1, x + 1, &(try cchar_tOf(drawing.h_line)), iwidth - 2);
    _ = curses.mvvline_set(y + 1, x, &(try cchar_tOf(drawing.v_line)), iheight - 2);
    _ = curses.mvvline_set(y + 1, x + iwidth - 1, &(try cchar_tOf(drawing.v_line)), iheight - 2);

    // Corners
    _ = curses.mvadd_wch(y, x, &(try cchar_tOf(drawing.tl_corner)));
    _ = curses.mvadd_wch(y, x + iwidth - 1, &(try cchar_tOf(drawing.tr_corner)));
    _ = curses.mvadd_wch(y + iheight - 1, x, &(try cchar_tOf(drawing.bl_corner)));
    _ = curses.mvadd_wch(y + iheight - 1, x + iwidth - 1, &(try cchar_tOf(drawing.br_corner)));
}

pub fn drawBoard(board: minesweeper.Board, x: i32, y: i32) void {
    for (board.minefield, 0..) |cell, i| {
        const ii: i32 = @intCast(i);
        _ = curses.mvadd_wch(
            y + @divTrunc(ii, board.width),
            x + @mod(ii, board.width),
            switch (cell.state) {
                .discovered => if (cell.has_mine) &(cchar_tOf(drawing.mine) catch unreachable)
                else switch (board.countAdjacentMines(@intCast(i))) {
                    inline 0...8 => |adj| &(cchar_tOf(drawing.discovered[adj]) catch unreachable),
                    else => unreachable,
                },
                .flagged => &(cchar_tOf(drawing.flagged) catch unreachable),
                .undiscovered => &(cchar_tOf(drawing.undiscovered) catch unreachable),
            },
        );
    }
}

const GameState = struct {
    board: minesweeper.Board,
    board_origin_x: i32 = 1,
    board_origin_y: i32 = 1,
    cursor_x: i32 = 0,
    cursor_y: i32 = 0,
};

fn draw(state: GameState) !void {
    _ = curses.erase();
    defer _ = curses.refresh();

    try drawBox(0, 0, state.board.width + 2, state.board.height + 2);
    drawBoard(state.board, 1, 1);
    _ = curses.move(state.cursor_y, state.cursor_x);
}

pub fn main() !u8 {
    // Need for unicode support
    _ = locale.setlocale(locale.LC_ALL, "");
    const main_window = curses.initscr().?;
    defer _ = curses.endwin();
    // Raw mode to instantly process characters
    _ = curses.raw();
    // Activate arrow key support
    _ = curses.keypad(main_window, true);

    var rand = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var state = GameState{
        .board = minesweeper.Board{
            .height = 16, .width = 16,
            .rand = rand.random(),
        }
    };
    state.board.init();
    state.board.generateMinefield(0.1);

    // Main loop
    try draw(state);
    while (true) {
        switch (curses.getch()) {
            'q' => return 0,
            curses.KEY_UP => {state.cursor_y -= 1;},
            curses.KEY_DOWN => {state.cursor_y += 1;},
            curses.KEY_LEFT => {state.cursor_x -= 1;},
            curses.KEY_RIGHT => {state.cursor_x += 1;},
            ' ' => {
                state.board.discoverCell(
                    (state.cursor_y - state.board_origin_y) *
                    state.board.width +
                    (state.cursor_x - state.board_origin_y)
                );
            },
            else => |val| {std.debug.print("Pressed key: {x}\n", .{val});},
        }
        try draw(state);
    }
    return 0;
}