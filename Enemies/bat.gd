class_name Bat
extends CharacterBody2D
## Flying enemy that patrols in the air and chases the player on sight.
## Deals contact damage to the player.

enum State { PATROL, CHASE, HURT, DEAD }

# Node references
@onready var sprites: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

# Configuration
@export var patrol_speed: float = 40.0
@export var chase_speed: float = 80.0
@export var damage: int = 5
@export var detection_range: float = 100.0
@export var lose_sight_range: float = 150.0

## Patrol behavior - bat will fly between patrol points
@export var patrol_distance: float = 60.0  # How far to fly before turning
@export var vertical_bob_amount: float = 8.0  # Slight up/down motion while patrolling
@export var bob_speed: float = 2.0

# State
var current_state: State = State.PATROL
var direction: int = 1
var _player: Player = null
var _patrol_origin: Vector2
var _bob_time: float = 0.0


func _ready() -> void:
	# Defer capturing patrol origin until the node is properly positioned in the scene
	call_deferred("_initialize_patrol")
	
	# Connect health component signals
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	
	# Connect hurtbox signal (when we get hit)
	hurtbox.hurt.connect(_on_hurt)
	
	# Setup hitbox for contact damage
	hitbox.damage = damage
	hitbox.active = true
	hitbox.hit.connect(_on_hitbox_hit)
	
	# Start flying animation
	sprites.play("fly")


func _initialize_patrol() -> void:
	_patrol_origin = global_position


func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			velocity = Vector2.ZERO
	
	move_and_slide()


func _state_patrol(delta: float) -> void:
	# Check for player
	if _detect_player():
		_change_state(State.CHASE)
		return
	
	# Horizontal patrol movement
	velocity.x = direction * patrol_speed
	
	# Vertical bobbing
	_bob_time += delta * bob_speed
	var target_y = _patrol_origin.y + sin(_bob_time) * vertical_bob_amount
	velocity.y = (target_y - global_position.y) * 3.0
	
	# Turn around at patrol bounds
	var distance_from_origin = global_position.x - _patrol_origin.x
	if abs(distance_from_origin) > patrol_distance:
		_turn_around()


func _state_chase(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_change_state(State.PATROL)
		return
	
	var to_player = _player.global_position - global_position
	var dist_to_player = to_player.length()
	
	# Lose sight if too far
	if dist_to_player > lose_sight_range:
		_player = null
		_change_state(State.PATROL)
		return
	
	# Move toward player
	var move_direction = to_player.normalized()
	velocity = move_direction * chase_speed
	
	# Face the player
	if move_direction.x != 0:
		direction = 1 if move_direction.x > 0 else -1
		sprites.flip_h = direction < 0


func _state_hurt(delta: float) -> void:
	# Slow down during hurt
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	
	match new_state:
		State.PATROL:
			sprites.play("fly")
			hitbox.active = true
		State.CHASE:
			sprites.play("fly")
			hitbox.active = true
		State.HURT:
			sprites.play("fly")  # Keep flying, just flash or something
			# Brief invincibility handled by HealthComponent
		State.DEAD:
			sprites.stop()
			hitbox.active = false
			hurtbox.set_deferred("monitoring", false)
			# Disable collision
			set_collision_layer_value(3, false)


func _detect_player() -> bool:
	# Find player in range
	var players = get_tree().get_nodes_in_group("Player")
	for node in players:
		if node is Player:
			var dist = global_position.distance_to(node.global_position)
			if dist <= detection_range:
				_player = node
				return true
	return false


func _turn_around() -> void:
	direction *= -1
	sprites.flip_h = direction < 0


func _on_damaged(_amount: int, _current: int) -> void:
	if current_state == State.DEAD:
		return
	
	_change_state(State.HURT)
	
	# Knockback away from player
	if _player and is_instance_valid(_player):
		var knockback_dir = (global_position - _player.global_position).normalized()
		velocity = knockback_dir * 100.0
	
	# Quick recovery - return to chase/patrol after brief stun
	await get_tree().create_timer(0.2).timeout
	if current_state == State.HURT:
		if _player and is_instance_valid(_player):
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)


func _on_died() -> void:
	_change_state(State.DEAD)
	# Could add death animation here, then queue_free
	await get_tree().create_timer(0.3).timeout
	queue_free()


func _on_hurt(_hitbox_that_hit: HitboxComponent) -> void:
	# This is called when something hits our hurtbox
	# The hurtbox component automatically calls health.take_damage
	pass


func _on_hitbox_hit(_hurtbox_hit: HurtboxComponent) -> void:
	# This is called when our hitbox hits something (the player)
	# The hitbox/hurtbox system handles the damage automatically
	pass


func take_damage(amount: int) -> void:
	## Public method for taking damage (used by player attacks)
	if current_state == State.DEAD:
		return
	health.take_damage(amount)
