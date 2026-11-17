extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- GENERATING AAA MAP PREVIEW THUMBNAILS ---")
	generate_cosmodrome_preview()
	generate_dam_preview()
	generate_skyline_preview()
	print("--- MAP PREVIEW THUMBNAILS COMPLETE ---")
	quit(0)

func draw_line_dda(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var steps := maxi(absi(dx), absi(dy))
	if steps == 0:
		if x0 >= 0 and x0 < img.get_width() and y0 >= 0 and y0 < img.get_height():
			img.set_pixel(x0, y0, col)
		return
	var x_inc := float(dx) / float(steps)
	var y_inc := float(dy) / float(steps)
	var x := float(x0)
	var y := float(y0)
	for i in range(steps + 1):
		var px := int(round(x))
		var py := int(round(y))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, col)
		x += x_inc
		y += y_inc

func fill_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	var x_start := maxi(0, x0)
	var y_start := maxi(0, y0)
	var x_end := mini(img.get_width(), x0 + w)
	var y_end := mini(img.get_height(), y0 + h)
	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			img.set_pixel(x, y, col)

func fill_polygon_convex(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
	# Quick bounding box scanline fill for 4-point convex quads
	var min_y := int(maxf(0.0, minf(minf(p0.y, p1.y), minf(p2.y, p3.y))))
	var max_y := int(minf(float(img.get_height() - 1), maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))))
	var pts: Array[Vector2] = [p0, p1, p2, p3]
	for y in range(min_y, max_y + 1):
		var intersections: Array[float] = []
		for i in range(4):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 4]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				var t: float = (float(y) - a.y) / (b.y - a.y)
				intersections.append(a.x + t * (b.x - a.x))
		if intersections.size() >= 2:
			intersections.sort()
			var x_start := int(maxf(0.0, intersections[0]))
			var x_end := int(minf(float(img.get_width() - 1), intersections[intersections.size() - 1]))
			for x in range(x_start, x_end + 1):
				img.set_pixel(x, y, col)

