class_name WarGameState
extends Node
## Autoload: session config + weapon database + shared match state.
## Ported from client/src/physics/WeaponSystem.ts WEAPON_CONFIGS and main.ts session vars.

const WEAPONS: Array = [
	{
		"id": "ak47", "name": "M61 Vulcan", "damage": 34.0, "headshot_mult": 1.8,
		"fire_rate": 600.0, "mag_size": 30, "reload_time": 2.5,
		"base_spread": 1.2, "bloom_per_shot": 0.4, "max_spread": 5.0, "bloom_recovery": 8.0,
		"recoil_vertical": 0.02, "recoil_horizontal": 0.008, "recoil_recovery": 6.0,
		"ads_time": 0.16, "ads_spread_mult": 0.08, "ads_recoil_mult": 0.7,
		"is_auto": true,
	},
	{
		"id": "pistol", "name": "M197 Cannon", "damage": 34.0, "headshot_mult": 1.8,
		"fire_rate": 400.0, "mag_size": 12, "reload_time": 1.5,
		"base_spread": 1.0, "bloom_per_shot": 0.8, "max_spread": 6.0, "bloom_recovery": 12.0,
		"recoil_vertical": 0.04, "recoil_horizontal": 0.005, "recoil_recovery": 10.0,
		"ads_time": 0.10, "ads_spread_mult": 0.12, "ads_recoil_mult": 0.5,
		"is_auto": false,
	},
	{
		"id": "m2010", "name": "GAU-8/A Avenger", "damage": 100.0, "headshot_mult": 1.8,
		"fire_rate": 45.0, "mag_size": 5, "reload_time": 3.2,
		"base_spread": 0.06, "bloom_per_shot": 2.0, "max_spread": 8.0, "bloom_recovery": 5.0,
		"recoil_vertical": 0.08, "recoil_horizontal": 0.015, "recoil_recovery": 4.0,
		"ads_time": 0.20, "ads_spread_mult": 0.02, "ads_recoil_mult": 0.3,
		"is_auto": false,
	},
	{
		"id": "hmg", "name": "GAU-12/U Equalizer", "damage": 34.0, "headshot_mult": 1.8,
		"fire_rate": 520.0, "mag_size": 60, "reload_time": 3.4,
		"base_spread": 2.2, "bloom_per_shot": 0.45, "max_spread": 6.8, "bloom_recovery": 7.5,
		"recoil_vertical": 0.032, "recoil_horizontal": 0.010, "recoil_recovery": 5.5,
		"ads_time": 0.20, "ads_spread_mult": 0.18, "ads_recoil_mult": 0.65,
		"is_auto": true,
	},
	{
		"id": "m4", "name": "M39 Cannon", "damage": 25.0, "headshot_mult": 1.8,
		"fire_rate": 750.0, "mag_size": 30, "reload_time": 2.2,
		"base_spread": 0.85, "bloom_per_shot": 0.28, "max_spread": 4.2, "bloom_recovery": 10.0,
		"recoil_vertical": 0.014, "recoil_horizontal": 0.005, "recoil_recovery": 8.0,
		"ads_time": 0.14, "ads_spread_mult": 0.08, "ads_recoil_mult": 0.65,
		"is_auto": true,
	},
	{
		"id": "mp5", "name": "GAU-22/A Cannon", "damage": 25.0, "headshot_mult": 1.6,
		"fire_rate": 850.0, "mag_size": 30, "reload_time": 1.8,
		"base_spread": 1.4, "bloom_per_shot": 0.32, "max_spread": 5.0, "bloom_recovery": 12.0,
		"recoil_vertical": 0.01, "recoil_horizontal": 0.006, "recoil_recovery": 8.0,
		"ads_time": 0.11, "ads_spread_mult": 0.08, "ads_recoil_mult": 0.6,
		"is_auto": true,
	},
	{
		"id": "dmr", "name": "M230 Chain Gun", "damage": 50.0, "headshot_mult": 1.7,
		"fire_rate": 240.0, "mag_size": 20, "reload_time": 2.6,
		"base_spread": 0.35, "bloom_per_shot": 0.65, "max_spread": 3.5, "bloom_recovery": 7.0,
		"recoil_vertical": 0.028, "recoil_horizontal": 0.004, "recoil_recovery": 8.0,
		"ads_time": 0.19, "ads_spread_mult": 0.08, "ads_recoil_mult": 0.72,
		"is_auto": false,
	},
	{
		"id": "aim9", "name": "AIM-9 Sidewinder", "damage": 82.0, "headshot_mult": 1.0,
		"fire_rate": 75.0, "mag_size": 2, "reload_time": 4.0,
		"base_spread": 0.0, "bloom_per_shot": 0.0, "max_spread": 0.0, "bloom_recovery": 8.0,
		"recoil_vertical": 0.005, "recoil_horizontal": 0.0, "recoil_recovery": 8.0,
		"ads_time": 0.16, "ads_spread_mult": 0.0, "ads_recoil_mult": 0.5,
		"is_auto": false,
		"missile_speed": 78.0, "missile_range": 170.0,
	},
	{
		"id": "agm114", "name": "AGM-114 Hellfire", "damage": 95.0, "headshot_mult": 1.0,
		"fire_rate": 55.0, "mag_size": 1, "reload_time": 4.0,
		"base_spread": 0.0, "bloom_per_shot": 0.0, "max_spread": 0.0, "bloom_recovery": 8.0,
		"recoil_vertical": 0.005, "recoil_horizontal": 0.0, "recoil_recovery": 8.0,
		"ads_time": 0.16, "ads_spread_mult": 0.0, "ads_recoil_mult": 0.5,
		"is_auto": false,
		"missile_speed": 62.0, "missile_range": 140.0,
	},
]

