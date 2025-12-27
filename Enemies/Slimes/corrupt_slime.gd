class_name CorruptSlime
extends CharacterBody2D
## Terraria-style slime AI - hops toward player, adjusts jump height for terrain.

enum State { IDLE, HOP, AIRBORNE, HURT, DEAD }

# ============ EXPORTS ============
@export_group("Movement")
## Horizontal speed while hopping
@export var hop_speed: float = 60.0
## Base jump velocity (small hops)
@export var jump_velocity: float = -180.0
## Higher jump for obstacles
@export var high_jump_velocity: float = -280.0
## Gravity multiplier
@export var gravity: float = 600.0
## Time between hops when idle
@export var hop_interval: float = 0.8
## Random variance added to hop interval
@export var hop_interval_variance: float = 0.4

@export_group("Detection")
## How far the slime can detect the player
@export var detection_range: float = 120.0
## Range at which slime loses interest
@export var lose_interest_range: float = 180.0
## How far ahead to check for walls (triggers high jump)
@export var wall_check_distance: float = 12.0
## How far down to check for ledges
@export var ledge_check_distance: float = 20.0

@export_group("Combat")
## Damage dealt on contact
@export var damage: int = 1

# ============ NODE REFERENCES ============
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# Optional components - will be found if they exist
var health: HealthComponent = null
var hitbox: Area2D = null
var hurtbox: Area2D = null

# ============ STATE ============
var current_state: State = State.IDLE
var direction: int = 1  # 1 = right, -1 = left
var _player: Player = null
var _hop_timer: float = 0.0
var _squash_tween: Tween = null

# Track if we've been added to enemy group
var _initialized: bool = false


func _ready() -> void:
	# Add to enemy group for player detection
	add_to_group("Enemy")
	
	# Find optional components
	if has_node("HealthComponent"):
		health = $HealthComponent
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	
	if has_node("Hitbox"):
		hitbox = $Hitbox
		# Connect hitbox to deal damage on contact
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if has_node("Hurtbox"):
		hurtbox = $Hurtbox
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Start with a random hop delay so multiple slimes don't sync up
	_hop_timer = randf_range(0.0, hop_interval)
	
	# Play idle animation
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	else:
		sprite.play("new_animation")
	
	_initialized = true


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# State machine
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.HOP:
			_state_hop()
		State.AIRBORNE:
			_state_airborne()
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			velocity.x = 0
	
	move_and_slide()
	
	# Check for landing
	if current_state == State.AIRBORNE and is_on_floor():
		_on_landed()


# ============ STATE FUNCTIONS ============

func _state_idle(delta: float) -> void:
	velocity.x = 0
	
	# Look for player
	_try_detect_player()
	
	# Countdown to next hop
	_hop_timer -= delta
	if _hop_timer <= 0:
		_start_hop()


func _state_hop() -> void:
	# Brief pre-jump squash frame, then launch
	# This state is very short - just initiates the jump
	pass


func _state_airborne() -> void:
	# Maintain horizontal velocity while in air
	velocity.x = direction * hop_speed
	
	# Update facing
	sprite.flip_h = direction < 0


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 200.0 * delta)


# ============ ACTIONS ============

func _start_hop() -> void:
	current_state = State.HOP
	
	# Decide direction
	if _player and is_instance_valid(_player):
		# Hop toward player
		var dir_to_player = sign(_player.global_position.x - global_position.x)
		if dir_to_player != 0:
			direction = int(dir_to_player)
		
		# Check if player is too far and we should lose interest
		var dist = global_position.distance_to(_player.global_position)
		if dist > lose_interest_range:
			_player = null
	else:
		# Random direction change occasionally
		if randf() < 0.3:
			direction *= -1
	
	# Check for obstacles - use high jump if wall ahead
	var needs_high_jump = _check_wall_ahead() or _check_ledge_ahead()
	
	# Squash animation before jump
	_do_squash()
	
	# Small delay for squash, then jump
	await get_tree().create_timer(0.08).timeout
	
	if current_state == State.DEAD:
		return
	
	# Launch!
	velocity.y = high_jump_velocity if needs_high_jump else jump_velocity
	velocity.x = direction * hop_speed
	sprite.flip_h = direction < 0
	
	current_state = State.AIRBORNE
	
	# Stretch animation during jump
	_do_stretch()


func _on_landed() -> void:
	current_state = State.IDLE
	
	# Squash on landing
	_do_land_squash()
	
	# Reset hop timer with some variance
	_hop_timer = hop_interval + randf_range(-hop_interval_variance, hop_interval_variance)
	
	# More aggressive if chasing player
	if _player and is_instance_valid(_player):
		_hop_timer *= 0.6


func _do_squash() -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.08)


func _do_stretch() -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
	_squash_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)


func _do_land_squash() -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.06)
	_squash_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.12)


# ============ DETECTION ============

func _try_detect_player() -> void:
	if _player and is_instance_valid(_player):
		return  # Already tracking
	
	# Find player
	var player = get_tree().get_first_node_in_group("Player")
	if player and player is Player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			_player = player


func _check_wall_ahead() -> bool:
	# Raycast forward to check for walls
	var space_state = get_world_2d().direct_space_state
	
	var start = global_position
	var end = start + Vector2(direction * wall_check_distance, 0)
	
	var query = PhysicsRayQueryParameters2D.create(start, end, 1)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


func _check_ledge_ahead() -> bool:
	# Raycast down ahead to check for ledges/gaps
	var space_state = get_world_2d().direct_space_state
	
	var start = global_position + Vector2(direction * 8, 0)
	var end = start + Vector2(0, ledge_check_distance)
	
	var query = PhysicsRayQueryParameters2D.create(start, end, 1)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	# If no ground ahead, we need to jump
	return result.is_empty()


# ============ DAMAGE ============

func _on_damaged(_amount: int, _current: int) -> void:
	if current_state == State.DEAD:
		return
	
	current_state = State.HURT
	
	# Knockback away from damage source
	if _player and is_instance_valid(_player):
		var knockback_dir = sign(global_position.x - _player.global_position.x)
		velocity.x = knockback_dir * 60.0
		velocity.y = -80.0
	
	# Flash or hurt animation
	_do_hurt_flash()
	
	# Return to idle after brief stun
	await get_tree().create_timer(0.3).timeout
	if current_state != State.DEAD:
		current_state = State.IDLE
		_hop_timer = 0.2  # Quick recovery hop


func _do_hurt_flash() -> void:
	# Simple flash effect
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = Color.WHITE


func _on_died() -> void:
	current_state = State.DEAD
	
	if hitbox:
		hitbox.monitoring = false
	if hurtbox:
		hurtbox.monitoring = false
	
	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, false)
	
	# Death animation - shrink and fade
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.set_parallel(true)
	_squash_tween.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.2)
	_squash_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	_squash_tween.set_parallel(false)
	_squash_tween.tween_callback(queue_free)


func _on_hitbox_area_entered(area: Area2D) -> void:
	"""Deal damage when our hitbox touches the player's hurtbox."""
	if current_state == State.DEAD:
		return
	
	# Check if we hit the player's hurtbox
	var body = area.get_parent()
	if body is Player:
		body.health.take_damage(damage)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if current_state == State.DEAD:
		return
	
	# Check if hit by player attack
	if "damage" in area:
		if health:
			health.take_damage(area.damage)
		else:
			# No health component, just die
			_on_died()


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
	
	if health:
		health.take_damage(amount)
	else:
		_on_died()