# -----------------------------------------------------------------------------
# 1. COSMODROME PREVIEW (1100x550)
# -----------------------------------------------------------------------------
func generate_cosmodrome_preview() -> void:
	var w := 1100
	var h := 550
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var horizon_y := 340

	# Dawn Aerospace Sky Gradient
	for y in range(horizon_y):
		var t := float(y) / float(horizon_y)
		var sky_col := Color(0.10, 0.16, 0.30).lerp(Color(0.85, 0.52, 0.28), t * t)
		for x in range(w):
			img.set_pixel(x, y, sky_col)

	# Tarmac Apron Ground
	for y in range(horizon_y, h):
		var t := float(y - horizon_y) / float(h - horizon_y)
		var ground_col := Color(0.25, 0.26, 0.28).lerp(Color(0.16, 0.17, 0.18), t)
		for x in range(w):
			img.set_pixel(x, y, ground_col)

	# Ground Grid / Runway markings
	for x in range(0, w, 55):
		draw_line_dda(img, x, horizon_y, int(x * 1.5 - 275), h, Color(0.35, 0.36, 0.38, 0.4))
	for y_step in [370, 410, 460, 510]:
		draw_line_dda(img, 0, y_step, w - 1, y_step, Color(0.35, 0.36, 0.38, 0.4))

	# Launch Table Support Structure (Center X=520, W=220)
	fill_rect(img, 410, 270, 220, 70, Color(0.38, 0.37, 0.36))
	# Exhaust flame opening
	fill_rect(img, 470, 290, 100, 50, Color(0.12, 0.12, 0.12))

	# Flame exhaust deflector glow in trench
	for y in range(320, 390):
		var dy := (y - 320)
		fill_rect(img, 480 - dy, y, 80 + dy * 2, 1, Color(0.75, 0.35, 0.10, 0.5))

	# Gantry Service Tower (X=640, W=45, Height from Y=270 up to Y=70)
	fill_rect(img, 640, 70, 42, 200, Color(0.78, 0.22, 0.14)) # Aerospace Orange
	# Gantry cross-lattice lines
	for gy in range(70, 270, 25):
		draw_line_dda(img, 640, gy, 682, gy, Color(0.95, 0.45, 0.30))
		draw_line_dda(img, 640, gy, 682, gy + 25, Color(0.90, 0.40, 0.25))
	# Crane boom at top of gantry
	fill_rect(img, 530, 62, 160, 8, Color(0.85, 0.25, 0.15))
	# Lightning mast
	fill_rect(img, 660, 30, 3, 32, Color(0.70, 0.72, 0.75))
	# Aviation strobe red beacon
	fill_rect(img, 658, 26, 7, 7, Color(1.0, 0.15, 0.15))

	# Orbital Rocket Stack (Center X=520, standing from launch table Y=270 up to Y=90)
	# Core rocket booster
	fill_rect(img, 504, 110, 32, 160, Color(0.92, 0.94, 0.96))
	# Interstage / engine skirt
	fill_rect(img, 502, 245, 36, 25, Color(0.15, 0.15, 0.16))
	fill_rect(img, 503, 165, 34, 14, Color(0.15, 0.15, 0.16))
	# Nose fairing cone
	fill_polygon_convex(img, Vector2(504, 110), Vector2(536, 110), Vector2(520, 60), Vector2(520, 60), Color(0.94, 0.95, 0.97))
	# Boosters Left & Right
	fill_rect(img, 486, 155, 16, 105, Color(0.88, 0.90, 0.92))
	fill_rect(img, 538, 155, 16, 105, Color(0.88, 0.90, 0.92))
	fill_polygon_convex(img, Vector2(486, 155), Vector2(502, 155), Vector2(494, 135), Vector2(494, 135), Color(0.88, 0.90, 0.92))
	fill_polygon_convex(img, Vector2(538, 155), Vector2(554, 155), Vector2(546, 135), Vector2(546, 135), Color(0.88, 0.90, 0.92))
	# Swing-away umbilical arms
	fill_rect(img, 536, 140, 104, 6, Color(0.75, 0.25, 0.15))
	fill_rect(img, 536, 190, 104, 6, Color(0.75, 0.25, 0.15))

	# Cryogenic Spherical Tanks on Left (X=180..260)
	fill_rect(img, 150, 260, 70, 70, Color(0.82, 0.84, 0.86))
	fill_rect(img, 240, 275, 55, 55, Color(0.82, 0.84, 0.86))
	# Pipe bridge
	fill_rect(img, 220, 290, 190, 8, Color(0.48, 0.50, 0.54))

	# Telemetry Radar on Right (X=860..940)
	fill_rect(img, 880, 280, 30, 60, Color(0.45, 0.44, 0.42))
	fill_polygon_convex(img, Vector2(850, 245), Vector2(935, 220), Vector2(940, 230), Vector2(855, 255), Color(0.85, 0.86, 0.88))
	fill_rect(img, 936, 216, 6, 6, Color(0.1, 1.0, 0.3)) # Green beacon

	# Command Bunker (X=310, Y=310, W=80, H=30)
	fill_rect(img, 310, 310, 80, 30, Color(0.40, 0.39, 0.38))
	fill_rect(img, 335, 320, 25, 20, Color(0.9, 0.75, 0.1)) # Hazard yellow door

	# Tactical HUD Overlay / Borders
	draw_line_dda(img, 40, 40, 180, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, 40, 40, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 181, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 41, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 180, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 40, h - 121, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 181, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 41, h - 121, Color(0.0, 0.85, 1.0, 0.8))

	img.save_png("res://assets/ui/maps/cosmodrome.png")
	print("Saved Cosmodrome preview to res://assets/ui/maps/cosmodrome.png")

