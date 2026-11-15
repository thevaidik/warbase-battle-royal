extends RefCounted
## Shared, mipmapped PBR metal finish. Generated once, never per drone or frame.
static var _grain: ImageTexture
static var _roughness: ImageTexture
static var _normal: ImageTexture

static func apply_metal_grain(material: StandardMaterial3D) -> void:
	if material.emission_enabled:
		return
	if _grain == null:
		var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var rough := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var norm := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var random := RandomNumberGenerator.new()
		random.seed = 640313
		for y in 256:
			var brush := random.randf_range(0.94, 0.99)
			for x in 256:
				# Broad machining variation survives mipmapping without sparkling.
				var wear := sin(float(x) * 0.049) * sin(float(y) * 0.074)
				var value := clampf(brush + wear * 0.006 + random.randf_range(-0.008, 0.008), 0.0, 1.0)
				image.set_pixel(x, y, Color(value, value, value))
				var finish := clampf(0.88 + wear * 0.05, 0.55, 1.0)
				rough.set_pixel(x, y, Color(finish, finish, finish))
				
				# Tangent space normal map for micro-machined brushed metal relief
				var grain_nx := (random.randf() * 2.0 - 1.0) * 0.05 + cos(float(x) * 0.049) * 0.04
				var grain_ny := (random.randf() * 2.0 - 1.0) * 0.025
				var r := clampf(0.5 + grain_nx, 0.0, 1.0)
				var g := clampf(0.5 + grain_ny, 0.0, 1.0)
				norm.set_pixel(x, y, Color(r, g, 1.0))
		image.generate_mipmaps()
		rough.generate_mipmaps()
		norm.generate_mipmaps()
		_grain = ImageTexture.create_from_image(image)
		_roughness = ImageTexture.create_from_image(rough)
		_normal = ImageTexture.create_from_image(norm)
	
	if material.metallic >= 0.35:
		material.albedo_texture = _grain
		material.roughness_texture = _roughness
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.normal_enabled = true
		material.normal_texture = _normal
		material.normal_scale = 0.65
		material.clearcoat_enabled = true
		material.clearcoat = 0.35
		material.clearcoat_roughness = 0.28
		material.rim_enabled = true
		material.rim = 0.18
		material.rim_tint = 0.5
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(5.0, 7.0, 5.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
