const std = @import("std");
const curses = @cImport({
    // @cDefine("NCURSES_WIDECHAR", "1");
    @cInclude("curses.h");
});
const signal = @cImport(@cInclude("signal.h"));
const locale = @cImport(@cInclude("locale.h"));

const CursesError = error{
    Return,
};

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

const GameState = struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub fn main() !u8 {
    // Need for unicode support
    _ = locale.setlocale(locale.LC_ALL, "");
    const main_window = curses.initscr().?;
    defer _ = curses.endwin();
    // Raw mode to instantly process characters
    _ = curses.raw();
    // Activate arrow key support
    _ = curses.keypad(main_window, true);

    var state = GameState{};

    // Main loop
    while (true) {
        switch (curses.getch()) {
            'q' => return 0,
            curses.KEY_UP => {state.y -= 1;},
            curses.KEY_DOWN => {state.y += 1;},
            curses.KEY_LEFT => {state.x -= 1;},
            curses.KEY_RIGHT => {state.x += 1;},
            else => |val| {std.debug.print("Pressed key: {x}\n", .{val});},
        }
        _ = curses.erase();
        try drawBox(state.x, state.y, 15, 10);
        _ = curses.refresh();
    }
    return 0;
}