class_name WarAudioManager
extends Node
## High-performance procedural audio synthesis engine for WarBase.
## Zero external audio asset dependencies; 100% deterministic 16-bit PCM sound bank.

const AUDIO_ENABLED := true
var muted := false
var master_volume := 1.0
var sfx_volume := 1.0

const MIX_RATE := 22050
const POOL_SIZE := 16

var _players: Array[AudioStreamPlayer] = []
var _player_idx := 0
var _streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)
		AudioServer.set_bus_volume_db(master, linear_to_db(master_volume))
	
	# Instantiate voice pool for overlapping sound playback
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "AudioVoice_%d" % i
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	
	_bake_sound_bank()

func _play_stream(stream: AudioStreamWAV, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if not AUDIO_ENABLED or muted or stream == null:
		return
	var player := _players[_player_idx]
	_player_idx = (_player_idx + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = clampf(gain_db + linear_to_db(sfx_volume), -80.0, 6.0)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()

# ==============================================================================
# PUBLIC SOUND API
# ==============================================================================

func shoot(kind: String, gain_db: float = 0.0) -> void:
	var key := "shoot_" + kind.to_lower()
	var stream: AudioStreamWAV = _streams.get(key, _streams.get("shoot_ak47"))
	var pitch_var := randf_range(0.96, 1.04)
	_play_stream(stream, gain_db, pitch_var)

func dry() -> void:
	_play_stream(_streams.get("dry"), -4.0, randf_range(0.95, 1.05))

func reload() -> void:
	_play_stream(_streams.get("reload"), -2.0, 1.0)

func hitmarker(hit_type: Variant = false) -> void:
	if hit_type is bool:
		var key := "hitmarker_kill" if hit_type else "hitmarker_hit"
		_play_stream(_streams.get(key), 1.5 if hit_type else -1.0, 1.0)
		return
	var type_str := String(hit_type).to_lower()
	match type_str:
		"deflect", "armor":
			_play_stream(_streams.get("ricochet"), 0.5, randf_range(0.98, 1.05))
		"crit", "critical", "rear":
			_play_stream(_streams.get("armor_crunch"), 2.0, randf_range(0.94, 1.02))
		"kill":
			_play_stream(_streams.get("hitmarker_kill"), 2.0, 1.0)
		_:
			_play_stream(_streams.get("hitmarker_hit"), -1.0, 1.0)

func missile_lock_warning() -> void:
	_play_stream(_streams.get("missile_warning"), 1.0, 1.0)

func low_hull_alarm() -> void:
	_play_stream(_streams.get("low_hull_alarm"), -2.0, 1.0)

func explosion() -> void:
	var stream: AudioStreamWAV = _streams.get("explosion")
	_play_stream(stream, 2.0, randf_range(0.92, 1.06))

func grenade_bounce() -> void:
	_play_stream(_streams.get("grenade_bounce"), -4.0, randf_range(0.9, 1.1))

func grenade_pin() -> void:
	_play_stream(_streams.get("grenade_pin"), -3.0, 1.0)

func step() -> void:
	_play_stream(_streams.get("step"), -12.0, randf_range(0.9, 1.1))

func hurt() -> void:
	_play_stream(_streams.get("hurt"), 0.0, randf_range(0.95, 1.05))

func casing() -> void:
	_play_stream(_streams.get("casing"), -9.0, randf_range(0.92, 1.08))

func ui_btn_click() -> void:
	_play_stream(_streams.get("ui_click"), -6.0, 1.0)

func click() -> void:
	ui_btn_click()

func ui_btn_hover() -> void:
	_play_stream(_streams.get("ui_hover"), -12.0, 1.0)

func objective_alert(captured: bool = true) -> void:
	var key := "objective_captured" if captured else "objective_lost"
	_play_stream(_streams.get(key), 1.0, 1.0)

func supersonic_crack(gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get("supersonic_crack")
	_play_stream(stream, gain_db, randf_range(0.95, 1.05))

func ricochet(gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get("ricochet")
	_play_stream(stream, gain_db, randf_range(0.92, 1.08))

func cookoff_pop(gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get("cookoff_pop")
	_play_stream(stream, gain_db, randf_range(0.88, 1.15))

func ability_activate(kind: String) -> void:
	var key := "ability_" + kind.to_lower()
	var stream: AudioStreamWAV = _streams.get(key, _streams.get("ability_generic"))
	_play_stream(stream, 1.5, 1.0)

func stop_all() -> void:
	for p in _players:
		if p.playing:
			p.stop()

func get_engine_stream(mobility_mode: String) -> AudioStreamWAV:
	var key := "engine_" + mobility_mode.to_lower()
	return _streams.get(key, _streams.get("engine_wheels"))

# ==============================================================================
# PROCEDURAL PCM SYNTHESIS
# ==============================================================================

func _bake_sound_bank() -> void:
	_streams["shoot_ak47"] = _bake_rifle(140.0, 50.0, 0.22, 0.42)
	_streams["shoot_m4"] = _bake_rifle(155.0, 60.0, 0.20, 0.38)
	_streams["shoot_mp5"] = _bake_rifle(260.0, 120.0, 0.14, 0.32)
	_streams["shoot_pistol"] = _bake_rifle(320.0, 180.0, 0.11, 0.25)
	_streams["shoot_dmr"] = _bake_rifle(110.0, 42.0, 0.28, 0.50)
	_streams["shoot_m2010"] = _bake_sniper(60.0, 0.42)
	_streams["shoot_hmg"] = _bake_autocannon(55.0, 0.26)
	_streams["shoot_m39"] = _bake_autocannon(65.0, 0.24)
	_streams["shoot_m230"] = _bake_autocannon(50.0, 0.28)
	_streams["shoot_gau22"] = _bake_autocannon(75.0, 0.20)
	_streams["shoot_aim9"] = _bake_missile_whoosh(0.48)
	_streams["shoot_agm114"] = _bake_missile_whoosh(0.55)
	
	_streams["hitmarker_hit"] = _bake_hitmarker(false)
	_streams["hitmarker_kill"] = _bake_hitmarker(true)
	_streams["explosion"] = _bake_explosion(0.60)
	_streams["reload"] = _bake_reload(0.30)
	_streams["dry"] = _bake_click(850.0, 0.04)
	_streams["casing"] = _bake_metallic_tink(2200.0, 0.04)
	_streams["grenade_bounce"] = _bake_metallic_tink(1650.0, 0.07)
	_streams["grenade_pin"] = _bake_click(1400.0, 0.05)
	_streams["step"] = _bake_step(0.08)
	_streams["hurt"] = _bake_thump(65.0, 0.14)
	
	_streams["ui_click"] = _bake_tone(1350.0, 0.035)
	_streams["ui_hover"] = _bake_tone(900.0, 0.020)
	_streams["objective_captured"] = _bake_fanfare(true)
	_streams["objective_lost"] = _bake_fanfare(false)
	_streams["supersonic_crack"] = _bake_supersonic_crack()
	_streams["ricochet"] = _bake_ricochet()
	_streams["cookoff_pop"] = _bake_cookoff()
	_streams["armor_crunch"] = _bake_armor_crunch()
	_streams["missile_warning"] = _bake_missile_warning()
	_streams["low_hull_alarm"] = _bake_alarm_klaxon()
	
	_streams["ability_smoke"] = _bake_whoosh(0.65)
	_streams["ability_nitro"] = _bake_nitro(0.85)
	_streams["ability_flares"] = _bake_flares(0.55)
	_streams["ability_airbrake"] = _bake_airbrake(0.70)
	_streams["ability_generic"] = _bake_whoosh(0.50)
	
	_streams["engine_tracked"] = _bake_engine_tracked(1.0)
	_streams["engine_wheels"] = _bake_engine_wheels(1.0)
	_streams["engine_heli"] = _bake_engine_heli(1.0)
	_streams["engine_wing"] = _bake_engine_wing(1.0)

func _make_wav(data: PackedByteArray, loop: bool = false, rate: int = MIX_RATE) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	w.data = data
	return w

func _bake_rifle(start_freq: float, end_freq: float, duration: float, punch: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 22.0)
		var freq := lerpf(start_freq, end_freq, clampf(t / duration, 0.0, 1.0))
		var body := sin(TAU * freq * t) * punch
		var noise := (randf() * 2.0 - 1.0) * 0.45 * exp(-t * 30.0)
		var ring := sin(TAU * 780.0 * t) * 0.15 * exp(-t * 40.0)
		var s := (body + noise + ring) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_sniper(sub_freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 8.5)
		var crack := (randf() * 2.0 - 1.0) * exp(-t * 55.0) * 0.8
		var sub := sin(TAU * sub_freq * t) * 0.75 * exp(-t * 12.0)
		var mid := sin(TAU * 220.0 * t) * 0.35 * exp(-t * 16.0)
		var s := (crack + sub + mid) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_autocannon(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 14.0)
		var sub := sin(TAU * freq * t) * 0.70
		var mech := sin(TAU * 480.0 * t) * 0.35 * exp(-t * 35.0)
		var noise := (randf() * 2.0 - 1.0) * 0.40 * exp(-t * 22.0)
		var s := (sub + mech + noise) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_missile_whoosh(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var swell := sin(PI * clampf(t / duration, 0.0, 1.0))
		var noise := (randf() * 2.0 - 1.0) * 0.65
		var sub := sin(TAU * 85.0 * t) * 0.45
		var s := (noise + sub) * swell
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 31000.0))
	return _make_wav(data)

func _bake_hitmarker(kill: bool) -> AudioStreamWAV:
	var duration := 0.12 if kill else 0.035
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var s: float = 0.0
		if kill:
			var env := exp(-t * 24.0)
			s = (sin(TAU * 1200.0 * t) * 0.45 + sin(TAU * 1800.0 * t) * 0.55) * env
		else:
			var env := exp(-t * 85.0)
			s = (sin(TAU * 1350.0 * t) * 0.75 + (randf() * 2.0 - 1.0) * 0.25) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_explosion(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 6.5)
		var sub := sin(TAU * 38.0 * t) * 0.85
		var noise := (randf() * 2.0 - 1.0) * 0.55
		var crack := (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.95
		var s := (sub + noise + crack) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_reload(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var s := 0.0
		# Click 1: mag eject at t=0.03
		if t > 0.02 and t < 0.07:
			s += sin(TAU * 950.0 * (t - 0.02)) * exp(-(t - 0.02) * 80.0) * 0.6
		# Click 2: mag insert at t=0.14
		if t > 0.13 and t < 0.20:
			s += sin(TAU * 650.0 * (t - 0.13)) * exp(-(t - 0.13) * 60.0) * 0.7
		# Click 3: bolt release at t=0.23
		if t > 0.22 and t < 0.29:
			s += sin(TAU * 1450.0 * (t - 0.22)) * exp(-(t - 0.22) * 90.0) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _make_wav(data)

func _bake_click(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 70.0)
		var s := (sin(TAU * freq * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data)

func _bake_metallic_tink(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 60.0)
		var s := (sin(TAU * freq * t) * 0.6 + sin(TAU * (freq * 1.52) * t) * 0.4) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	return _make_wav(data)

func _bake_step(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 45.0)
		var s := (sin(TAU * 75.0 * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 24000.0))
	return _make_wav(data)

func _bake_thump(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 20.0)
		var s := sin(TAU * freq * t) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_tone(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 35.0)
		var s := sin(TAU * freq * t) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 22000.0))
	return _make_wav(data)

func _bake_fanfare(victory: bool) -> AudioStreamWAV:
	var duration := 0.40
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var s: float = 0.0
		if victory:
			# Rising C-E-G triad
			if t < 0.12: s = sin(TAU * 523.25 * t)
			elif t < 0.24: s = sin(TAU * 659.25 * (t - 0.12))
			else: s = (sin(TAU * 783.99 * (t - 0.24)) + sin(TAU * 1046.50 * (t - 0.24)) * 0.5) * exp(-(t - 0.24) * 8.0)
		else:
			# Descending minor tone
			if t < 0.18: s = sin(TAU * 440.0 * t)
			else: s = sin(TAU * 349.23 * (t - 0.18)) * exp(-(t - 0.18) * 9.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	return _make_wav(data)

func _bake_whoosh(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := sin(PI * clampf(t / duration, 0.0, 1.0))
		var noise := (randf() * 2.0 - 1.0) * 0.65
		var mid := sin(TAU * 340.0 * t) * 0.35
		var s := (noise + mid) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data)

func _bake_nitro(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := sin(PI * clampf(t / duration, 0.0, 1.0))
		var roar := sin(TAU * 90.0 * t) * 0.55 + sin(TAU * 180.0 * t) * 0.35
		var hiss := (randf() * 2.0 - 1.0) * 0.45
		var s := (roar + hiss) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 31000.0))
	return _make_wav(data)

func _bake_flares(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var pop := sin(TAU * 450.0 * t) * exp(-t * 25.0) * 0.7
		var hiss := (randf() * 2.0 - 1.0) * exp(-t * 4.0) * 0.55
		var s := pop + hiss
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _make_wav(data)

func _bake_airbrake(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := sin(PI * clampf(t / duration, 0.0, 1.0))
		var drag := (randf() * 2.0 - 1.0) * 0.60
		var tone := sin(TAU * 220.0 * t) * 0.40
		var s := (drag + tone) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data)

# ==============================================================================
# LOOPING ENGINE STREAMS (1.0 second loops)
# ==============================================================================

func _bake_engine_tracked(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var diesel := sin(TAU * 38.0 * t) * 0.50 + sin(TAU * 76.0 * t) * 0.30
		var clatter := sin(TAU * 152.0 * t) * 0.15 + (randf() * 2.0 - 1.0) * 0.05
		var s := diesel + clatter
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data, true)

func _bake_engine_wheels(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var v8 := sin(TAU * 52.0 * t) * 0.48 + sin(TAU * 104.0 * t) * 0.28 + sin(TAU * 156.0 * t) * 0.16
		var rasp := (randf() * 2.0 - 1.0) * 0.08
		var s := v8 + rasp
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data, true)

func _bake_engine_heli(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var rotor := sin(TAU * 26.0 * t) * 0.60 + sin(TAU * 52.0 * t) * 0.25
		var turbine := sin(TAU * 480.0 * t) * 0.15
		var s := rotor + turbine
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data, true)

func _bake_engine_wing(duration: float) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var thrust := (randf() * 2.0 - 1.0) * 0.50
		var tone := sin(TAU * 210.0 * t) * 0.35 + sin(TAU * 420.0 * t) * 0.15
		var s := thrust + tone
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data, true)

func _bake_supersonic_crack() -> AudioStreamWAV:
	var duration := 0.08
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var impulse := (1.0 if t < 0.003 else -0.75) * exp(-t * 70.0)
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.85
		var s := (impulse * 0.65 + noise * 0.55)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_ricochet() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := 1800.0 + sin(t * 120.0) * 600.0 - t * 4000.0
		var ping := sin(TAU * freq * t) * exp(-t * 18.0) * 0.75
		var spark := (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.45
		var s := ping + spark
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_cookoff() -> AudioStreamWAV:
	var duration := 0.12
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var crack := (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.9
		var thump := sin(TAU * 120.0 * t) * exp(-t * 25.0) * 0.5
		var s := crack + thump
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_armor_crunch() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var bass := sin(TAU * 72.0 * t) * exp(-t * 14.0) * 0.85
		var crunch := (randf() * 2.0 - 1.0) * exp(-t * 24.0) * 0.70
		var tear := sin(TAU * (380.0 - t * 900.0) * t) * exp(-t * 18.0) * 0.45
		var s := bass + crunch + tear
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _make_wav(data)

func _bake_missile_warning() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := 1150.0 if fmod(t, 0.11) < 0.055 else 880.0
		var env := 1.0 if fmod(t, 0.055) < 0.045 else 0.0
		var tone := sin(TAU * freq * t) * 0.75 * env
		data.encode_s16(i * 2, int(clampf(tone, -1.0, 1.0) * 28000.0))
	return _make_wav(data)

func _bake_alarm_klaxon() -> AudioStreamWAV:
	var duration := 0.38
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sweep := lerpf(460.0, 310.0, clampf(t / duration, 0.0, 1.0))
		var env := sin(PI * clampf(t / duration, 0.0, 1.0))
		var tone := sin(TAU * sweep * t) * 0.65 + sin(TAU * sweep * 2.0 * t) * 0.25
		var s := tone * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	return _make_wav(data)