# -----------------------------------------------------------------------------
# 2. DAM PREVIEW (1100x550)
# -----------------------------------------------------------------------------
func generate_dam_preview() -> void:
	var w := 1100
	var h := 550
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Alpine Reservoir Sky Gradient
	for y in range(210):
		var t := float(y) / 210.0
		var sky_col := Color(0.24, 0.32, 0.42).lerp(Color(0.68, 0.72, 0.76), t)
		for x in range(w):
			img.set_pixel(x, y, sky_col)

	# Mountain Canyon Rock Cliffs Left & Right
	# West Cliff (Left)
	fill_polygon_convex(img, Vector2(0, 40), Vector2(280, 180), Vector2(240, 550), Vector2(0, 550), Color(0.28, 0.26, 0.24))
	# East Cliff (Right)
	fill_polygon_convex(img, Vector2(820, 180), Vector2(1100, 40), Vector2(1100, 550), Vector2(860, 550), Color(0.28, 0.26, 0.24))

	# Reservoir Water behind the Dam Crest
	for y in range(160, 205):
		var t := float(y - 160) / 45.0
		var water_col := Color(0.08, 0.22, 0.30).lerp(Color(0.12, 0.32, 0.38), t)
		for x in range(280, 820):
			img.set_pixel(x, y, water_col)

	# Reservoir Intake Towers
	fill_rect(img, 390, 140, 36, 65, Color(0.52, 0.51, 0.49))
	fill_rect(img, 674, 140, 36, 65, Color(0.52, 0.51, 0.49))
	fill_rect(img, 406, 134, 4, 6, Color(1.0, 0.15, 0.15)) # Beacon
	fill_rect(img, 690, 134, 4, 6, Color(1.0, 0.15, 0.15))

	# Dam Monolithic Wall (Spanning X=250..850, Y=200..420)
	fill_polygon_convex(img, Vector2(250, 200), Vector2(850, 200), Vector2(790, 420), Vector2(310, 420), Color(0.62, 0.60, 0.58))

	# Spillway Chutes & 40 deg Dive Slopes
	fill_polygon_convex(img, Vector2(330, 204), Vector2(480, 204), Vector2(450, 420), Vector2(350, 420), Color(0.52, 0.50, 0.48))
	fill_polygon_convex(img, Vector2(620, 204), Vector2(770, 204), Vector2(750, 420), Vector2(650, 420), Color(0.52, 0.50, 0.48))

	# Upper Dam Crest 2-Lane Highway (Y=196..206)
	fill_rect(img, 240, 196, 620, 10, Color(0.20, 0.21, 0.23))
	# Parapet Barriers
	draw_line_dda(img, 240, 195, 860, 195, Color(0.68, 0.67, 0.65))
	draw_line_dda(img, 240, 207, 860, 207, Color(0.68, 0.67, 0.65))
	# Highway road lamp posts
	for lx in [310, 410, 510, 590, 690, 790]:
		draw_line_dda(img, lx, 182, lx, 195, Color(0.40, 0.42, 0.45))
		fill_rect(img, lx - 2, 180, 5, 3, Color(1.0, 0.75, 0.15)) # Amber glow

	# 3 Giant Penstock Steel Pipes (Center, descending dam face)
	for px in [515, 545, 575]:
		draw_line_dda(img, px, 206, px - 15, 410, Color(0.30, 0.33, 0.36))
		draw_line_dda(img, px + 1, 206, px - 14, 410, Color(0.42, 0.45, 0.48))
		draw_line_dda(img, px + 2, 206, px - 13, 410, Color(0.30, 0.33, 0.36))

	# Turbine Powerhouse at Canyon Base (X=410..690, Y=400..470)
	fill_rect(img, 410, 405, 280, 65, Color(0.48, 0.47, 0.45))
	# Skylights / Open Drone Ingress shafts in roof
	fill_rect(img, 440, 407, 50, 18, Color(0.12, 0.12, 0.14))
	fill_rect(img, 610, 407, 50, 18, Color(0.12, 0.12, 0.14))

	# Riverbed Canyon Floor (Y=465..550)
	for y in range(465, h):
		var t := float(y - 465) / 85.0
		var bed_col := Color(0.32, 0.30, 0.28).lerp(Color(0.22, 0.21, 0.20), t)
		for x in range(w):
			img.set_pixel(x, y, bed_col)

	# High-voltage Substation switchyard on right
	fill_rect(img, 720, 470, 90, 50, Color(0.40, 0.40, 0.42))
	for tx in [735, 765, 795]:
		fill_rect(img, tx, 460, 16, 20, Color(0.30, 0.32, 0.35))

	# Tactical HUD Overlay / Borders
	draw_line_dda(img, 40, 40, 180, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, 40, 40, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 181, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 41, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 180, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 40, h - 121, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 181, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 41, h - 121, Color(0.0, 0.85, 1.0, 0.8))

	img.save_png("res://assets/ui/maps/dam.png")
	print("Saved Dam preview to res://assets/ui/maps/dam.png")

