extends RefCounted
class_name TextureFactory

static var cache := {}

static func cube_texture(type: String) -> Texture:
	if cache.has(type):
		return cache[type]
	var path := ""
	match type:
		Constants.GRASS: path = "res://assets/texture/grass_top.jpg"
		Constants.ICE: path = "res://assets/texture/ice.jpeg"
		Constants.FIRE: path = "res://assets/texture/fire.png"
		Constants.TNT: path = "res://assets/texture/tnt_top.jpg"
		Constants.START: path = "res://assets/texture/start_top.jpg"
		Constants.END: path = "res://assets/texture/end_top.jpg"
		Constants.HEART: path = ""  # procedural only
	var tex: Texture = null
	if path != "":
		tex = load(path)
		if tex == null:
			tex = make(type)
	else:
		tex = make(type)
	cache[type] = tex
	return tex

static func color_from_hex(h: int) -> Color:
	return Color(
		float((h >> 16) & 0xff) / 255.0,
		float((h >> 8) & 0xff) / 255.0,
		float(h & 0xff) / 255.0, 1.0)

static func make(type: String) -> ImageTexture:
	var S = 64
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	var base = 0x4caf50
	var dark = 0x2e7d32
	match type:
		Constants.ICE:
			base = 0x3aa0ef; dark = 0x1565c0
		Constants.FIRE:
			base = 0xff9d2e; dark = 0xe65100
		Constants.TNT:
			base = 0xc62828; dark = 0x4a0000
		Constants.HEART:
			base = 0xe91e63; dark = 0x880e4f
		Constants.START:
			base = 0x57c25b; dark = 0x2e7d32
		Constants.END:
			base = 0xffd24a; dark = 0xc79100
	var cbase = color_from_hex(base)
	var cdark = color_from_hex(dark)
	img.fill(cbase)

	match type:
		Constants.GRASS, Constants.START:
			for y in range(0, S, 16):
				for x in range(0, S, 16):
					img.set_pixel(x + 2, y + 2, cdark)
					img.set_pixel(x + 3, y + 3, cdark)
					img.set_pixel(x + 4, y + 4, cdark)
		Constants.ICE:
			for i in range(-S, S * 2, 12):
				for t in range(-1, 2):
					var x = i + t
					var y = -i + t * 2
					for k in range(0, S):
						var px = int(x + k)
						var py = int((y + k) * 0.5 + k * 0.5)
						if px >= 0 and px < S and py >= 0 and py < S:
							img.set_pixel(px, py, Color(1, 1, 1, 0.35))
		Constants.FIRE:
			for i in range(14):
				var cx = (i * 97) % S
				var cy = (i * 53) % S
				var r = 14 + (i % 4) * 6
				_draw_circle(img, cx, cy, r, cdark)
			_draw_circle(img, 32, 32, 20, Color(1, 1, 1, 0.18))
		Constants.TNT:
			for x in range(0, S):
				for y in range(24, 40):
					img.set_pixel(x, y, cdark)
			for x in range(4, S - 4):
				for y in range(4, S - 4):
					if (x == 4 or x == S - 5 or y == 4 or y == S - 5):
						img.set_pixel(x, y, Color(1, 1, 1, 0.4))
		Constants.HEART:
			for i in range(28):
				var a = float(i) / 28.0 * TAU
				var hx = 32 + cos(a) * 16
				var hy = 38 + sin(a) * 16
				_draw_circle(img, int(hx), int(hy), 10, Color(1, 1, 1, 0.9))
		Constants.END:
			for y in range(0, S, 12):
				for x in range(0, S, 12):
					img.set_pixel(x + 2, y + 2, cdark)

	var tex = ImageTexture.create_from_image(img)
	tex.set("resource_local_to_scene", false)
	return tex

static func _draw_circle(img: Image, cx: int, cy: int, r: int, col: Color):
	for y in range(max(0, cy - r), min(img.get_height(), cy + r)):
		for x in range(max(0, cx - r), min(img.get_width(), cx + r)):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, col)
