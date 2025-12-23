extends Node
## SaveManager - Handles save/load functionality with 3 save slots, respawning, and powerup tracking.

# ============ SIGNALS ============
signal save_completed(slot: int)
signal load_completed(slot: int)
signal slot_deleted(slot: int)

# ============ CONSTANTS ============
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXT: String = ".save"
const MAX_SLOTS: int = 3
const RESPAWN_DELAY: float = 1.5

# ============ CURRENT GAME STATE ============
var current_slot: int = -1  # -1 means no slot loaded
var respawn_position: Vector2 = Vector2.ZERO
var _default_respawn: Vector2 = Vector2.ZERO
var _collected_powerups: Dictionary = {}  # Keyed by slot: {slot_id: {powerup_id: true}}

# Player abilities (synced with Player script)
var abilities: Dictionary = {
	"wall_jump": false,
	"dash": false,
	"double_jump": false,
	"sneak": true,
	"attack": true,
	"throw": true
}

# Game progress
var current_level: String = ""
var play_time_seconds: float = 0.0
var _play_timer_active: bool = false


func _ready() -> void:
	# Ensure save directory exists
	_ensure_save_directory()


func _process(delta: float) -> void:
	# Track play time when actively playing
	if _play_timer_active:
		play_time_seconds += delta


# ============ SAVE DIRECTORY ============

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT


# ============ SAVE GAME ============

func save_game(slot: int) -> bool:
	"""Save the current game state to a slot (1-3)."""
	if slot < 1 or slot > MAX_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	var save_data = _create_save_data()
	var save_path = _get_save_path(slot)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	current_slot = slot
	save_completed.emit(slot)
	print("Game saved to slot ", slot)
	return true


func _create_save_data() -> Dictionary:
	"""Create a dictionary with all data to save."""
	return {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"play_time": play_time_seconds,
		"current_level": current_level,
		"respawn_position": {
			"x": respawn_position.x,
			"y": respawn_position.y
		},
		"abilities": abilities.duplicate(),
		"collected_powerups": _get_current_slot_powerups(),
		"player_stats": _get_player_stats()
	}


func _get_player_stats() -> Dictionary:
	"""Get current player stats for saving."""
	var player = GameManager.get_player()
	if player:
		return {
			"max_health": player.health.max_health,
			"attack_damage": player.attack_damage
		}
	return {
		"max_health": 10,
		"attack_damage": 3
	}


# ============ LOAD GAME ============

func load_game(slot: int) -> bool:
	"""Load a game from a slot (1-3)."""
	if slot < 1 or slot > MAX_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		push_error("Save file not found: " + save_path)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		return false
	
	var save_data = json.get_data()
	_apply_save_data(save_data)
	
	current_slot = slot
	load_completed.emit(slot)
	print("Game loaded from slot ", slot)
	return true


func _apply_save_data(data: Dictionary) -> void:
	"""Apply loaded save data to current game state."""
	# Basic data
	play_time_seconds = data.get("play_time", 0.0)
	current_level = data.get("current_level", "")
	
	# Respawn position
	var resp_data = data.get("respawn_position", {})
	respawn_position = Vector2(
		resp_data.get("x", 0.0),
		resp_data.get("y", 0.0)
	)
	
	# Abilities
	var saved_abilities = data.get("abilities", {})
	for ability_name in abilities.keys():
		if ability_name in saved_abilities:
			abilities[ability_name] = saved_abilities[ability_name]
	
	# Collected powerups - store per-slot
	if not _collected_powerups.has(current_slot):
		_collected_powerups[current_slot] = {}
	else:
		_collected_powerups[current_slot].clear()
	
	var powerup_list = data.get("collected_powerups", [])
	for powerup_id in powerup_list:
		_collected_powerups[current_slot][powerup_id] = true
	
	# Apply to player if exists
	_apply_to_player()


func _apply_to_player(set_position: bool = true) -> void:
	"""Apply loaded data to the player node."""
	var player = GameManager.get_player()
	if not player:
		return
	
	# Apply abilities
	player.can_wall_jump = abilities["wall_jump"]
	player.can_dash = abilities["dash"]
	player.can_double_jump = abilities["double_jump"]
	player.can_sneak = abilities["sneak"]
	player.can_attack = abilities["attack"]
	player.can_throw = abilities["throw"]
	
	# Apply position only when loading a save
	if set_position and respawn_position != Vector2.ZERO:
		player.global_position = respawn_position


# ============ SLOT INFO ============

func get_slot_info(slot: int) -> Dictionary:
	"""Get info about a save slot for display in UI."""
	if slot < 1 or slot > MAX_SLOTS:
		return {}
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return {"empty": true}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {"empty": true}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {"empty": true, "corrupted": true}
	
	var data = json.get_data()
	
	# Count abilities unlocked
	var abilities_unlocked = 0
	var saved_abilities = data.get("abilities", {})
	for ability in saved_abilities.values():
		if ability:
			abilities_unlocked += 1
	
	return {
		"empty": false,
		"timestamp": data.get("timestamp", "Unknown"),
		"play_time": data.get("play_time", 0.0),
		"level": data.get("current_level", "Unknown"),
		"abilities_unlocked": abilities_unlocked,
		"powerups_collected": data.get("collected_powerups", []).size()
	}


func has_save_data(slot: int) -> bool:
	"""Check if a slot has save data."""
	var info = get_slot_info(slot)
	return not info.get("empty", true)