# -----------------------------------------------------------------------------
# 3. SKYLINE PREVIEW (1100x550)
# -----------------------------------------------------------------------------
func generate_skyline_preview() -> void:
	var w := 1100
	var h := 550
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Cyber Twilight Sky Gradient (Midnight indigo to neon violet horizon)
	for y in range(350):
		var t := float(y) / 350.0
		var sky_col := Color(0.08, 0.09, 0.20).lerp(Color(0.48, 0.20, 0.46), t * t)
		for x in range(w):
			img.set_pixel(x, y, sky_col)

	# Ground Plazas & Streets (Y=350..550)
	for y in range(350, h):
		var t := float(y - 350) / 200.0
		var street_col := Color(0.18, 0.19, 0.22).lerp(Color(0.11, 0.12, 0.14), t)
		for x in range(w):
			img.set_pixel(x, y, street_col)

	# Sunken Transit Underpass in center (X=500..600, Y=350..550)
	fill_polygon_convex(img, Vector2(520, 350), Vector2(580, 350), Vector2(620, 550), Vector2(480, 550), Color(0.08, 0.08, 0.10))
	# Highway center neon lane dividers
	draw_line_dda(img, 550, 350, 550, 550, Color(0.95, 0.75, 0.10, 0.6))
	# Street overpass bridge (Y=440)
	fill_rect(img, 450, 435, 200, 18, Color(0.45, 0.44, 0.42))

	# Commercial Mid-Rises in Background
	fill_rect(img, 80, 220, 160, 130, Color(0.20, 0.22, 0.28))
	fill_rect(img, 860, 200, 170, 150, Color(0.20, 0.22, 0.28))

	# TOWER ALPHA (Left Skyscraper: X=270..450, Height from Y=350 up to Y=40)
	fill_rect(img, 270, 40, 170, 310, Color(0.14, 0.18, 0.26))
	# Alpha window matrix (Cyan luminous grid)
	for wy in range(60, 330, 15):
		for wx in range(285, 430, 22):
			fill_rect(img, wx, wy, 12, 7, Color(0.15, 0.65, 0.85, 0.55))
	# Alpha Construction Crane atop roof
	fill_rect(img, 310, 15, 6, 25, Color(0.92, 0.72, 0.10))
	fill_rect(img, 260, 12, 110, 5, Color(0.92, 0.72, 0.10))
	# Alpha Holographic Neon Billboard
	fill_rect(img, 275, 170, 80, 30, Color(0.0, 0.85, 1.0, 0.85))

	# TOWER BRAVO (Right Skyscraper: X=650..830, Height from Y=350 up to Y=80)
	fill_rect(img, 650, 80, 170, 270, Color(0.14, 0.18, 0.26))
	# Bravo window matrix (Magenta & Cyan luminous grid)
	for wy in range(100, 330, 15):
		for wx in range(665, 810, 22):
			fill_rect(img, wx, wy, 12, 7, Color(0.75, 0.20, 0.65, 0.55))
	# Bravo Helipad Deck (Point A Objective) atop roof
	fill_rect(img, 675, 72, 120, 8, Color(0.55, 0.54, 0.52))
	# Glowing Cyan Helipad Ring
	draw_line_dda(img, 690, 70, 780, 70, Color(0.0, 0.95, 1.0))
	fill_rect(img, 676, 66, 5, 5, Color(1.0, 0.15, 0.15)) # Strobe
	fill_rect(img, 790, 66, 5, 5, Color(1.0, 0.15, 0.15))
	# Bravo Holographic Neon Billboard
	fill_rect(img, 735, 170, 80, 30, Color(1.0, 0.10, 0.65, 0.85))

	# DUAL TRANSIT SKYBRIDGES (Connecting Alpha and Bravo across X=440..650)
	# Upper High-Altitude Skybridge (Y=120..142)
	fill_rect(img, 440, 122, 210, 20, Color(0.22, 0.25, 0.30))
	# Glowing skybridge glass panels
	fill_rect(img, 450, 126, 190, 12, Color(0.10, 0.80, 0.90, 0.70))

	# Lower Skybridge (Y=210..236)
	fill_rect(img, 440, 212, 210, 24, Color(0.22, 0.25, 0.30))
	fill_rect(img, 450, 216, 190, 16, Color(0.90, 0.15, 0.60, 0.70))
	# Central neon display sign on bridge
	fill_rect(img, 530, 214, 30, 20, Color(0.0, 0.95, 1.0))

	# Tactical HUD Overlay / Borders
	draw_line_dda(img, 40, 40, 180, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, 40, 40, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 181, 40, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, 40, w - 41, 120, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 180, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, 40, h - 41, 40, h - 121, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 181, h - 41, Color(0.0, 0.85, 1.0, 0.8))
	draw_line_dda(img, w - 41, h - 41, w - 41, h - 121, Color(0.0, 0.85, 1.0, 0.8))

	img.save_png("res://assets/ui/maps/skyline.png")
	print("Saved Skyline preview to res://assets/ui/maps/skyline.png")
