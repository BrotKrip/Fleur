extends RefCounted
## Грани литых оправ и эмалевые индикаторы для карточек и активностей.

const BRASS := Color("b89258")
const HIGHLIGHT := Color("ffe3a2")
const INK := Color("101923")
const IVORY := Color("fcf2d9")


static func cut(rect: Rect2, corner: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([a + Vector2(corner, 0), Vector2(b.x - corner, a.y),
		Vector2(b.x, a.y + corner), b - Vector2(0, corner), b - Vector2(corner, 0),
		Vector2(a.x + corner, b.y), Vector2(a.x, b.y - corner), a + Vector2(0, corner)])


static func metal(ci: CanvasItem, rect: Rect2, corner: float, gauge: float, tint := BRASS) -> void:
	var outside := cut(rect, corner)
	var inside := cut(rect.grow(-gauge), maxf(1, corner - gauge * 0.55))
	bevel(ci, outside, inside, tint)


static func bevel(ci: CanvasItem, outside: PackedVector2Array, inside: PackedVector2Array, tint: Color) -> void:
	for i in outside.size():
		var j := (i + 1) % outside.size()
		var normal := (outside[j] - outside[i]).normalized().rotated(-PI / 2)
		var light := 0.5 + normal.dot(Vector2(-0.6, -0.8)) * 0.47
		var facet := tint.darkened(0.65).lerp(tint.lightened(0.53), light)
		ci.draw_colored_polygon(PackedVector2Array([outside[i], outside[j], inside[j], inside[i]]), facet)
	Look.outline(ci, outside, Color("181414"), 1.6)
	Look.outline(ci, inside, tint.lightened(0.4), 1.0)


static func panel(ci: CanvasItem, rect: Rect2, base: Color, corner := 15.0) -> void:
	var shape := cut(rect, corner)
	Look.soft_shadow(ci, shape, Vector2(0, 5), 6, 0.52)
	Look.fill_v(ci, shape, base.lightened(0.12), base.darkened(0.45))
	metal(ci, rect, corner, 3, BRASS)


static func gem(ci: CanvasItem, c: Vector2, r: float, ink: Color, lit := true) -> void:
	var socket := Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2)
	var outer := cut(socket, r * 0.53)
	ci.draw_colored_polygon(Look.offset(outer, Vector2(0, 2)), Color("10131a"))
	Look.fill_v(ci, outer, BRASS.lightened(0.42), BRASS.darkened(0.54))
	var jewel := cut(socket.grow(-r * 0.17), r * 0.43)
	var center := c + Vector2(-1, -r * 0.19)
	for i in jewel.size():
		var j := (i + 1) % jewel.size()
		var shine := (0.46 - absf(float(i) - 3.5) * 0.18) if lit else -0.47
		var facet := ink.lightened(maxf(0, shine)).darkened(maxf(0, -shine))
		ci.draw_colored_polygon(PackedVector2Array([jewel[i], jewel[j], center]), facet)
	Look.outline(ci, jewel, Color(ink.lightened(0.6), 0.8), 1.0)


static func iris(ci: CanvasItem, c: Vector2, scale: float, color: Color) -> void:
	var petal := PackedVector2Array([Vector2(0, 4), Vector2(-2, 0), Vector2(-1.5, -4), Vector2(0, -7),
		Vector2(1.5, -4), Vector2(2, 0)])
	for angle in [-0.96, 0.0, 0.96]:
		var shape := PackedVector2Array()
		for point in petal:
			shape.append(c + point.rotated(angle) * scale)
		ci.draw_colored_polygon(shape, color)
	ci.draw_line(c + Vector2(-4, 2) * scale, c + Vector2(4, 2) * scale, color, 1.2, true)


static func dial(ci: CanvasItem, c: Vector2, r: float, fill: float, ink: Color, value: String) -> void:
	var start := PI * 0.75
	var sweep := PI * 1.5
	ci.draw_circle(c + Vector2(0, 3), r + 1, Color(0, 0, 0, 0.5), true, -1, true)
	ci.draw_circle(c, r, BRASS, true, -1, true)
	ci.draw_circle(c, r - 2, INK, true, -1, true)
	ci.draw_arc(c, r - 6, start, start + sweep, 38, Color("48515a"), 4, true)
	var pct := clampf(fill, 0.0, 1.0)
	if pct > 0:
		ci.draw_arc(c, r - 6, start, start + sweep * pct, 38, ink, 4, true)
		ci.draw_arc(c, r - 8, start, start + sweep * pct, 38, ink.lightened(0.45), 1, true)
	for i in 5:
		var tick := Vector2.from_angle(start + sweep * i / 4.0)
		ci.draw_line(c + tick * (r - 11), c + tick * (r - 14), Color("90909a"), 1, true)
	var fs := roundi(r * (0.77 if value.length() <= 2 else 0.56))
	Look.text_c(ci, Look.font("display_bold"), c.x, c.y + fs * 0.32, value, fs, IVORY, (r - 9) * 2)


static func blades(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for side in [-1.0, 1.0]:
		var axis := Vector2(side * 0.62, -0.78)
		var cross := axis.orthogonal()
		var hilt := c - axis * r * 0.46
		var tip := c + axis * r * 0.91
		ci.draw_colored_polygon(PackedVector2Array([tip, hilt + cross * r * 0.12,
			hilt - axis * r * 0.1, hilt - cross * r * 0.12]), color)
		ci.draw_line(hilt - cross * r * 0.25, hilt + cross * r * 0.25, color, 2.2, true)
		ci.draw_line(hilt, hilt - axis * r * 0.28, color, 2, true)
