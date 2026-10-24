extends RefCounted
## The stickers for the sticker book (daily.gd hands them out), and how to
## draw each one: a round sticker with a white edge and a little picture,
## all made of simple shapes. Rare ones have a gold edge and sparkle.

## Sticker id -> name and background colour. The rare ones come from the
## surprise box for finishing all of a day's tasks.
const COMMON := {
	"carrot": ["Carrot", Color(1.0, 0.9, 0.75)], "apple": ["Apple", Color(0.85, 0.95, 0.8)],
	"horseshoe": ["Horseshoe", Color(0.85, 0.9, 1.0)], "heart": ["Heart", Color(1.0, 0.85, 0.9)],
	"star": ["Star", Color(0.8, 0.85, 1.0)], "rosette": ["Rosette", Color(0.95, 0.92, 0.8)],
	"cup": ["Cup", Color(0.82, 0.9, 0.98)], "flower": ["Flower", Color(0.85, 0.95, 0.85)],
	"sun": ["Sunshine", Color(0.75, 0.88, 1.0)], "moon": ["Moon", Color(0.3, 0.32, 0.55)],
	"rainbow": ["Rainbow", Color(0.8, 0.92, 1.0)], "clover": ["Lucky clover", Color(0.95, 0.95, 0.85)],
	"mushroom": ["Mushroom", Color(0.85, 0.95, 0.8)], "butterfly": ["Butterfly", Color(0.95, 0.9, 1.0)],
	"snowflake": ["Snowflake", Color(0.6, 0.75, 0.95)], "shell": ["Seashell", Color(0.75, 0.9, 0.95)],
	"leaf": ["Autumn leaf", Color(0.98, 0.93, 0.8)], "cherries": ["Cherries", Color(1.0, 0.95, 0.85)],
	"bow": ["Bow", Color(0.85, 0.9, 1.0)], "cloud": ["Cloud", Color(0.6, 0.8, 1.0)],
	"horse": ["Horse", Color(0.85, 0.95, 0.85)], "helmet": ["Riding hat", Color(1.0, 0.9, 0.85)],
	"bird": ["Bluebird", Color(0.95, 0.95, 0.85)], "icecream": ["Ice cream", Color(1.0, 0.88, 0.92)],
}
const RARE := {
	"unicorn": ["Unicorn", Color(0.95, 0.85, 1.0)], "gold_shoe": ["Golden horseshoe", Color(0.98, 0.95, 0.85)],
	"crown": ["Crown", Color(0.92, 0.85, 1.0)], "rainbow_star": ["Rainbow star", Color(0.85, 0.85, 0.98)],
	"pegasus": ["Pegasus", Color(0.8, 0.9, 1.0)], "diamond": ["Diamond", Color(0.85, 0.95, 1.0)],
}

const INK := Color(0.2, 0.14, 0.18)
const GOLD := Color(1.0, 0.8, 0.25)
const RAINBOW := [Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 0.88, 0.3),
	Color(0.4, 0.8, 0.35), Color(0.35, 0.6, 1.0), Color(0.6, 0.4, 0.9)]


static func all_ids() -> Array:
	return COMMON.keys() + RARE.keys()


static func is_rare(id: String) -> bool:
	return RARE.has(id)


static func sticker_name(id: String) -> String:
	return (RARE[id] if RARE.has(id) else COMMON[id])[0]


