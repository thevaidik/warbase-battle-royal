extends Control
## Static canvas details; redraw only on resize, never on a frame timer.
var accent := Color("c6ff5a")
var backdrop := false
var bleed := Vector4.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if backdrop:
		var grid := Color(0.36, 0.56, 0.56, 0.045)
		for x in range(0, int(size.x), 64): draw_line(Vector2(x, 0), Vector2(x, size.y), grid)
		for y in range(0, int(size.y), 64): draw_line(Vector2(0, y), Vector2(size.x, y), grid)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.65, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.6)]), Color(0.25, 0.42, 0.43, 0.035))
		return
	var c := Color(accent, 0.8)
	var inset := 1.0
	var length := 14.0
	var start := Vector2(-bleed.x + inset, -bleed.y + inset)
	var end := size + Vector2(bleed.z - inset, bleed.w - inset)
	for p in [start, Vector2(end.x, start.y), Vector2(start.x, end.y), end]:
		var sx := 1.0 if p.x < size.x * 0.5 else -1.0
		var sy := 1.0 if p.y < size.y * 0.5 else -1.0
		draw_line(p, p + Vector2(length * sx, 0), c, 1)
		draw_line(p, p + Vector2(0, length * sy), c, 1)
	for i in range(6):
		var x := end.x - 14 - i * 7
		draw_line(Vector2(x, end.y - 7), Vector2(x - 3, end.y - 3), Color(accent, 0.3), 2)
