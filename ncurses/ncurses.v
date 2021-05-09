module ncurses

#flag -lcurses
#include <curses.h>

fn C.initscr() &C._win_st
fn C.mvaddstr(y i16, x i16, str &char) i16
fn C.refresh() i16
fn C.delwin(win &C._win_st) i16
fn C.endwin() i16
fn C.noecho() i16
fn C.keypad(window &C._win_st, b bool) i16
fn C.getch() i16
fn C.wmove(window &C._win_st, y i16, x i16) i16
fn C.winsdelln(window &C._win_st, line i16) i16

struct C._win_st {
	_cury       i16
	_curx       i16
	_maxy       i16
	_maxx       i16
	_begy       i16
	_begx       i16
	_flags      i16
	_attrs      u16
	_bkgd       u16
	_notimeout  bool
	_clear      bool
	_leaveok    bool
	_scroll     bool
	_idlok      bool
	_idcok      bool
	_immed      bool
	_sync       bool
	_use_keypad bool
	_delay      i16
	_line       voidptr
	_regtop     i16
	_regbottom  i16
	_parx       i16
	_pary       i16
	_parent     &C._win_st
}

pub struct SessionConfig {
	use_keyboard bool
}

struct Session {
	config  SessionConfig
	mainwin &C._win_st
}

pub fn create_session(config SessionConfig) ?&Session {
	mut win := C.initscr()
	if win == 0 {
		return error('Error initialising ncurses.')
	}
	if config.use_keyboard {
		C.noecho()
		C.keypad(win, true)
	}
	return &Session{
		config: config
		mainwin: win
	}
}

pub fn (mut session Session) close_session() {
	C.delwin(session.mainwin)
	C.endwin()
	session.refresh()
}

pub fn (mut session Session) refresh() {
	C.refresh()
}

pub fn (mut session Session) write_string(x i16, y i16, str string) {
	C.mvaddstr(y, x, str.str)
}

pub fn (mut session Session) get_char() ?byte {
	if !session.config.use_keyboard {
		return error('Keyboard usage is not enabled!')
	}
	ch := C.getch()
	return byte(ch)
}

pub fn (mut session Session) move(x i16, y i16) {
	C.wmove(session.mainwin, y, x)
}

pub fn (mut session Session) clear_line(line i16) {
	C.winsdelln(session.mainwin, line)
}