## Draw sticker `id` on `c`, centred at `at`, `r` pixels round. A sticker
## not yet found is a grey shape with a question mark.
static func draw(c: CanvasItem, id: String, at: Vector2, r: float, owned := true, time := 0.0) -> void:
	var rare := RARE.has(id)
	c.draw_circle(at + Vector2(r * 0.05, r * 0.08), r, Color(0, 0, 0, 0.25))   # Shadow
	if not owned:
		c.draw_circle(at, r, Color(1, 1, 1, 0.18))
		c.draw_arc(at, r - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		var font := ThemeDB.fallback_font
		var size := int(r * 0.9)
		var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		c.draw_string(font, at + Vector2(-w * 0.5, size * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.5))
		return
	var back: Color = (RARE[id] if rare else COMMON[id])[1]
	c.draw_circle(at, r, GOLD if rare else Color.WHITE)          # The sticker's edge
	c.draw_circle(at, r * 0.88, back)
	_picture(c, id, at, r * 0.8)
	if rare:
		for k in 4:
			var a := time * 1.5 + k * TAU / 4.0
			_sparkle(c, at + Vector2(cos(a), sin(a)) * r * 0.78, r * 0.11 * (0.7 + 0.3 * sin(time * 4.0 + k)))


static func _picture(c: CanvasItem, id: String, o: Vector2, s: float) -> void:
	match id:
		"carrot":
			c.draw_colored_polygon(_pts(o, s, [[-0.15, -0.35], [0.2, -0.3], [0.05, 0.7]]), Color(1.0, 0.55, 0.15))
			for k in 3:
				c.draw_line(o + Vector2(-0.02 + k * 0.08, -0.32) * s, o + Vector2(-0.25 + k * 0.25, -0.7) * s, Color(0.3, 0.65, 0.2), s * 0.09)
			for k in 3:
				c.draw_line(o + Vector2(-0.05, -0.05 + k * 0.2) * s, o + Vector2(0.08, -0.03 + k * 0.2) * s, Color(0.85, 0.4, 0.1), s * 0.03)
		"apple":
			c.draw_circle(o + Vector2(-0.18, 0.1) * s, s * 0.42, Color(0.85, 0.15, 0.15))
			c.draw_circle(o + Vector2(0.18, 0.1) * s, s * 0.42, Color(0.85, 0.15, 0.15))
			c.draw_circle(o + Vector2(-0.22, -0.05) * s, s * 0.1, Color(1, 1, 1, 0.5))
			c.draw_line(o + Vector2(0, -0.25) * s, o + Vector2(0.05, -0.55) * s, Color(0.4, 0.25, 0.1), s * 0.07)
			c.draw_colored_polygon(_pts(o, s, [[0.05, -0.45], [0.4, -0.6], [0.2, -0.35]]), Color(0.3, 0.65, 0.2))
		"horseshoe", "gold_shoe":
			var metal := GOLD if id == "gold_shoe" else Color(0.6, 0.62, 0.68)
			c.draw_arc(o + Vector2(0, -0.05) * s, s * 0.45, PI * 0.82, PI * 2.18, 24, metal, s * 0.22, true)
			for k in 6:
				var a := PI * (0.95 + k * 0.22)
				c.draw_circle(o + Vector2(0, -0.05) * s + Vector2(cos(a), sin(a)) * s * 0.45, s * 0.035, INK)
			if id == "gold_shoe":
				_sparkle(c, o + Vector2(0.35, -0.45) * s, s * 0.14)
		"heart":
			_heart(c, o, s * 0.95, Color(0.95, 0.25, 0.45))
		"star":
			c.draw_colored_polygon(_star(o, s * 0.75, s * 0.32), Color(1.0, 0.8, 0.2))
		"rainbow_star":
			for k in RAINBOW.size():
				c.draw_colored_polygon(_star(o, s * (0.8 - k * 0.11), s * (0.34 - k * 0.048)), RAINBOW[k])
		"rosette":
			for k in 12:
				var a := k * TAU / 12.0
				c.draw_circle(o + Vector2(0, -0.15) * s + Vector2(cos(a), sin(a)) * s * 0.3, s * 0.18, Color(0.35, 0.55, 0.95))
			c.draw_colored_polygon(_pts(o, s, [[-0.2, 0.1], [-0.05, 0.1], [-0.15, 0.75], [-0.3, 0.65]]), Color(0.3, 0.5, 0.9))
			c.draw_colored_polygon(_pts(o, s, [[0.05, 0.1], [0.2, 0.1], [0.3, 0.65], [0.15, 0.75]]), Color(0.3, 0.5, 0.9))
			c.draw_circle(o + Vector2(0, -0.15) * s, s * 0.26, Color(1.0, 0.85, 0.3))
		"cup":
			c.draw_colored_polygon(_pts(o, s, [[-0.4, -0.55], [0.4, -0.55], [0.3, 0.0], [0.08, 0.15], [-0.08, 0.15], [-0.3, 0.0]]), GOLD)
			c.draw_arc(o + Vector2(-0.4, -0.3) * s, s * 0.17, PI * 0.5, PI * 1.5, 12, GOLD, s * 0.07)
			c.draw_arc(o + Vector2(0.4, -0.3) * s, s * 0.17, -PI * 0.5, PI * 0.5, 12, GOLD, s * 0.07)
			c.draw_rect(Rect2(o + Vector2(-0.06, 0.15) * s, Vector2(0.12, 0.3) * s), GOLD.darkened(0.15))
			c.draw_rect(Rect2(o + Vector2(-0.3, 0.45) * s, Vector2(0.6, 0.15) * s), Color(0.45, 0.3, 0.2))
		"flower":
			c.draw_line(o + Vector2(0, 0.1) * s, o + Vector2(0, 0.75) * s, Color(0.3, 0.6, 0.2), s * 0.08)
			for k in 6:
				var a := k * TAU / 6.0
				c.draw_circle(o + Vector2(0, -0.15) * s + Vector2(cos(a), sin(a)) * s * 0.3, s * 0.2, Color(1.0, 0.5, 0.75))
			c.draw_circle(o + Vector2(0, -0.15) * s, s * 0.18, Color(1.0, 0.85, 0.3))
		"sun":
			for k in 10:
				var a := k * TAU / 10.0
				c.draw_line(o + Vector2(cos(a), sin(a)) * s * 0.45, o + Vector2(cos(a), sin(a)) * s * 0.75, Color(1.0, 0.7, 0.15), s * 0.1)
			c.draw_circle(o, s * 0.4, Color(1.0, 0.82, 0.25))
			c.draw_circle(o + Vector2(-0.13, -0.06) * s, s * 0.05, INK)
			c.draw_circle(o + Vector2(0.13, -0.06) * s, s * 0.05, INK)
			c.draw_arc(o + Vector2(0, 0.02) * s, s * 0.17, 0.3, PI - 0.3, 10, INK, s * 0.04)
		"moon":
			var crescent := PackedVector2Array()
			for k in 17:
				var a := -PI * 0.5 + k * PI / 16.0
				crescent.append(o + Vector2(cos(a) * 0.6, sin(a) * 0.6) * s)
			for k in 17:
				var a := PI * 0.5 - k * PI / 16.0
				crescent.append(o + Vector2(cos(a) * 0.25, sin(a) * 0.6) * s)
			c.draw_colored_polygon(crescent, Color(1.0, 0.92, 0.55))
			_sparkle(c, o + Vector2(-0.4, -0.35) * s, s * 0.12)
			_sparkle(c, o + Vector2(-0.3, 0.4) * s, s * 0.08)
		"rainbow":
			for k in RAINBOW.size():
				c.draw_arc(o + Vector2(0, 0.35) * s, s * (0.75 - k * 0.09), PI, TAU, 24, RAINBOW[k], s * 0.09, true)
			_cloud(c, o + Vector2(-0.55, 0.35) * s, s * 0.35)
			_cloud(c, o + Vector2(0.55, 0.35) * s, s * 0.35)
		"clover":
			c.draw_line(o, o + Vector2(0.15, 0.7) * s, Color(0.2, 0.55, 0.2), s * 0.08)
			for k in 4:
				var a := k * TAU / 4.0 + PI / 4.0
				_heart(c, o + Vector2(cos(a), sin(a)) * s * 0.28, s * 0.42, Color(0.3, 0.7, 0.3), a + PI / 2.0)
		"mushroom":
			c.draw_rect(Rect2(o + Vector2(-0.15, -0.05) * s, Vector2(0.3, 0.6) * s), Color(0.98, 0.95, 0.88))
			var cap := PackedVector2Array()
			for k in 17:
				var a := PI + k * PI / 16.0
				cap.append(o + Vector2(cos(a) * 0.6, sin(a) * 0.5 + 0.0) * s)
			c.draw_colored_polygon(cap, Color(0.9, 0.2, 0.2))
			for p in [[-0.3, -0.15], [0.05, -0.32], [0.3, -0.12]]:
				c.draw_circle(o + Vector2(p[0], p[1]) * s, s * 0.08, Color.WHITE)
		"butterfly":
			for side in [-1.0, 1.0]:
				c.draw_circle(o + Vector2(side * 0.3, -0.2) * s, s * 0.3, Color(0.6, 0.45, 0.95))
				c.draw_circle(o + Vector2(side * 0.25, 0.25) * s, s * 0.22, Color(1.0, 0.55, 0.8))
				c.draw_circle(o + Vector2(side * 0.32, -0.22) * s, s * 0.1, Color(1.0, 0.9, 0.4))
			c.draw_line(o + Vector2(0, -0.4) * s, o + Vector2(0, 0.45) * s, INK, s * 0.1)
			c.draw_line(o + Vector2(0, -0.4) * s, o + Vector2(-0.15, -0.65) * s, INK, s * 0.03)
			c.draw_line(o + Vector2(0, -0.4) * s, o + Vector2(0.15, -0.65) * s, INK, s * 0.03)
		"snowflake":
			for k in 6:
				var a := k * TAU / 6.0
				var tip := o + Vector2(cos(a), sin(a)) * s * 0.7
				c.draw_line(o, tip, Color.WHITE, s * 0.08)
				var mid := o + Vector2(cos(a), sin(a)) * s * 0.42
				for t in [-0.6, 0.6]:
					c.draw_line(mid, mid + Vector2(cos(a + t), sin(a + t)) * s * 0.2, Color.WHITE, s * 0.06)
		"shell":
			var fan := PackedVector2Array([o + Vector2(0, 0.5) * s])
			for k in 13:
				var a := PI + 0.25 + k * (PI - 0.5) / 12.0
				fan.append(o + Vector2(0, 0.15) * s + Vector2(cos(a), sin(a)) * s * 0.65)
			c.draw_colored_polygon(fan, Color(1.0, 0.72, 0.65))
			for k in 6:
				var a := PI + 0.4 + k * (PI - 0.8) / 5.0
				c.draw_line(o + Vector2(0, 0.5) * s, o + Vector2(0, 0.15) * s + Vector2(cos(a), sin(a)) * s * 0.6, Color(0.9, 0.5, 0.45), s * 0.04)
		"leaf":
			var outline := PackedVector2Array()
			for k in 25:
				var t := k / 24.0 * TAU
				outline.append(o + Vector2(sin(t) * 0.35 * (1.0 - 0.2 * cos(t)), -cos(t) * 0.62).rotated(0.5) * s)
			c.draw_colored_polygon(outline, Color(0.95, 0.5, 0.15))
			c.draw_line(o + Vector2(0, 0.62).rotated(0.5) * s, o + Vector2(0, -0.55).rotated(0.5) * s, Color(0.7, 0.3, 0.1), s * 0.05)
		"cherries":
			c.draw_line(o + Vector2(-0.25, 0.25) * s, o + Vector2(0.1, -0.55) * s, Color(0.35, 0.5, 0.2), s * 0.06)
			c.draw_line(o + Vector2(0.3, 0.2) * s, o + Vector2(0.1, -0.55) * s, Color(0.35, 0.5, 0.2), s * 0.06)
			c.draw_colored_polygon(_pts(o, s, [[0.1, -0.55], [0.45, -0.65], [0.3, -0.45]]), Color(0.3, 0.65, 0.2))
			for p in [[-0.25, 0.35], [0.3, 0.3]]:
				c.draw_circle(o + Vector2(p[0], p[1]) * s, s * 0.25, Color(0.8, 0.08, 0.15))
				c.draw_circle(o + Vector2(p[0] - 0.08, p[1] - 0.08) * s, s * 0.06, Color(1, 1, 1, 0.6))
		"bow":
			c.draw_colored_polygon(_pts(o, s, [[0, 0], [-0.65, -0.4], [-0.65, 0.4]]), Color(0.95, 0.35, 0.55))
			c.draw_colored_polygon(_pts(o, s, [[0, 0], [0.65, -0.4], [0.65, 0.4]]), Color(0.95, 0.35, 0.55))
			c.draw_colored_polygon(_pts(o, s, [[-0.05, 0.05], [-0.3, 0.7], [-0.15, 0.7]]), Color(0.85, 0.25, 0.45))
			c.draw_colored_polygon(_pts(o, s, [[0.05, 0.05], [0.3, 0.7], [0.15, 0.7]]), Color(0.85, 0.25, 0.45))
			c.draw_circle(o, s * 0.14, Color(0.85, 0.25, 0.45))
		"cloud":
			_cloud(c, o + Vector2(0, 0.05) * s, s)
			for k in 4:
				c.draw_line(o + Vector2(-0.3 + k * 0.2, 0.45) * s, o + Vector2(-0.35 + k * 0.2, 0.65) * s, Color(0.3, 0.55, 1.0), s * 0.06)
		"horse", "unicorn", "pegasus":
			var coat := Color(0.6, 0.38, 0.22) if id == "horse" else Color(0.98, 0.97, 1.0)
			if id == "pegasus":
				c.draw_colored_polygon(_pts(o, s, [[0.2, 0.05], [0.75, -0.45], [0.7, -0.1], [0.8, 0.05], [0.6, 0.15], [0.65, 0.3], [0.35, 0.3]]), Color(0.85, 0.92, 1.0))
			c.draw_colored_polygon(_pts(o, s, [[0.35, 0.7], [0.25, 0.1], [0.1, -0.35], [-0.05, -0.55], [-0.15, -0.5],
				[-0.55, 0.05], [-0.62, 0.22], [-0.5, 0.3], [-0.2, 0.15], [-0.15, 0.7]]), coat)
			c.draw_colored_polygon(_pts(o, s, [[-0.1, -0.5], [-0.02, -0.7], [0.05, -0.48]]), coat)
			c.draw_circle(o + Vector2(-0.18, -0.18) * s, s * 0.05, INK)
			c.draw_circle(o + Vector2(-0.52, 0.18) * s, s * 0.03, INK)
			if id == "unicorn":
				c.draw_colored_polygon(_pts(o, s, [[-0.2, -0.45], [-0.45, -0.85], [-0.08, -0.5]]), GOLD)
				for k in 4:
					c.draw_circle(o + Vector2(0.15 + k * 0.05, -0.4 + k * 0.25) * s, s * 0.14, RAINBOW[(k * 2) % RAINBOW.size()])
			else:
				for k in 4:
					c.draw_circle(o + Vector2(0.15 + k * 0.05, -0.4 + k * 0.25) * s, s * 0.12, Color(0.35, 0.22, 0.14) if id == "horse" else Color(0.75, 0.82, 0.95))
		"helmet":
			var dome := PackedVector2Array()
			for k in 17:
				var a := PI + k * PI / 16.0
				dome.append(o + Vector2(cos(a) * 0.55, sin(a) * 0.55 + 0.15) * s)
			c.draw_colored_polygon(dome, Color(0.2, 0.25, 0.45))
			c.draw_colored_polygon(_pts(o, s, [[-0.55, 0.15], [0.75, 0.15], [0.7, 0.28], [-0.55, 0.25]]), Color(0.15, 0.18, 0.35))
			c.draw_circle(o + Vector2(0, -0.4) * s, s * 0.08, Color(0.9, 0.3, 0.5))
		"bird":
			c.draw_circle(o, s * 0.45, Color(0.35, 0.6, 1.0))
			c.draw_circle(o + Vector2(0.05, 0.15) * s, s * 0.28, Color(0.9, 0.95, 1.0))
			c.draw_colored_polygon(_pts(o, s, [[-0.1, 0.0], [-0.65, -0.35], [-0.45, 0.15]]), Color(0.25, 0.45, 0.85))
			c.draw_colored_polygon(_pts(o, s, [[0.4, -0.15], [0.7, -0.05], [0.4, 0.02]]), Color(1.0, 0.65, 0.2))
			c.draw_circle(o + Vector2(0.2, -0.15) * s, s * 0.06, INK)
		"icecream":
			c.draw_colored_polygon(_pts(o, s, [[-0.3, 0.0], [0.3, 0.0], [0.0, 0.75]]), Color(0.85, 0.62, 0.35))
			c.draw_circle(o + Vector2(-0.15, -0.1) * s, s * 0.25, Color(1.0, 0.7, 0.8))
			c.draw_circle(o + Vector2(0.15, -0.1) * s, s * 0.25, Color(0.6, 0.4, 0.25))
			c.draw_circle(o + Vector2(0, -0.35) * s, s * 0.25, Color(0.98, 0.95, 0.85))
			c.draw_circle(o + Vector2(0, -0.62) * s, s * 0.08, Color(0.85, 0.1, 0.15))
		"crown":
			c.draw_colored_polygon(_pts(o, s, [[-0.6, 0.4], [-0.65, -0.35], [-0.3, 0.0], [0.0, -0.55], [0.3, 0.0], [0.65, -0.35], [0.6, 0.4]]), GOLD)
			for p in [[-0.65, -0.35], [0.0, -0.55], [0.65, -0.35]]:
				c.draw_circle(o + Vector2(p[0], p[1]) * s, s * 0.08, GOLD)
			c.draw_circle(o + Vector2(0, 0.15) * s, s * 0.11, Color(0.9, 0.15, 0.3))
			c.draw_circle(o + Vector2(-0.35, 0.18) * s, s * 0.08, Color(0.3, 0.55, 1.0))
			c.draw_circle(o + Vector2(0.35, 0.18) * s, s * 0.08, Color(0.3, 0.8, 0.4))
		"diamond":
			c.draw_colored_polygon(_pts(o, s, [[-0.6, -0.2], [-0.3, -0.55], [0.3, -0.55], [0.6, -0.2], [0.0, 0.65]]), Color(0.55, 0.85, 1.0))
			c.draw_colored_polygon(_pts(o, s, [[-0.3, -0.55], [0.0, -0.2], [0.3, -0.55]]), Color(0.8, 0.95, 1.0))
			c.draw_colored_polygon(_pts(o, s, [[-0.6, -0.2], [0.0, -0.2], [0.0, 0.65]]), Color(0.4, 0.7, 0.95))
			_sparkle(c, o + Vector2(0.45, -0.55) * s, s * 0.15)


static func _pts(o: Vector2, s: float, points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(o + Vector2(p[0], p[1]) * s)
	return out


static func _star(o: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 10:
		var r := outer if k % 2 == 0 else inner
		var a := -PI / 2.0 + k * PI / 5.0
		out.append(o + Vector2(cos(a), sin(a)) * r)
	return out


static func _heart(c: CanvasItem, o: Vector2, s: float, color: Color, turn := 0.0) -> void:
	var out := PackedVector2Array()
	for k in 32:
		var t := k / 32.0 * TAU
		var p := Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) / 34.0
		out.append(o + p.rotated(turn) * s)
	c.draw_colored_polygon(out, color)


static func _cloud(c: CanvasItem, o: Vector2, s: float) -> void:
	for p in [[-0.3, 0.05, 0.25], [0.0, -0.1, 0.32], [0.3, 0.05, 0.25], [0.0, 0.12, 0.25]]:
		c.draw_circle(o + Vector2(p[0], p[1]) * s, s * p[2], Color.WHITE)


static func _sparkle(c: CanvasItem, at: Vector2, size: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.25, -size * 0.25),
		at + Vector2(size, 0), at + Vector2(size * 0.25, size * 0.25), at + Vector2(0, size),
		at + Vector2(-size * 0.25, size * 0.25), at + Vector2(-size, 0), at + Vector2(-size * 0.25, -size * 0.25)]), Color(1, 1, 0.9))
