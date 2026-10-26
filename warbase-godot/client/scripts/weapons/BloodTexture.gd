extends RefCounted
## Shared cached splatter mask.
static var _texture: ImageTexture
static func get_texture() -> ImageTexture:
	if _texture != null: return _texture
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7392
	for i in 24:
		var center := Vector2(64, 64) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		var radius := Vector2(rng.randf_range(3, 19), rng.randf_range(3, 16))
		for y in range(maxi(0, int(center.y-radius.y)), mini(128, int(center.y+radius.y)+1)):
			for x in range(maxi(0, int(center.x-radius.x)), mini(128, int(center.x+radius.x)+1)):
				var distance := ((Vector2(x, y)-center)/radius).length()
				if distance < 1:
					var alpha := maxf(image.get_pixel(x,y).a, clampf((1-distance)*5,0,0.9))
					image.set_pixel(x,y,Color(1,1,1,alpha))
	image.generate_mipmaps()
	_texture = ImageTexture.create_from_image(image)
	return _texture
