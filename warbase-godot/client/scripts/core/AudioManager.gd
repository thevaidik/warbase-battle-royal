class_name WarAudioManager
extends Node
## Studio-grade procedural SFX synthesizer (no external audio assets required).
## 16-bit 44.1kHz PCM synthesis with pre-baked sound caches and dynamic variation.
## Provides tactile FPS gunshots, reloads, hit confirmations, explosions, and footsteps.

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var muted := false
var master_volume := 0.7
var sfx_volume := 0.7

# Sound cache for zero-latency playback
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferences := ConfigFile.new()
	if preferences.load("user://settings.cfg") == OK:
		sfx_volume = clampf(float(preferences.get_value("audio", "sfx", 0.7)), 0.0, 1.0)
	# Audio stays controllable through the in-game volume setting.
	var master_bus_idx := AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, false)
		
	# Pool of stream players for polyphony
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_prebake_sounds()

func _play(stream: AudioStreamWAV, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or stream == null or master_volume <= 0.0 or sfx_volume <= 0.0:
		return
	var p: AudioStreamPlayer = null
	for i in _players.size():
		var test_idx := (_idx + i) % _players.size()
		if not _players[test_idx].playing:
			p = _players[test_idx]
			_idx = (test_idx + 1) % _players.size()
			break
	if p == null:
		p = _players[_idx]
		_idx = (_idx + 1) % _players.size()
	p.stream = stream
	var user_db: float = linear_to_db(clampf(master_volume * sfx_volume, 0.001, 2.0))
	p.volume_db = vol_db + user_db
	p.pitch_scale = pitch
	p.play()

# 16-bit 44.1kHz PCM buffer generator
func _bake_pcm(dur: float, rate: int, generator: Callable) -> AudioStreamWAV:
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var s: float = generator.call(t, i, n)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32760.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _prebake_sounds() -> void:
	var rate := 44100
	
	# AK-47: Crisp high transient + mechanical bolt cycle + 110Hz body punch + low decay
	_sfx_cache["ak47"] = _bake_pcm(0.24, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-18.0 * t)
		var sub := sin(TAU * (115.0 - 55.0 * t) * t) * 0.75
		var noise := (randf() * 2.0 - 1.0) * exp(-26.0 * t) * 0.85
		var snap := sin(TAU * 780.0 * t) * exp(-48.0 * t) * 0.6
		var clack := sin(TAU * 1420.0 * maxf(0.0, t - 0.035)) * exp(-40.0 * maxf(0.0, t - 0.035)) * 0.4 if t >= 0.035 else 0.0
		return (sub + noise + snap + clack) * env
	)
	
	# Pistol .50: Sharp crack + punchy slide kick
	_sfx_cache["pistol"] = _bake_pcm(0.18, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-24.0 * t)
		var punch := sin(TAU * 165.0 * t) * 0.7
		var crack := (randf() * 2.0 - 1.0) * exp(-36.0 * t) * 0.95
		var slide := sin(TAU * 2200.0 * maxf(0.0, t - 0.025)) * exp(-45.0 * maxf(0.0, t - 0.025)) * 0.3 if t >= 0.025 else 0.0
		return (punch + crack + slide) * env
	)
	
	# M2010 Sniper: Thunderous supersonic crack + 50Hz sub-bass shockwave + echo tail
	_sfx_cache["m2010"] = _bake_pcm(0.55, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-8.5 * t)
		var crack := (randf() * 2.0 - 1.0) * exp(-28.0 * t) * 1.1
		var sub := sin(TAU * (52.0 - 18.0 * t) * t) * exp(-6.5 * t) * 1.0
		var whip := sin(TAU * 2400.0 * t) * exp(-55.0 * t) * 0.7
		var echo := sin(TAU * 180.0 * t) * exp(-10.0 * t) * 0.35
		return (crack + sub + whip + echo) * env
	)
	
	# M2 .50 HMG: Deep heavy machine gun metallic thud + 72Hz concussive chest thump
	_sfx_cache["hmg"] = _bake_pcm(0.28, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-14.0 * t)
		var thump := sin(TAU * (76.0 - 28.0 * t) * t) * 0.88
		var blast := (randf() * 2.0 - 1.0) * exp(-24.0 * t) * 0.95
		var bolt := sin(TAU * 1150.0 * maxf(0.0, t - 0.04)) * exp(-35.0 * maxf(0.0, t - 0.04)) * 0.5 if t >= 0.04 else 0.0
		return (thump + blast + bolt) * env
	)
	
	# Distinct envelopes for the expanded rifle/SMG roster.
	_sfx_cache["m4"] = _bake_pcm(0.19, rate, func(t: float, _i: int, _n: int) -> float:
		return (sin(TAU * 145.0 * t) * 0.5 + (randf() * 2.0 - 1.0) * exp(-28.0 * t)) * exp(-22.0 * t)
	)
	_sfx_cache["mp5"] = _bake_pcm(0.13, rate, func(t: float, _i: int, _n: int) -> float:
		return (sin(TAU * 210.0 * t) * 0.4 + (randf() * 2.0 - 1.0) * exp(-38.0 * t)) * exp(-32.0 * t)
	)
	_sfx_cache["dmr"] = _bake_pcm(0.30, rate, func(t: float, _i: int, _n: int) -> float:
		return (sin(TAU * (105.0 - 35.0 * t) * t) * 0.75 + (randf() * 2.0 - 1.0) * exp(-22.0 * t)) * exp(-14.0 * t)
	)
	# Dry fire hammer click
	_sfx_cache["dry"] = _bake_pcm(0.06, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-70.0 * t)
		var click := sin(TAU * 1800.0 * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.5
		return click * env
	)
	
	# Brass shell casing hitting concrete
	_sfx_cache["casing_clink"] = _bake_pcm(0.08, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-48.0 * t)
		var ping1 := sin(TAU * 3200.0 * t) * 0.6
		var ping2 := sin(TAU * 4800.0 * t) * 0.3
		return (ping1 + ping2) * env
	)
	
	# UI Tactical Click
	_sfx_cache["ui_click"] = _bake_pcm(0.04, rate, func(t: float, i: int, n: int) -> float:
		return sin(TAU * 1600.0 * t) * exp(-65.0 * t) * 0.6
	)
	
	# UI Hover Chirp
	_sfx_cache["ui_hover"] = _bake_pcm(0.03, rate, func(t: float, i: int, n: int) -> float:
		return sin(TAU * (800.0 + 1200.0 * t) * t) * exp(-75.0 * t) * 0.35
	)
	
	# Reload parts:
	# 1. Mag out
	_sfx_cache["reload_out"] = _bake_pcm(0.12, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 380.0 * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.4) * exp(-28.0 * t)
	)
	# 2. Mag in
	_sfx_cache["reload_in"] = _bake_pcm(0.14, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 260.0 * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * exp(-22.0 * t)
	)
	# 3. Bolt rack
	_sfx_cache["reload_bolt"] = _bake_pcm(0.15, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 780.0 * t) * 0.4 + (randf() * 2.0 - 1.0) * 0.6) * exp(-26.0 * t)
	)
	
	# Hitmarker (body)
	_sfx_cache["hit_body"] = _bake_pcm(0.08, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 1250.0 * t) * 0.8 + sin(TAU * 2500.0 * t) * 0.2) * exp(-40.0 * t)
	)
	
	# Hitmarker (headshot / kill confirmation)
	_sfx_cache["hit_kill"] = _bake_pcm(0.16, rate, func(t: float, i: int, n: int) -> float:
		var tone1 := sin(TAU * 1560.0 * t) * exp(-25.0 * t) * 0.6
		var tone2 := sin(TAU * 2080.0 * (t - 0.03)) * exp(-25.0 * maxf(0.0, t - 0.03)) * 0.6 if t >= 0.03 else 0.0
		return tone1 + tone2
	)
	
	# Explosion
	_sfx_cache["explosion"] = _bake_pcm(0.85, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-5.0 * t)
		var rumble := sin(TAU * (48.0 - 15.0 * t) * t) * 0.8
		var noise := (randf() * 2.0 - 1.0) * exp(-8.0 * t) * 0.7
		var punch := (randf() * 2.0 - 1.0) * exp(-35.0 * t) * 0.8
		return (rumble + noise + punch) * env
	)
	
	# Grenade bounce clink
	_sfx_cache["grenade_bounce"] = _bake_pcm(0.08, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 1900.0 * t) * 0.5 + sin(TAU * 950.0 * t) * 0.3) * exp(-55.0 * t)
	)
	
	# Grenade pin pull & spoon pop
	_sfx_cache["grenade_pin"] = _bake_pcm(0.12, rate, func(t: float, i: int, n: int) -> float:
		var metal_scrape := (randf() * 2.0 - 1.0) * exp(-28.0 * t) * 0.4
		var pin_ting := sin(TAU * 2600.0 * t) * exp(-45.0 * t) * 0.7
		var spoon_pop := sin(TAU * 720.0 * t) * exp(-60.0 * t) * 0.5
		return metal_scrape + pin_ting + spoon_pop
	)
	
	# Footstep: concrete/gravel tactical boot step
	_sfx_cache["step"] = _bake_pcm(0.09, rate, func(t: float, i: int, n: int) -> float:
		var env := exp(-42.0 * t)
		var thud := sin(TAU * 85.0 * t) * 0.6
		var grit := (randf() * 2.0 - 1.0) * exp(-50.0 * t) * 0.4
		return (thud + grit) * env
	)
	
	# Player hurt
	_sfx_cache["hurt"] = _bake_pcm(0.18, rate, func(t: float, i: int, n: int) -> float:
		return (sin(TAU * 95.0 * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.3) * exp(-16.0 * t)
	)

func shoot(kind: String, gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sfx_cache.get(kind, _sfx_cache.get("ak47"))
	var db := 0.0
	match kind:
		"m2010":
			db = 2.0
		"pistol":
			db = -1.5
		_:
			db = 0.0
	_play(stream, db + gain_db, randf_range(0.96, 1.04))

func dry() -> void:
	_play(_sfx_cache.get("dry"), -4.0, randf_range(0.98, 1.02))

func reload() -> void:
	_play(_sfx_cache.get("reload_out"), -2.0)
	await get_tree().create_timer(0.4).timeout
	_play(_sfx_cache.get("reload_in"), -2.0)
	await get_tree().create_timer(0.4).timeout
	_play(_sfx_cache.get("reload_bolt"), -1.0)

func hitmarker(kill: bool = false) -> void:
	var stream: AudioStreamWAV = _sfx_cache.get("hit_kill" if kill else "hit_body")
	_play(stream, 1.0 if kill else -1.0, randf_range(0.98, 1.02))

func explosion() -> void:
	_play(_sfx_cache.get("explosion"), 3.0, randf_range(0.95, 1.05))

func grenade_bounce() -> void:
	_play(_sfx_cache.get("grenade_bounce"), -4.0, randf_range(0.9, 1.1))

func grenade_pin() -> void:
	_play(_sfx_cache.get("grenade_pin"), -2.0, randf_range(0.95, 1.05))

func step() -> void:
	_play(_sfx_cache.get("step"), -9.0, randf_range(0.92, 1.08))

func hurt() -> void:
	_play(_sfx_cache.get("hurt"), 0.0, randf_range(0.95, 1.05))

func casing() -> void:
	_play(_sfx_cache.get("casing_clink"), -12.0, randf_range(0.92, 1.15))

func ui_btn_click() -> void:
	_play(_sfx_cache.get("ui_click"), -6.0, randf_range(0.98, 1.02))

func click() -> void:
	ui_btn_click()

func ui_btn_hover() -> void:
	_play(_sfx_cache.get("ui_hover"), -14.0, randf_range(0.95, 1.05))

func stop_all() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
