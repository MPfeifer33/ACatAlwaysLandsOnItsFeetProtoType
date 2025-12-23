class_name HealthComponent
extends Node
## Reusable health component - instance onto any entity that needs health.
## Connect to signals to react to damage, healing, and death.

# ============ SIGNALS ============
## Emitted when taking damage. Passes damage amount and new health value.
signal damaged(amount: int, current_health: int)
## Emitted when healing. Passes heal amount and new health value.
signal healed(amount: int, current_health: int)
## Emitted when health reaches zero.
signal died
## Emitted whenever health changes. Useful for UI updates.
signal health_changed(current_health: int, max_health: int)

# ============ CONFIGURATION ============
@export var max_health: int = 10
@export var starting_health: int = -1  ## -1 means use max_health

## If true, entity cannot take damage
@export var invincible: bool = false

## Invincibility frames after taking damage (0 = none)
@export var invincibility_duration: float = 0.0

# ============ STATE ============
var current_health: int
var is_invincible_frames: bool = false

@onready var _invincibility_timer: Timer = Timer.new()


func _ready() -> void:
	# Initialize health
	if starting_health < 0:
		current_health = max_health
	else:
		current_health = mini(starting_health, max_health)
	
	# Setup invincibility timer
	_invincibility_timer.one_shot = true
	_invincibility_timer.timeout.connect(_on_invincibility_ended)
	add_child(_invincibility_timer)
	
	# Emit initial health
	health_changed.emit(current_health, max_health)


# ============ PUBLIC API ============

func take_damage(amount: int) -> void:
	"""Deal damage to this entity. Respects invincibility."""
	if invincible or is_invincible_frames or amount <= 0:
		return
	
	current_health = maxi(0, current_health - amount)
	
	damaged.emit(amount, current_health)
	health_changed.emit(current_health, max_health)
	
	# Start invincibility frames if configured
	if invincibility_duration > 0 and current_health > 0:
		is_invincible_frames = true
		_invincibility_timer.start(invincibility_duration)
	
	# Check for death
	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	"""Restore health to this entity."""
	if amount <= 0 or current_health <= 0:
		return
	
	var previous_health = current_health
	current_health = mini(current_health + amount, max_health)
	
	var actual_heal = current_health - previous_health
	if actual_heal > 0:
		healed.emit(actual_heal, current_health)
		health_changed.emit(current_health, max_health)


func heal_full() -> void:
	"""Restore health to maximum."""
	heal(max_health - current_health)


func kill() -> void:
	"""Instantly kill this entity, bypassing invincibility."""
	current_health = 0
	health_changed.emit(current_health, max_health)
	died.emit()


func set_max_health(new_max: int, heal_to_new_max: bool = false) -> void:
	"""Change max health. Optionally heal to new max."""
	max_health = maxi(1, new_max)
	current_health = mini(current_health, max_health)
	
	if heal_to_new_max:
		current_health = max_health
	
	health_changed.emit(current_health, max_health)


func get_health_percent() -> float:
	"""Returns health as a percentage (0.0 to 1.0)."""
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)


func is_alive() -> bool:
	"""Returns true if current health is above zero."""
	return current_health > 0


func is_full_health() -> bool:
	"""Returns true if at max health."""
	return current_health >= max_health


# ============ INTERNAL ============

func _on_invincibility_ended() -> void:
	is_invincible_frames = false
