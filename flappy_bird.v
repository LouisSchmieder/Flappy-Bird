module main

import ncurses
import time
import rand
import rand.seed

const (
	playfield_width  = 100
	playfield_height = 30
	framerate        = 30
)

struct App {
mut:
	session          ncurses.Session
	buffer0          [][]bool
	buffer1          [][]bool
	cur_buf          bool
	framerate        int
	frames           int
	player           Player
	global_offset    int = 40
	last             int
	next_to_recreate int
	sprites          [3]DoubleSprite
	alive            bool
}

struct DoubleSprite {
mut:
	top_sprite    Sprite
	bottom_sprite Sprite
	hitted        bool
}

struct Sprite {
mut:
	x      f32
	y      f32
	height int
	width  int
}

struct Player {
	Sprite
mut:
	score int
}

fn main() {
	mut app := App{}
	mut session := ncurses.create_session(use_keyboard: true) or { panic(err) }
	app.session = session

	app.create_border()

	app.buffer0 = [][]bool{len: playfield_height, init: []bool{len: playfield_width}}
	app.buffer1 = [][]bool{len: playfield_height, init: []bool{len: playfield_width}}
	app.cur_buf = false
	app.alive = true
	ncurses.curs_set(0) or { panic(err) }

	app.player = Player{}
	app.player.x = 10
	app.player.y = (playfield_height - 4) / 2
	app.player.height = 4
	app.player.width = 5

	app.sprites[0] = DoubleSprite{
		top_sprite: Sprite{
			x: app.last + 0
			y: 0
			height: 10
			width: 10
		}
		bottom_sprite: Sprite{
			x: app.last + 0
			y: 20
			height: 10
			width: 10
		}
	}

	app.last += 10
	app.sprites[1] = app.create_sprite()

	app.sprites[2] = app.create_sprite()

	go render(&app)
	go framerate(&app)
	go input(&app)
	go physics(&app)
	go game_logic(&app)

	for app.alive {
		// draw player
		app.draw_rect(int(app.player.x), int(app.player.y), app.player.width, app.player.height)

		// draw sprites
		app.draw_rect(int(app.sprites[0].top_sprite.x + app.global_offset), int(app.sprites[0].top_sprite.y),
			app.sprites[0].top_sprite.width, app.sprites[0].top_sprite.height)
		app.draw_rect(int(app.sprites[0].bottom_sprite.x + app.global_offset), int(app.sprites[0].bottom_sprite.y),
			app.sprites[0].bottom_sprite.width, app.sprites[0].bottom_sprite.height)

		app.draw_rect(int(app.sprites[1].top_sprite.x + app.global_offset), int(app.sprites[1].top_sprite.y),
			app.sprites[1].top_sprite.width, app.sprites[1].top_sprite.height)
		app.draw_rect(int(app.sprites[1].bottom_sprite.x + app.global_offset), int(app.sprites[1].bottom_sprite.y),
			app.sprites[1].bottom_sprite.width, app.sprites[1].bottom_sprite.height)

		app.draw_rect(int(app.sprites[2].top_sprite.x + app.global_offset), int(app.sprites[2].top_sprite.y),
			app.sprites[2].top_sprite.width, app.sprites[2].top_sprite.height)
		app.draw_rect(int(app.sprites[2].bottom_sprite.x + app.global_offset), int(app.sprites[2].bottom_sprite.y),
			app.sprites[2].bottom_sprite.width, app.sprites[2].bottom_sprite.height)
	}
	app.session.close_session()
}

fn (mut app App) draw_rect(x int, y int, width int, height int) {
	for yy in 0 .. height {
		for xx in 0 .. width {
			app.draw(x + xx, y + yy)
		}
	}
}

fn (mut app App) draw(x int, y int) {
	if x > -1 && x < playfield_width && y > -1 && y < playfield_height {
		if app.cur_buf {
			app.buffer0[y][x] = true
		} else {
			app.buffer1[y][x] = true
		}
	}
}

