class_name ProcTextures

static func _height_to_normal(height_img: Image, strength: float = 2.0) -> ImageTexture:
	var w = height_img.get_width()
	var h = height_img.get_height()
	var n_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var hl = height_img.get_pixel((x - 1 + w) % w, y).r
			var hr = height_img.get_pixel((x + 1) % w, y).r
			var hu = height_img.get_pixel(x, (y - 1 + h) % h).r
			var hd = height_img.get_pixel(x, (y + 1) % h).r
			var dx = (hl - hr) * strength
			var dy = (hu - hd) * strength
			var v = Vector3(dx, dy, 1.0).normalized()
			n_img.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5, 1.0))
	return ImageTexture.create_from_image(n_img)

static func road_pbr() -> Dictionary:
	var alb = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var hgt = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var rgh = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = 101
	for y in 128:
		for x in 128:
			var grain = rng.randf_range(-0.04, 0.04)
			var col = Color(0.09 + grain, 0.095 + grain, 0.11 + grain)
			var hv = 0.5 + grain * 4.0
			var rv = clampf(0.52 + grain * 2.5, 0.28, 0.85)
			# Subtle wet-asphalt reflection streaks
			if sin(x * 0.14 + y * 0.06) > 0.72:
				rv = 0.18
			if (x >= 60 and x <= 62) or (x >= 65 and x <= 67):
				col = Color(0.90, 0.72, 0.14); rv = 0.35
			elif x == 5 or x == 6 or x == 121 or x == 122:
				col = Color(0.78, 0.80, 0.84); rv = 0.38
			elif (x == 32 or x == 96) and (y % 20 < 9):
				col = Color(0.68, 0.70, 0.74); rv = 0.38
			alb.set_pixel(x, y, col)
			hgt.set_pixel(x, y, Color(hv, hv, hv))
			rgh.set_pixel(x, y, Color(rv, rv, rv))
	return {
		"albedo": ImageTexture.create_from_image(alb),
		"normal": _height_to_normal(hgt, 2.4),
		"roughness": ImageTexture.create_from_image(rgh)
	}

static func sidewalk_pbr() -> Dictionary:
	var alb = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var hgt = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = 7
	for y in 128:
		for x in 128:
			var seam = (x % 32 == 0) or (y % 32 == 0)
			var n = rng.randf_range(-0.02, 0.02)
			alb.set_pixel(x, y, Color(0.18, 0.19, 0.22) if seam else Color(0.31 + n, 0.32 + n, 0.35 + n))
			var hv = 0.15 if seam else (0.65 + n * 3.0)
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	return {
		"albedo": ImageTexture.create_from_image(alb),
		"normal": _height_to_normal(hgt, 3.0)
	}

static func building_facade(base_col: Color, glow_col: Color, seed_val: int) -> Dictionary:
	var alb = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var emi = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var hgt = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = seed_val
	alb.fill(base_col); emi.fill(Color(0, 0, 0, 1)); hgt.fill(Color(0.8, 0.8, 0.8))
	for r in 8:
		for c in 8:
			var lit = rng.randf() < 0.45
			var wcol = glow_col.lerp(Color.WHITE, rng.randf_range(0.1, 0.4)) if lit else base_col.darkened(0.55)
			for yy in range(r * 16 + 3, r * 16 + 13):
				for xx in range(c * 16 + 3, c * 16 + 13):
					alb.set_pixel(xx, yy, wcol)
					hgt.set_pixel(xx, yy, Color(0.25, 0.25, 0.25))
					if lit: emi.set_pixel(xx, yy, wcol)
	return {
		"albedo": ImageTexture.create_from_image(alb),
		"emission": ImageTexture.create_from_image(emi),
		"normal": _height_to_normal(hgt, 2.8)
	}