func delete_save(slot: int) -> bool:
	"""Delete a save slot."""
	if slot < 1 or slot > MAX_SLOTS:
		return false
	
	var save_path = _get_save_path(slot)
	
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT)
			slot_deleted.emit(slot)
			print("Deleted save slot ", slot)
			return true
	
	return false


# ============ PLAY TIME ============

func start_play_timer() -> void:
	_play_timer_active = true


func stop_play_timer() -> void:
	_play_timer_active = false


func get_formatted_play_time() -> String:
	"""Get play time as formatted string (HH:MM:SS)."""
	var total_seconds: int = int(play_time_seconds)
	@warning_ignore("integer_division")
	var hours: int = total_seconds / 3600
	@warning_ignore("integer_division")
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func format_play_time(seconds: float) -> String:
	"""Format arbitrary seconds as HH:MM:SS."""
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%02d:%02d:%02d" % [h, m, s]


# ============ NEW GAME ============

func start_new_game(slot: int) -> void:
	"""Start a fresh game in the specified slot."""
	current_slot = slot
	
	# Reset all progress
	respawn_position = Vector2.ZERO
	_collected_powerups.clear()
	play_time_seconds = 0.0
	current_level = ""
	
	# Reset abilities to defaults
	abilities = {
		"wall_jump": false,
		"dash": false,
		"double_jump": false,
		"sneak": true,
		"attack": true,
		"throw": true
	}
	
	# Apply abilities to player (don't set position - let them start where they are)
	_apply_to_player(false)
	
	# Start tracking play time
	start_play_timer()
	
	# Save immediately to create the slot
	save_game(slot)


# ============ RESPAWN SYSTEM ============

func set_respawn_position(pos: Vector2) -> void:
	respawn_position = pos
	print("Saved at hospital: ", pos)
	# Auto-save when hitting a checkpoint
	if current_slot > 0:
		save_game(current_slot)


func set_default_respawn(pos: Vector2) -> void:
	"""Call this when the level loads to set a fallback spawn point."""
	_default_respawn = pos
	if respawn_position == Vector2.ZERO:
		respawn_position = pos


func respawn(player: Player) -> void:
	"""Called when player dies. Handles the full respawn sequence."""
	if not player:
		push_error("SaveManager.respawn() called with null player!")
		return
	
	var spawn_pos = respawn_position if respawn_position != Vector2.ZERO else _default_respawn
	
	if spawn_pos == Vector2.ZERO:
		push_warning("No respawn position set! Using player's current position.")
		spawn_pos = player.global_position
	
	await player.get_tree().create_timer(RESPAWN_DELAY).timeout
	_reset_player(player, spawn_pos)


func _reset_player(player: Player, spawn_pos: Vector2) -> void:
	"""Reset all player state for respawn."""
	player.global_position = spawn_pos
	player.velocity = Vector2.ZERO
	
	player._is_dead = false
	player.current_state = Player.State.NORMAL
	
	player.health.current_health = player.health.max_health
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)
	
	player.hitbox.monitoring = false
	player.hurtbox.monitoring = true
	
	player.cat_sprite.play(&"idle")
	player._current_anim = &"idle"
	
	player._is_throwing = false
	player._has_double_jumped = false
	
	print("Player respawned at: ", spawn_pos)


# ============ POWERUP TRACKING ============

func _get_current_slot_powerups() -> Array:
	"""Get list of collected powerup IDs for current slot."""
	if current_slot < 1:
		return []
	if not _collected_powerups.has(current_slot):
		return []
	return _collected_powerups[current_slot].keys()


func mark_powerup_collected(powerup_id: String) -> void:
	"""Mark a powerup as collected so it doesn't respawn."""
	if current_slot < 1:
		push_warning("Cannot mark powerup collected - no save slot loaded")
		return
	
	# Ensure slot dictionary exists
	if not _collected_powerups.has(current_slot):
		_collected_powerups[current_slot] = {}
	
	_collected_powerups[current_slot][powerup_id] = true
	# Auto-save on powerup collection
	save_game(current_slot)


func is_powerup_collected(powerup_id: String) -> bool:
	"""Check if a powerup has already been collected in the current slot."""
	if current_slot < 1:
		return false  # No slot loaded, powerup should appear
	
	if not _collected_powerups.has(current_slot):
		return false
	
	return _collected_powerups[current_slot].get(powerup_id, false)


func reset_powerups() -> void:
	"""Reset collected powerups for the current slot (for new game)."""
	if current_slot > 0:
		_collected_powerups[current_slot] = {}
	else:
		# If no slot, clear everything (shouldn't normally happen)
		_collected_powerups.clear()


# ============ ABILITY SYNC ============

func unlock_ability(ability_name: String) -> void:
	"""Unlock an ability and sync to player."""
	if ability_name in abilities:
		abilities[ability_name] = true
		# Apply only this specific ability to the player
		var player = GameManager.get_player()
		if player:
			match ability_name:
				"wall_jump":
					player.can_wall_jump = true
				"dash":
					player.can_dash = true
				"double_jump":
					player.can_double_jump = true
				"sneak":
					player.can_sneak = true
				"attack":
					player.can_attack = true
				"throw":
					player.can_throw = true
		# Auto-save
		if current_slot > 0:
			save_game(current_slot)


func sync_abilities_from_player() -> void:
	"""Sync abilities from player to SaveManager (call after player changes)."""
	var player = GameManager.get_player()
	if player:
		abilities["wall_jump"] = player.can_wall_jump
		abilities["dash"] = player.can_dash
		abilities["double_jump"] = player.can_double_jump
		abilities["sneak"] = player.can_sneak
		abilities["attack"] = player.can_attack
		abilities["throw"] = player.can_throw
