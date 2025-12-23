class_name Enemy
extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }

@onready var sprites: AnimatedSprite2D = $AnimatedSprite2D
@onready var patrol_ray: RayCast2D = $PatrolRay
@onready var chase_ray: RayCast2D = $AttackFollowRay
@onready var wall_detector: RayCast2D = $WallDetector
@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

# Configuration
@export var gravity: float = 1200.0
@export var patrol_speed: float = 40.0
@export var chase_speed: float = 90.0
@export var damage: int = 10
@export var attack_range: float = 20.0
@export var lose_sight_range: float = 120.0
@export var attack_cooldown: float = 1.0
@export var attack_windup: float = 0.25
@export var attack_active: float = 0.15

# State
var current_state: State = State.PATROL
var direction: int = 1
var _player: Player = null
var _attack_cooldown_timer: float = 0.0
var _has_hit_player: bool = false
var _attack_windup_timer: float = 0.0
var _attack_active_timer: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	sprites.animation_finished.connect(_on_animation_finished)
	hitbox.monitoring = false
	sprites.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta
	
	match current_state:
		State.PATROL:
			_state_patrol()
		State.CHASE:
			_state_chase()
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			velocity.x = 0
	
	move_and_slide()


func _state_patrol() -> void:
	if _detect_player():
		_change_state(State.CHASE)
		return
	
	velocity.x = direction * patrol_speed
	
	if _should_turn():
		_turn_around()


func _state_chase() -> void:
	if not _player or not is_instance_valid(_player):
		_change_state(State.PATROL)
		return
	
	var dist_to_player = global_position.distance_to(_player.global_position)
	
	# Update direction toward player first (before line of sight check)
	var dir_to_player = sign(_player.global_position.x - global_position.x)
	if dir_to_player != 0:
		direction = int(dir_to_player)
		sprites.flip_h = direction < 0
		# Update chase ray to face the player
		chase_ray.target_position.x = abs(chase_ray.target_position.x) * direction
	
	if dist_to_player > lose_sight_range or not _has_line_of_sight():
		_player = null
		_change_state(State.PATROL)
		return
	
	if dist_to_player <= attack_range and _attack_cooldown_timer <= 0:
		_change_state(State.ATTACK)
		return
	
	velocity.x = direction * chase_speed


func _state_attack(delta: float) -> void:
	velocity.x = 0
	
	# Keep tracking the player during attack so we don't lose sight
	if _player and is_instance_valid(_player):
		var dir_to_player = sign(_player.global_position.x - global_position.x)
		if dir_to_player != 0:
			direction = int(dir_to_player)
			sprites.flip_h = direction < 0
			chase_ray.target_position.x = abs(chase_ray.target_position.x) * direction
	
	if _attack_windup_timer > 0:
		_attack_windup_timer -= delta
		if _attack_windup_timer <= 0:
			hitbox.monitoring = true
			_has_hit_player = false
			_attack_active_timer = attack_active
		return
	
	if _attack_active_timer > 0:
		_attack_active_timer -= delta
		if _attack_active_timer <= 0:
			hitbox.monitoring = false


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 400.0 * delta)


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	if current_state == State.ATTACK:
		hitbox.monitoring = false
		_has_hit_player = false
	
	current_state = new_state
	
	match new_state:
		State.PATROL:
			sprites.play("walk")
		State.CHASE:
			sprites.play("walk")
		State.ATTACK:
			sprites.play("attack")
			_attack_cooldown_timer = attack_cooldown
			_attack_windup_timer = attack_windup
			_attack_active_timer = 0.0
		State.HURT:
			sprites.play("got_hit")
		State.DEAD:
			sprites.play("died")
			hitbox.monitoring = false
			hurtbox.monitoring = false
			set_collision_layer_value(3, false)


func _detect_player() -> bool:
	chase_ray.target_position.x = abs(chase_ray.target_position.x) * direction
	chase_ray.force_raycast_update()
	
	if chase_ray.is_colliding():
		var collider = chase_ray.get_collider()
		if collider is Player:
			_player = collider
			return true
	
	chase_ray.target_position.x = abs(chase_ray.target_position.x) * -direction
	chase_ray.force_raycast_update()
	
	if chase_ray.is_colliding():
		var collider = chase_ray.get_collider()
		if collider is Player:
			_player = collider
			direction = -direction
			sprites.flip_h = direction < 0
			return true
	
	chase_ray.target_position.x = abs(chase_ray.target_position.x) * direction
	return false


func _has_line_of_sight() -> bool:
	if not _player or not is_instance_valid(_player):
		return false
	
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	
	if dist > lose_sight_range:
		return false
	
	# Store original target for restoration
	var original_target = chase_ray.target_position
	
	# Temporarily aim directly at player for line of sight check
	chase_ray.target_position = to_player
	chase_ray.force_raycast_update()
	
	var has_sight = false
	if chase_ray.is_colliding():
		has_sight = chase_ray.get_collider() is Player
	else:
		# No collision means clear path to player (within range)
		has_sight = true
	
	# Restore ray to face current direction (for visual consistency)
	chase_ray.target_position.x = abs(original_target.x) * direction
	chase_ray.target_position.y = 0
	
	return has_sight


func _should_turn() -> bool:
	patrol_ray.target_position.x = abs(patrol_ray.target_position.x) * direction
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * direction
	patrol_ray.force_raycast_update()
	wall_detector.force_raycast_update()
	
	return not patrol_ray.is_colliding() or wall_detector.is_colliding()


func _turn_around() -> void:
	direction *= -1
	sprites.flip_h = direction < 0


func _on_damaged(_amount: int, _current: int) -> void:
	if current_state == State.DEAD:
		return
	
	_change_state(State.HURT)
	if _player and is_instance_valid(_player):
		var knockback_dir = sign(global_position.x - _player.global_position.x)
		velocity.x = knockback_dir * 80.0
		velocity.y = -100.0
	else:
		velocity.x = -direction * 80.0
		velocity.y = -100.0


func _on_died() -> void:
	_change_state(State.DEAD)


func _on_animation_finished() -> void:
	match sprites.animation:
		"got_hit":
			if _player and is_instance_valid(_player) and _has_line_of_sight():
				_change_state(State.CHASE)
			else:
				_change_state(State.PATROL)
		"died":
			queue_free()
		"attack":
			if _player and is_instance_valid(_player) and _has_line_of_sight():
				_change_state(State.CHASE)
			else:
				_change_state(State.PATROL)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if current_state == State.DEAD:
		return
	if "damage" in area:
		health.take_damage(area.damage)


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
	health.take_damage(amount)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if _has_hit_player:
		return
	var body = area.get_parent()
	if body is Player:
		body.health.take_damage(damage)
		_has_hit_player = true