fn (mut app App) create_border() {
	// border
	app.session.write_string(0, 0, '#'.repeat(playfield_width + 1))
	for i in 0 .. playfield_height + 1 {
		app.session.write_string(0, i, '#')
		app.session.write_string(playfield_width + 1, i, '#')
	}
	app.session.write_string(0, playfield_height + 1, '#'.repeat(playfield_width + 2))
	app.session.move(0, playfield_height + 2)
	app.session.refresh()
}

fn framerate(data voidptr) {
	mut app := &App(data)
	for app.alive {
		time.sleep(time.second)
		app.framerate = app.frames
		app.frames = 0
	}
}

fn input(data voidptr) {
	mut app := &App(data)
	for app.alive {
		ch := app.session.get_char() or { ` ` }

		if ch == 32 {
			if app.player.y - 1 > 0 {
				app.player.y -= 2
			}
		}
	}
}

fn physics(data voidptr) {
	mut app := &App(data)
	for app.alive {
		if app.player.y + f32(app.player.height) < f32(playfield_height) {
			if app.player.y + 0.4 >= f32(playfield_height) {
				app.player.y = f32(playfield_height)
			} else {
				app.player.y += 0.4
			}
		}
		time.sleep(time.millisecond * 200)
	}
}

fn game_logic(data voidptr) {
	mut app := &App(data)
	for app.alive {
		app.global_offset--

		if app.sprites[app.next_to_recreate].top_sprite.x +
			app.sprites[app.next_to_recreate].top_sprite.width + app.global_offset <= 0 {
			app.sprites[app.next_to_recreate] = app.create_sprite()
			app.next_to_recreate++
			if app.next_to_recreate >= 3 {
				app.next_to_recreate = 0
			}
		}

		// Dead

		if int(app.player.y) + app.player.height == playfield_height {
			app.alive = false
		}

		// Detect collision
		if app.collide(0) || app.collide(1) || app.collide(2) {
			app.alive = false
		}

		time.sleep(time.millisecond * 200)
	}
}

fn (mut app App) collide(sprite int) bool {
	pl := app.player.x // player left
	pr := app.player.x + app.player.width // player right
	pty := app.player.y // player top y
	pby := app.player.y + app.player.height // player bottom y

	mut ds := app.sprites[sprite]

	ts := ds.top_sprite
	sl := ts.x + app.global_offset // sprite left
	sr := ts.x + ts.width + app.global_offset // sprite right
	sh := ts.height // sprite height

	bsy := ds.bottom_sprite.y // bottom sprite y

	if (pl >= sl && pl <= sr) || (pr >= sl && pr <= sr) {
		// inside x
		if pty <= sh || pby >= bsy {
			return true
		}
		if !ds.hitted {
			ds.hitted = true
			app.player.score++
			app.sprites[sprite] = ds
		}
	}
	return false
}

fn (mut app App) create_sprite() DoubleSprite {
	seed.time_seed_32()
	height := rand.int_in_range(2, 18)
	ds := DoubleSprite{
		top_sprite: Sprite{
			x: app.last + 40
			y: 0
			width: 10
			height: height
		}
		bottom_sprite: Sprite{
			x: app.last + 40
			y: height + 10
			width: 10
			height: playfield_height - height + 10
		}
	}
	app.last += 50
	return ds
}

fn render(data voidptr) {
	mut app := &App(data)
	for app.alive {
		buf := if app.cur_buf { app.buffer1 } else { app.buffer0 }
		for y, line in buf {
			mut str := ''
			for dd in line {
				mut d := ' '
				if dd {
					d = '#'
				}
				str += d
			}
			app.session.write_string(1, i16(y + 1), str)
		}
		unsafe {
			buf.free()
		}
		mut spaces := 4 - app.framerate.str().len
		mut s := 4 - app.player.score.str().len
		app.session.write_string(0, playfield_height + 3, 'Score: ${' '.repeat(s)}$app.player.score    FPS: ${' '.repeat(spaces)}$app.framerate')
		app.session.refresh()
		if app.cur_buf {
			app.buffer1 = [][]bool{len: playfield_height, init: []bool{len: playfield_width}}
		} else {
			app.buffer0 = [][]bool{len: playfield_height, init: []bool{len: playfield_width}}
		}
		app.cur_buf = !app.cur_buf
		app.frames++
		time.sleep(time.millisecond * i64(1000 / framerate))
	}
}
