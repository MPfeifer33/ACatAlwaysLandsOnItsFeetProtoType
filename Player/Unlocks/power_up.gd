class_name AbilityPowerUp
extends Node2D
## Base class for all powerups. Extend this or use the exported ability_name.

## Which ability flag to enable on the player
@export_enum("wall_jump", "dash", "double_jump", "sneak", "attack", "throw") var ability_name: String = ""

## Optional: unique ID for save system (so collected powerups stay collected)
@export var powerup_id: String = ""

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D

# Visual feedback settings
var _bob_amount: float = 4.0
var _bob_speed: float = 2.0
var _initial_y: float = 0.0


func _ready() -> void:
	_initial_y = position.y
	
	# Set up collision to detect player (layer 2)
	area.collision_layer = 0
	area.collision_mask = 2
	area.body_entered.connect(_on_body_entered)
	
	# Check if already collected (for save system)
	if powerup_id != "" and SaveManager.is_powerup_collected(powerup_id):
		queue_free()


func _process(_delta: float) -> void:
	# Gentle bobbing animation
	position.y = _initial_y + sin(Time.get_ticks_msec() * 0.001 * _bob_speed) * _bob_amount


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_collect(body as Player)


func _collect(player: Player) -> void:
	# Apply the powerup effect
	_apply_effect(player)
	
	# Mark as collected for save system
	if powerup_id != "":
		SaveManager.mark_powerup_collected(powerup_id)
	
	# Visual/audio feedback (add particles, sound, etc. here)
	_play_collect_effect()
	
	# Remove the powerup
	queue_free()


func _apply_effect(player: Player) -> void:
	## Override this in subclasses for custom effects, or use ability_name export
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
		_:
			push_warning("PowerUp: No ability_name set!")
			return
	
	# Sync to SaveManager for persistence
	SaveManager.unlock_ability(ability_name)
	print("Unlocked ability: ", ability_name)


func _play_collect_effect() -> void:
	## Override for custom effects. Could add particles, screen flash, sound, etc.
	# TODO: Add collect sound
	# TODO: Add particle burst
	pass
