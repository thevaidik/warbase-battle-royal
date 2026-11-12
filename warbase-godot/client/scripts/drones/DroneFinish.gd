extends RefCounted
## Shared, mipmapped metal finish. Generated once, never per drone or frame.
static var _grain: ImageTexture
static var _roughness: ImageTexture

static func apply_metal_grain(material: StandardMaterial3D) -> void:
	if material.metallic < 0.55 or material.emission_enabled:
		return
	if _grain == null:
		var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var rough := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var random := RandomNumberGenerator.new()
		random.seed = 640313
		for y in 256:
			var brush := random.randf_range(0.94, 0.99)
			for x in 256:
				# Broad machining variation survives mipmapping without sparkling.
				var wear := sin(float(x) * 0.049) * sin(float(y) * 0.074)
				var value := clampf(brush + wear * 0.006 + random.randf_range(-0.008, 0.008), 0.0, 1.0)
				image.set_pixel(x, y, Color(value, value, value))
				var finish := clampf(0.90 + wear * 0.04, 0.60, 1.0)
				rough.set_pixel(x, y, Color(finish, finish, finish))
		image.generate_mipmaps()
		rough.generate_mipmaps()
		_grain = ImageTexture.create_from_image(image)
		_roughness = ImageTexture.create_from_image(rough)
	material.albedo_texture = _grain
	material.roughness_texture = _roughness
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(5.0, 7.0, 5.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