const GAME_PROTOCOL_VERSION := 16

const WALK_SPEED := 6.2
const SPRINT_SPEED := 8.8
const CROUCH_SPEED := 2.5
const JUMP_IMPULSE := 6.2
const BASE_FOV := 75.0
const SPRINT_FOV_BOOST := 5.0
## Drone combat profile consumed by the flight controller and presentation.
const DRONE_RADIUS := 0.4
const DRONE_HIT_RADIUS := 0.45
const DRONE_SPAWN_OFFSET := 0.9
const DRONE_ASCEND_KEY := KEY_SPACE
const DRONE_DESCEND_KEY := KEY_CTRL
const DRONE_BOOST_KEY := KEY_SHIFT
var BASE_SENSITIVITY := 0.002

# Session (set by MainMenu, read by Main)
var username := "PILOT"
var room_id := "industrial-public"
# Remote production server by default (war.vaidik.blog via Cloudflare Tunnel).
# Override at runtime with `-- host=<hostname:port>` or in Settings dialog if needed.
var server_host := "war.vaidik.blog"
var selected_map := "industrial"
var selected_mode := "FFA"
var selected_time := "noon"
const TIMES := {"dawn":"DAWN", "noon":"NOON", "dusk":"DUSK", "overcast":"OVERCAST"}

func time_label(id: String) -> String:
	return String(TIMES.get("overcast" if id == "night" else id, TIMES["noon"]))
var selected_primary := "ak47"
var selected_drone_chassis := "heli"
var selected_drone_payload := "ak47"
var selected_secondary := "pistol"
var selected_tertiary := "hmg"
var selected_throwable := "frag"
const THROWABLES := {
	"frag": {"name":"M67 Frag", "description":"3-second fuse • Wide blast • 2 per life", "fuse":3.0, "radius":8.5, "damage":90.0},
	"impact": {"name":"Impact Grenade", "description":"Detonates on impact • Focused blast • 2 per life", "fuse":1.8, "radius":5.5, "damage":75.0}
}
var practice_mode := false
var online_ready := false
var thermal_view := false
var throwables_remaining := 2

# Match state (mirrors server GameState for HUD)
var players: Dictionary = {}
var score_a := 0
var score_b := 0
var winner_id := ""
var local_team := "A"
var local_kills := 0
var local_deaths := 0

# Peaceful exploration toggle
var bot_damage_enabled: bool = true
signal bot_damage_toggled(enabled: bool)

func set_bot_damage(enabled: bool) -> void:
	bot_damage_enabled = enabled
	bot_damage_toggled.emit(enabled)

func toggle_bot_damage() -> bool:
	set_bot_damage(not bot_damage_enabled)
	return bot_damage_enabled

var vsync_enabled: bool = true

func toggle_vsync() -> bool:
	vsync_enabled = not vsync_enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	return vsync_enabled

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var preferences := ConfigFile.new()
	if preferences.load("user://settings.cfg") == OK:
		BASE_SENSITIVITY = clampf(float(preferences.get_value("controls", "sensitivity", BASE_SENSITIVITY)), 0.0005, 0.006)
		selected_primary = String(preferences.get_value("loadout", "primary", "ak47"))
		selected_drone_chassis = String(preferences.get_value("loadout", "drone_chassis", "heli"))
		selected_secondary = String(preferences.get_value("loadout", "secondary", "pistol"))
		selected_tertiary = String(preferences.get_value("loadout", "tertiary", "hmg"))
		selected_throwable = String(preferences.get_value("loadout", "throwable", "frag"))
	validate_loadout()
	if not ["wheels", "tracked", "heli", "wing"].has(selected_drone_chassis): selected_drone_chassis = "heli"
	selected_drone_payload = selected_primary
	randomize()
	if username == "PILOT":
		username = "PILOT_%03d" % (randi() % 900 + 100)

func reset_match_stats() -> void:
	throwables_remaining = 2
	local_kills = 0
	local_deaths = 0
	players.clear()
	players[username] = {"name": username, "kills": 0, "deaths": 0, "health": 100}

func record_local_kill() -> void:
	local_kills += 1
	if not players.has(username):
		players[username] = {"name": username, "kills": local_kills, "deaths": local_deaths, "health": 100}
	else:
		players[username]["kills"] = local_kills

func record_local_death() -> void:
	local_deaths += 1
	if not players.has(username):
		players[username] = {"name": username, "kills": local_kills, "deaths": local_deaths, "health": 0}
	else:
		players[username]["deaths"] = local_deaths

static func max_health_for_chassis(chassis: String) -> int:
	match chassis:
		"tracked": return 220
		"wheels": return 170
		"heli": return 100
		"wing": return 75
		_: return 100

func weapon_index_for_id(wid: String) -> int:
	for i in WEAPONS.size():
		if WEAPONS[i]["id"] == wid: return i
	return 0

func weapon_id_for_index(idx: int) -> String:
	return String(WEAPONS[clampi(idx, 0, WEAPONS.size() - 1)]["id"])

func starting_weapon_index() -> int:
	return weapon_index_for_id(selected_primary)

func equipped_indices() -> Array[int]:
	if selected_drone_chassis == "tracked":
		return [weapon_index_for_id(selected_primary), weapon_index_for_id(selected_secondary), weapon_index_for_id(selected_tertiary)]
	return [weapon_index_for_id(selected_primary), weapon_index_for_id(selected_secondary)]

func validate_loadout() -> void:
	var ids := []
	for weapon in WEAPONS: ids.append(weapon["id"])
	if selected_primary not in ids: selected_primary = "ak47"
	if selected_secondary not in ids or selected_secondary == selected_primary:
		selected_secondary = "pistol" if selected_primary != "pistol" else "ak47"
	if selected_tertiary not in ids or selected_tertiary == selected_primary or selected_tertiary == selected_secondary:
		for fallback in ["hmg", "m2010", "dmr", "mp5"]:
			if fallback != selected_primary and fallback != selected_secondary:
				selected_tertiary = fallback
				break
	if not THROWABLES.has(selected_throwable): selected_throwable = "frag"

func equip(slot: String, id: String) -> void:
	if slot == "primary":
		if id == selected_secondary: selected_secondary = selected_primary
		elif id == selected_tertiary: selected_tertiary = selected_primary
		selected_primary = id
	elif slot == "secondary":
		if id == selected_primary: selected_primary = selected_secondary
		elif id == selected_tertiary: selected_tertiary = selected_secondary
		selected_secondary = id
	elif slot == "tertiary":
		if id == selected_primary: selected_primary = selected_tertiary
		elif id == selected_secondary: selected_secondary = selected_tertiary
		selected_tertiary = id
	else: selected_throwable = id
	validate_loadout()
	selected_drone_payload = selected_primary
	save_settings()

func damage_at_range(config: Dictionary, metres: float) -> float:
	if config["id"] == "m2010": return 100.0
	var start := 20.0
	var end := 90.0
	var minimum := 0.60
	match String(config["id"]):
		"mp5": start = 10; end = 45; minimum = 0.45
		"pistol": start = 10; end = 50; minimum = 0.5
		"dmr": start = 35; end = 150; minimum = 0.75
	return roundf(float(config["damage"]) * lerpf(1, minimum, clampf((metres-start)/(end-start), 0, 1)))

func damage_for_zone(config: Dictionary, metres: float, zone: String) -> int:
	var weapon_id := String(config.get("id", ""))
	var damage := damage_at_range(config, metres)
	match zone:
		"head": damage *= float(config.get("headshot_mult", 1.0))
		"stomach", "arm", "leg": damage *= 0.91 if weapon_id == "dmr" else 0.84
	if weapon_id == "m2010": damage = maxf(damage, 100.0)
	return roundi(damage)

func save_settings() -> void:
	var preferences := ConfigFile.new()
	preferences.set_value("loadout", "primary", selected_primary)
	preferences.set_value("loadout", "drone_chassis", selected_drone_chassis)
	preferences.set_value("loadout", "secondary", selected_secondary)
	preferences.set_value("loadout", "tertiary", selected_tertiary)
	preferences.set_value("loadout", "throwable", selected_throwable)
	preferences.set_value("controls", "sensitivity", BASE_SENSITIVITY)
	preferences.set_value("audio", "sfx", Audio.sfx_volume)
	preferences.save("user://settings.cfg")
