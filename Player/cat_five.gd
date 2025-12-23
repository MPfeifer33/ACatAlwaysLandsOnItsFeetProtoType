class_name Player
extends CharacterBody2D

# Movement constants
const SPEED = 150.0
const JUMP_VELOCITY = -350.0
const ACCELERATION = 800.0
const FRICTION = 1200.0
const WALL_CLIMB_SPEED = 65.0
const SNEAK_SPEED_MULTIPLIER = 0.5

# Dash constants
const DASH_SPEED = 400.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 3.0

# Combat constants
const NINJA_STAR_SPEED = 400.0
const NINJA_STAR_CD = 0.5
const ATTACK_DURATION = 0.2
const THROW_WINDUP = 0.18  # Delay before star spawns (sync with animation)
const THROW_VELOCITY_DAMPEN = 0.4  # Slow down when throwing
const THROW_RECOVERY = 0.25  # Total time locked in throw (slightly longer than anim)
const HURT_DURATION = 0.4  # Time before player regains control

# Ledge climb constants
const LEDGE_CLIMB_OFFSET = Vector2(12.0, -6.0)  # Final offset when climb completes (x forward, y up onto ledge)

# Animation thresholds
const RUN_THRESHOLD = 185.0
const WALK_THRESHOLD = 10.0
const DUST_THRESHOLD = 410.0

# Animation blend speeds (lower = smoother transitions)
# Note: These constants are available for future animation blending features
const ANIM_BLEND_FAST = 0.1
const ANIM_BLEND_NORMAL = 0.15

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

@export var dust_particles: PackedScene = preload("res://Player/landing_dust.tscn")
@export var ninja_star: PackedScene = preload("res://Player/ninja_star.tscn")

# Node references - using @onready for cleaner initialization
@onready var cat_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var idle_timer: Timer = $IdleTimer
@onready var sit_timer: Timer = $SitTimer
@onready var sleep_timer: Timer = $SleepTimer
@onready var hitbox: Area2D = $Hitbox
@onready var dust_point: Marker2D = $DustParticlePoint
@onready var fire_point: Marker2D = $FirePoint
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Area2D = $Hurtbox

# Timers that may be created dynamically
var ninja_star_timer: Timer
var dash_timer: Timer
var dash_cooldown_timer: Timer
var attack_timer: Timer
var throw_windup_timer: Timer
var throw_recovery_timer: Timer
var hurt_timer: Timer

# Shader reference for glitch effect
var _tilemap_material: ShaderMaterial = null

enum State { NORMAL, ON_WALL, DASHING, ATTACKING, HURT, DEAD, LEDGE_GRAB }

# State tracking
var current_state: State = State.NORMAL
var _previous_state: State = State.NORMAL

# Ledge climb
var _ledge_climb_target_pos: Vector2 = Vector2.ZERO
var _ledge_climb_start_pos: Vector2 = Vector2.ZERO
var _ledge_climb_timer: float = 0.0
var _ledge_grab_cooldown: float = 0.0  # Prevents rapid re-triggering
const LEDGE_GRAB_COOLDOWN_TIME = 0.5
const LEDGE_CLIMB_DURATION = 0.55  # 10 frames at 18 FPS

# Physics tracking
var _was_on_floor: bool = false
var _last_velocity_y: float = 0.0

# Ability unlock flags
var can_wall_jump: bool = false
var can_dash: bool = false
var can_double_jump: bool = false
var can_sneak: bool = false
var can_attack: bool = true
var can_throw: bool = true

# Runtime ability tracking
var _has_double_jumped: bool = false
var _dash_direction: float = 0.0
var _is_sneaking: bool = false
var attack_damage: int = 3

# Animation state tracking for smooth transitions
var _current_anim: StringName = &""
var _target_anim: StringName = &""
var _facing_direction: float = 1.0  # 1 = right, -1 = left
var _is_throwing: bool = false  # Lock to prevent throw animation interruption
var _is_dead: bool = false

# Cached input values (reduces Input polling)
var _input_direction: float = 0.0
var _input_vertical: float = 0.0


func _ready() -> void:
	_setup_timers()
	_setup_hitbox()
	_setup_glitch_shader()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	# Connect animation finished signal for smoother chaining
	if cat_sprite:
		cat_sprite.animation_finished.connect(_on_animation_finished)


func _on_damaged(_amount: int, _current: int) -> void:
	if _is_dead:
		return
	_change_state(State.HURT)
	_stop_idle_chain()
	_is_throwing = false
	cat_sprite.play(&"hurt")
	_current_anim = &"hurt"
	# Knockback
	velocity.x = -_facing_direction * 100.0
	velocity.y = -150.0
	# Timer to recover (backup in case animation_finished doesn't fire)
	hurt_timer.start()


func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	_change_state(State.DEAD)
	_stop_idle_chain()
	_is_throwing = false
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitoring", false)
	cat_sprite.play(&"died")
	_current_anim = &"died"


func _on_hurtbox_area_entered(area: Area2D) -> void:
	# When enemy hitbox touches us
	if "damage" in area:
		health.take_damage(area.damage)

func _setup_glitch_shader() -> void:
	# Try to find tilemap and cache its material for glitch effect
	await get_tree().process_frame  # Wait for scene to be ready
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if tilemap and tilemap.material is ShaderMaterial:
		_tilemap_material = tilemap.material


func _setup_timers() -> void:
	# Only create timers if they don't exist - uses a helper to reduce repetition
	_ensure_timer("DashTimer", DASH_DURATION, _on_dash_timer_timeout)
	_ensure_timer("DashCooldownTimer", DASH_COOLDOWN, Callable())
	_ensure_timer("AttackTimer", ATTACK_DURATION, _on_attack_timer_timeout)
	_ensure_timer("NinjaStarTimer", NINJA_STAR_CD, _on_ninja_star_cd_timeout)
	_ensure_timer("ThrowWindupTimer", THROW_WINDUP, _on_throw_windup_complete)
	_ensure_timer("ThrowRecoveryTimer", THROW_RECOVERY, _on_throw_recovery_complete)
	_ensure_timer("HurtTimer", HURT_DURATION, _on_hurt_timer_timeout)


func _ensure_timer(timer_name: String, wait_time: float, callback: Callable) -> Timer:
	var timer: Timer
	if has_node(timer_name):
		timer = get_node(timer_name)
	else:
		timer = Timer.new()
		timer.name = timer_name
		timer.one_shot = true
		timer.wait_time = wait_time
		add_child(timer)
		if callback.is_valid():
			timer.timeout.connect(callback)
	
	# Update reference
	match timer_name:
		"DashTimer": dash_timer = timer
		"DashCooldownTimer": dash_cooldown_timer = timer
		"AttackTimer": attack_timer = timer
		"NinjaStarTimer": ninja_star_timer = timer
		"ThrowWindupTimer": throw_windup_timer = timer
		"ThrowRecoveryTimer": throw_recovery_timer = timer
		"HurtTimer": hurt_timer = timer
	
	return timer


func _setup_hitbox() -> void:
	if has_node("Hitbox"):
		hitbox = $Hitbox
		# Player hitbox on layer 4 (PlayerHitbox), detects layer 3 (Enemy) where enemy hurtboxes live
		hitbox.collision_layer = 8  # Bit 8 = layer 4 (PlayerHitbox)
		hitbox.collision_mask = 4   # Bit 4 = layer 3 (Enemy)
		hitbox.monitoring = false
		# Connect area_entered since hurtboxes are Area2Ds
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
		return
	
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 8  # Layer 4 = PlayerHitbox
	hitbox.collision_mask = 4   # Detect layer 3 = Enemy
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(27.25, 20)
	collision.shape = shape
	collision.position = Vector2(20, 0)
	
	hitbox.add_child(collision)
	add_child(hitbox)
	hitbox.monitoring = false
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	# Cache input once per frame (more efficient than polling multiple times)
	_cache_input()
	
	# Update cooldowns
	if _ledge_grab_cooldown > 0:
		_ledge_grab_cooldown -= delta
	
	# State machine
	_check_transitions()
	_process_state(delta)
	
	# Capture velocity before move_and_slide (for landing dust detection)
	var pre_move_velocity_y = velocity.y
	
	move_and_slide()
	
	# Landing dust effect - use pre-move velocity since move_and_slide zeroes it on landing
	if is_on_floor() and not _was_on_floor:
		print("Landed! pre_move_velocity_y: ", pre_move_velocity_y, " threshold: ", DUST_THRESHOLD)
		if absf(pre_move_velocity_y) > DUST_THRESHOLD:
			print("Spawning dust!")
			_spawn_dust()
	
	# Update tracking variables
	_was_on_floor = is_on_floor()
	_last_velocity_y = velocity.y
	
	# Update glitch shader based on movement
	_update_glitch_shader()


func _cache_input() -> void:
	_input_direction = Input.get_axis("move_left", "move_right")
	_input_vertical = Input.get_axis("move_up", "move_down")


func _process_state(delta: float) -> void:
	match current_state:
		State.NORMAL:
			_state_normal(delta)
		State.ON_WALL:
			_state_on_wall(delta)
		State.DASHING:
			_state_dashing(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)
		State.LEDGE_GRAB:
			_state_ledge_grab(delta)



func _update_glitch_shader() -> void:
	if not _tilemap_material:
		return
	
	# Calculate target intensity based on speed
	var speed = absf(velocity.x)
	var target_intensity := 0.0
	
	if current_state == State.DASHING:
		target_intensity = 0.6  # Strong glitch when dashing
	elif speed > RUN_THRESHOLD:
		target_intensity = 0.25  # Medium glitch when running
	elif speed > WALK_THRESHOLD:
		target_intensity = 0.1  # Subtle glitch when walking
	
	# Smoothly lerp to target
	var current = _tilemap_material.get_shader_parameter("glitch_intensity")
	if current == null:
		current = 0.0
	var new_intensity = lerpf(current, target_intensity, 0.15)
	_tilemap_material.set_shader_parameter("glitch_intensity", new_intensity)


func _spawn_dust() -> void:
	if not dust_particles:
		print("ERROR: dust_particles is null!")
		return
	var dust = dust_particles.instantiate()
	print("Dust instantiated: ", dust, " adding to: ", get_parent())
	get_parent().add_child(dust)
	dust.global_position = dust_point.global_position
	print("Dust position: ", dust.global_position)

func _throw_star() -> void:
	if not ninja_star or not can_throw or _is_throwing:
		return
	
	# Commit to the throw - dampen velocity for weight
	velocity.x *= THROW_VELOCITY_DAMPEN
	
	# Start animation immediately (windup)
	_is_throwing = true
	cat_sprite.stop()
	cat_sprite.play(&"throw_star")
	cat_sprite.frame = 0
	_current_anim = &"throw_star"
	
	# Delay the actual projectile spawn to sync with animation
	throw_windup_timer.start()
	
	# Recovery timer ensures we exit throw state even if animation signal fails
	throw_recovery_timer.start()
	
	can_throw = false
	ninja_star_timer.start()


func _on_throw_windup_complete() -> void:
	# NOW spawn the star - synced with the release frame of animation
	if not ninja_star:
		return
	
	var star = ninja_star.instantiate()
	get_parent().add_child(star)
	
	# Adjust spawn position for wall throws
	var spawn_pos = fire_point.global_position
	if is_on_wall():
		var wall_offset = Vector2(0, -4)
		spawn_pos += wall_offset
	
	star.global_position = spawn_pos
	
	# Use wall normal if on wall, otherwise use facing direction
	var direction: float = get_wall_normal().x if is_on_wall() else _facing_direction
	star.set_direction(direction)
	
	# TODO: Add throw-specific particle effect here if desired
	#_spawn_throw_dust()


func _on_throw_recovery_complete() -> void:
	# Backup to clear throw state - ensures no sticking
	if _is_throwing:
		_is_throwing = false
		if current_state == State.ON_WALL:
			_queue_animation(&"wall_grab")
		elif current_state == State.NORMAL:
			_update_normal_animation()


func _on_ninja_star_cd_timeout() -> void:
	can_throw = true


# ============ STATE FUNCTIONS ============

func _state_normal(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_has_double_jumped = false
	
	# Start coyote time BEFORE jump check so it's available on the same frame
	if _was_on_floor and not is_on_floor() and velocity.y >= 0:
		coyote_timer.start()
	
	# Buffered jump check
	var can_jump = is_on_floor() or not coyote_timer.is_stopped()
	if not jump_buffer_timer.is_stopped() and can_jump:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer.stop()
		coyote_timer.stop()
	
	_process_movement(delta)
	_update_normal_animation()


func _state_on_wall(_delta: float) -> void:
	# Handle throwing while on wall
	if Input.is_action_just_pressed("throw_star") and ninja_star_timer.is_stopped():
		_throw_star()
	
	velocity.x = 0
	_has_double_jumped = false
	
	# Wall jump
	if Input.is_action_pressed("jump") and can_wall_jump:
		_stop_idle_chain()
		_is_throwing = false  # Cancel throw animation on wall jump
		velocity.y = JUMP_VELOCITY
		velocity.x = get_wall_normal().x * SPEED
		jump_buffer_timer.stop()
		_change_state(State.NORMAL)
		return
	
	# Don't change animation while throwing
	if _is_throwing:
		return
	
	# Wall climbing
	if _input_vertical != 0:
		var desired_velocity = _input_vertical * WALL_CLIMB_SPEED
		
		# Check for ceiling when climbing UP to prevent twitching at wall tops
		if _input_vertical < 0:
			if _is_ceiling_above():
				# Can't climb up - blocked by ceiling/wall top
				velocity.y = 0
				cat_sprite.speed_scale = 1.0
				_queue_animation(&"wall_grab")
				return
			
			# Check for ledge while climbing up (only if not blocked)
			if _check_for_ledge_on_wall():
				_start_ledge_grab()
				return
		
		velocity.y = desired_velocity
		_queue_animation(&"wall_climb")
		cat_sprite.speed_scale = -1.0 if _input_vertical < 0 else 1.0
	else:
		velocity.y = 5
		cat_sprite.speed_scale = 1.0
		_queue_animation(&"wall_grab")


func _is_ceiling_above() -> bool:
	"""Check if there's a ceiling/obstacle directly above that would block upward movement."""
	var space_state = get_world_2d().direct_space_state
	
	# Cast a short ray upward from head area
	var start = global_position + Vector2(0, -8)
	var end = start + Vector2(0, -12)  # Check a bit ahead of where we'd move
	
	var query = PhysicsRayQueryParameters2D.create(start, end, 1)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


func _state_dashing(_delta: float) -> void:
	velocity.x = _dash_direction * DASH_SPEED
	
	# Still apply gravity during dash
	if not is_on_floor():
		velocity.y += gravity * get_physics_process_delta_time()


func _state_attacking(delta: float) -> void:
	# Small forward momentum during attack
	var attack_boost = 30.0 if is_on_floor() else 10.0
	velocity.x += _facing_direction * attack_boost * delta
	velocity.x = clampf(velocity.x, -SPEED * 1.2, SPEED * 1.2)
	
	if not is_on_floor():
		velocity.y += gravity * delta


func _state_hurt(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	# Friction to slow down knockback
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.5 * delta)


func _state_dead(_delta: float) -> void:
	# Just sit there, no input
	velocity = Vector2.ZERO


func _state_ledge_grab(delta: float) -> void:
	# Check for interrupt - jump or attack cancels climb
	if Input.is_action_just_pressed("jump"):
		_change_state(State.NORMAL)
		velocity.y = JUMP_VELOCITY
		_update_normal_animation()
		return
	
	if Input.is_action_just_pressed("attack") and can_attack:
		_start_attack()
		return
	
	# Freeze velocity during climb
	velocity = Vector2.ZERO
	
	# Smoothly lerp position during climb animation
	if _ledge_climb_timer > 0:
		_ledge_climb_timer -= delta
		var progress = 1.0 - (_ledge_climb_timer / LEDGE_CLIMB_DURATION)
		# Use smooth easing for natural movement
		var eased_progress = ease(progress, 0.5)  # Slight ease-out
		global_position = _ledge_climb_start_pos.lerp(_ledge_climb_target_pos, eased_progress)


# ============ LEDGE DETECTION ============

func _check_for_ledge() -> bool:
	"""Check if there's a grabbable ledge while falling. Returns true if ledge grab should trigger."""
	# Only check while falling with meaningful downward velocity
	# Higher threshold prevents grabbing tiles we're jumping past
	if velocity.y < 50.0:
		return false
	
	# Don't grab ledges if on floor
	if is_on_floor():
		return false
	
	# Cooldown check
	if _ledge_grab_cooldown > 0:
		return false
	
	# Need to be pressing toward the wall to grab
	if _input_direction == 0:
		return false
	
	return _detect_ledge(_input_direction)


func _check_for_ledge_on_wall() -> bool:
	"""Check if there's a grabbable ledge while wall climbing. Returns true if ledge grab should trigger."""
	# Cooldown check
	if _ledge_grab_cooldown > 0:
		return false
	
	# Get direction we're facing (into the wall)
	var wall_normal = get_wall_normal()
	var check_direction = -wall_normal.x  # Direction INTO the wall
	
	if check_direction == 0:
		return false
	
	return _detect_ledge(check_direction)


func _detect_ledge(check_direction: float) -> bool:
	"""Shared ledge detection logic. Returns true if a valid ledge is found."""
	var space_state = get_world_2d().direct_space_state
	var ray_length = 16.0  # A bit longer to catch ledges better
	
	# Upper ray (head level) - should be EMPTY (air above ledge)
	# Check a bit higher to have a bigger detection window
	var upper_start = global_position + Vector2(0, -10)
	var upper_end = upper_start + Vector2(check_direction * ray_length, 0)
	
	# Lower ray (chest/body level) - should HIT a wall (the ledge itself)
	var lower_start = global_position + Vector2(0, 2)
	var lower_end = lower_start + Vector2(check_direction * ray_length, 0)
	
	# Create ray queries
	var upper_query = PhysicsRayQueryParameters2D.create(upper_start, upper_end, 1)
	upper_query.exclude = [self]
	
	var lower_query = PhysicsRayQueryParameters2D.create(lower_start, lower_end, 1)
	lower_query.exclude = [self]
	
	var upper_result = space_state.intersect_ray(upper_query)
	var lower_result = space_state.intersect_ray(lower_query)
	
	# Ledge condition: lower ray hits something, upper ray is clear
	if lower_result.is_empty() or not upper_result.is_empty():
		return false
	
	# Additional check: make sure we're not too close to ground
	var ground_check_start = global_position
	var ground_check_end = global_position + Vector2(0, 10)
	var ground_query = PhysicsRayQueryParameters2D.create(ground_check_start, ground_check_end, 1)
	ground_query.exclude = [self]
	var ground_result = space_state.intersect_ray(ground_query)
	if not ground_result.is_empty():
		return false
	
	# Found a ledge! Calculate the grab position
	var wall_x = lower_result.position.x
	
	# Find the top of the ledge by casting down from the empty space
	var down_start = Vector2(upper_end.x, upper_start.y - 4)
	var down_end = down_start + Vector2(0, 24)
	
	var down_query = PhysicsRayQueryParameters2D.create(down_start, down_end, 1)
	down_query.exclude = [self]
	
	var down_result = space_state.intersect_ray(down_query)
	
	if down_result.is_empty():
		return false
	
	# Position player at the ledge
	var ledge_top_y = down_result.position.y
	
	# Calculate target position
	var target_pos = Vector2(
		wall_x + (check_direction * LEDGE_CLIMB_OFFSET.x),
		ledge_top_y + LEDGE_CLIMB_OFFSET.y
	)
	
	# CEILING CHECK: Make sure there's enough room above the target position
	# Cast a ray upward from target to check for ceiling collision
	var player_height = 20.0  # Approximate player height
	var ceiling_check_start = target_pos + Vector2(0, 5)  # Start from feet area
	var ceiling_check_end = target_pos + Vector2(0, -player_height)  # Check up to head
	
	var ceiling_query = PhysicsRayQueryParameters2D.create(ceiling_check_start, ceiling_check_end, 1)
	ceiling_query.exclude = [self]
	var ceiling_result = space_state.intersect_ray(ceiling_query)
	
	if not ceiling_result.is_empty():
		# There's a ceiling in the way - don't grab this ledge
		return false
	
	# TILE-ABOVE CHECK: Make sure we're not grabbing a tile from below
	# Check if there's a solid tile directly above the ledge surface we detected
	# If there IS a tile above, this isn't a real ledge - it's just a wall we're passing
	var tile_above_start = Vector2(down_result.position.x, down_result.position.y - 2)
	var tile_above_end = tile_above_start + Vector2(0, -18)  # Check ~1 tile height up
	
	var tile_above_query = PhysicsRayQueryParameters2D.create(tile_above_start, tile_above_end, 1)
	tile_above_query.exclude = [self]
	var tile_above_result = space_state.intersect_ray(tile_above_query)
	
	if not tile_above_result.is_empty():
		# There's a tile above this "ledge" - it's not a real edge, just a wall
		return false
	
	# Store current position as climb start
	_ledge_climb_start_pos = global_position
	
	# Store the target position for after climb (on top of the ledge)
	_ledge_climb_target_pos = target_pos
	
	return true


func _is_position_clear(test_pos: Vector2) -> bool:
	"""Check if the player's collision shape can fit at the given position.
	Uses PhysicsShapeQueryParameters2D for accurate collision testing."""
	var space_state = get_world_2d().direct_space_state
	
	# Get the player's collision shape
	var collision_shape = $CollisionShape2D as CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return true  # Fallback: assume clear if we can't check
	
	# Create a shape query at the target position
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	# Account for the collision shape's local offset (it's at y=3 in the scene)
	query.transform = Transform2D(0, test_pos + collision_shape.position)
	query.collision_mask = 1  # Layer 1 = world geometry
	query.exclude = [self.get_rid()]  # Exclude self
	
	# Check for overlapping bodies
	var results = space_state.intersect_shape(query, 1)  # Only need to know if ANY collision
	
	return results.is_empty()


func _recover_from_collision() -> void:
	"""Safety net: If player ends up stuck in geometry, push them out.
	This is defensive programming - should rarely if ever trigger with proper validation."""
	if _is_position_clear(global_position):
		return  # Not stuck, nothing to do
	
	# We're stuck! Try to find a clear position nearby
	# Priority: up (most likely to be clear after ledge climb), then back toward start
	var escape_directions: Array[Vector2] = [
		Vector2(0, -8),   # Up
		Vector2(0, -16),  # More up
		Vector2(-_facing_direction * 8, 0),  # Back horizontally
		Vector2(-_facing_direction * 8, -8), # Back and up
		Vector2(0, 8),    # Down (last resort)
	]
	
	for offset in escape_directions:
		var test_pos = global_position + offset
		if _is_position_clear(test_pos):
			global_position = test_pos
			push_warning("Player recovered from collision at offset: ", offset)
			return
	
	# If all else fails, return to climb start position
	if _is_position_clear(_ledge_climb_start_pos):
		global_position = _ledge_climb_start_pos
		push_warning("Player recovered to ledge climb start position")
	else:
		# Absolute fallback - this should never happen
		push_error("Player stuck with no valid escape! Forcing position.")


func _start_ledge_grab() -> void:
	"""Enter the ledge climb state and start the climb animation."""
	_change_state(State.LEDGE_GRAB)
	_ledge_grab_cooldown = LEDGE_GRAB_COOLDOWN_TIME
	_ledge_climb_timer = LEDGE_CLIMB_DURATION
	velocity = Vector2.ZERO
	_stop_idle_chain()
	
	# Update facing direction - use the direction toward the ledge
	# Calculate from start to target position
	var climb_direction = signf(_ledge_climb_target_pos.x - _ledge_climb_start_pos.x)
	if climb_direction != 0:
		_facing_direction = climb_direction
	
	# Face the ledge
	cat_sprite.flip_h = _facing_direction < 0
	
	# Reset speed scale (might have been modified by wall climb)
	cat_sprite.speed_scale = 1.0
	
	# Play climb animation directly (no grab)
	cat_sprite.stop()
	cat_sprite.play(&"ledge_climb")
	cat_sprite.frame = 0
	_current_anim = &"ledge_climb"


# ============ STATE TRANSITIONS ============

func _check_transitions() -> void:
	match current_state:
		State.NORMAL:
			_check_normal_transitions()
		State.ON_WALL:
			_check_wall_transitions()
		State.DASHING, State.ATTACKING, State.HURT, State.DEAD, State.LEDGE_GRAB:
			pass  # These states end via timer or animation


func _check_normal_transitions() -> void:
	# Throwing
	if Input.is_action_just_pressed("throw_star") and ninja_star_timer.is_stopped():
		_throw_star()
	
	# Attack (highest priority action)
	if can_attack and Input.is_action_just_pressed("attack"):
		_start_attack()
		return
	
	# Dash
	if can_dash and Input.is_action_just_pressed("dash") and dash_cooldown_timer.is_stopped():
		_start_dash()
		return
	
	# Double jump
	if can_double_jump and Input.is_action_just_pressed("jump"):
		if not is_on_floor() and not _has_double_jumped and coyote_timer.is_stopped():
			velocity.y = JUMP_VELOCITY
			_has_double_jumped = true
			jump_buffer_timer.stop()
			return
	
	# Ledge grab (automatic, Nine Sols style)
	if not is_on_floor() and velocity.y > 0:
		if _check_for_ledge():
			_start_ledge_grab()
			return
	
	# Wall grab
	if is_on_wall() and Input.is_action_pressed("grab_wall") and not is_on_floor():
		_change_state(State.ON_WALL)


func _check_wall_transitions() -> void:
	# Stay on wall if we're still pressing grab and there's a wall nearby
	# Use a small grace period / sticky check to prevent twitching at wall tops
	if is_on_floor():
		_change_state(State.NORMAL)
		return
	
	if not Input.is_action_pressed("grab_wall"):
		_change_state(State.NORMAL)
		return
	
	# More forgiving wall check - use raycast instead of just is_on_wall()
	# This prevents dropping off when at the very edge
	if not is_on_wall() and not _is_wall_nearby():
		_change_state(State.NORMAL)


func _is_wall_nearby() -> bool:
	"""Check if there's a wall within grabbing distance (more forgiving than is_on_wall)."""
	var space_state = get_world_2d().direct_space_state
	var check_direction = -_facing_direction  # Check in the direction we were facing the wall
	
	# If we have a wall normal from recent contact, use that direction instead
	var wall_normal = get_wall_normal()
	if wall_normal != Vector2.ZERO:
		check_direction = -wall_normal.x
	
	# Cast a ray toward where the wall should be
	var start = global_position
	var end = start + Vector2(check_direction * 12, 0)  # Slightly longer reach
	
	var query = PhysicsRayQueryParameters2D.create(start, end, 1)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	_previous_state = current_state
	current_state = new_state


# ============ ACTIONS ============

func _start_attack() -> void:
	_change_state(State.ATTACKING)
	attack_timer.start()
	_stop_idle_chain()
	
	hitbox.monitoring = true
	
	# Position hitbox based on facing
	var hitbox_collision = hitbox.get_child(0) as CollisionShape2D
	if hitbox_collision:
		hitbox_collision.position.x = absf(hitbox_collision.position.x) * _facing_direction
	
	_queue_animation(&"attack", true)  # Force play attack


func _on_attack_timer_timeout() -> void:
	_change_state(State.NORMAL)
	hitbox.monitoring = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Check if we hit an enemy hurtbox
	var body = area.get_parent()
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)


func _start_dash() -> void:
	# Use input direction or facing direction
	_dash_direction = _input_direction if _input_direction != 0 else _facing_direction
	
	_change_state(State.DASHING)
	dash_timer.start()
	dash_cooldown_timer.start()
	_stop_idle_chain()


func _on_dash_timer_timeout() -> void:
	_change_state(State.NORMAL)


# ============ MOVEMENT ============

func _process_movement(delta: float) -> void:
	_is_sneaking = can_sneak and Input.is_action_pressed("sneak")
	
	var current_speed = SPEED * (SNEAK_SPEED_MULTIPLIER if _is_sneaking else 1.0)
	
	if _input_direction != 0:
		velocity.x = move_toward(velocity.x, _input_direction * current_speed, ACCELERATION * delta)
		_facing_direction = signf(_input_direction)
		cat_sprite.flip_h = _input_direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)


# ============ ANIMATION SYSTEM ============

func _queue_animation(anim_name: StringName, force: bool = false) -> void:
	"""Queue an animation - only changes if different from current (unless forced)"""
	if force or cat_sprite.animation != anim_name:
		_target_anim = anim_name
		cat_sprite.play(anim_name)
		_current_anim = anim_name


func _update_normal_animation() -> void:
	cat_sprite.speed_scale = 1.0
	
	# Don't interrupt attack, throw, or ledge animations
	if current_state == State.ATTACKING or _is_throwing or current_state == State.LEDGE_GRAB:
		return
	
	var speed_abs = absf(velocity.x)
	
	if not is_on_floor():
		_stop_idle_chain()
		_queue_animation(&"jump" if velocity.y < 0 else &"fall")
	elif speed_abs > RUN_THRESHOLD:
		_stop_idle_chain()
		_queue_animation(&"run")
	elif speed_abs > WALK_THRESHOLD:
		_stop_idle_chain()
		_queue_animation(&"sneak" if _is_sneaking else &"walk")
	else:
		_handle_idle_animation()


func _handle_idle_animation() -> void:
	# Don't restart idle chain if already in idle states
	if _current_anim in [&"sit", &"sleep"]:
		return
	
	if idle_timer.is_stopped():
		idle_timer.start()
		if _current_anim not in [&"idle", &"idle2"]:
			_play_random_idle()


func _play_random_idle() -> void:
	var idle_choice: StringName = [&"idle", &"idle2"].pick_random()
	_queue_animation(idle_choice)


func _stop_idle_chain() -> void:
	idle_timer.stop()
	sit_timer.stop()
	sleep_timer.stop()


func _on_animation_finished() -> void:
	# Handle animation chaining here for smoother transitions
	match _current_anim:
		&"throw_star":
			_is_throwing = false
			# Return to appropriate animation after throw
			if current_state == State.ON_WALL:
				_queue_animation(&"wall_grab")
			elif current_state == State.NORMAL:
				_update_normal_animation()
		&"attack":
			# Smoothly return to appropriate animation after attack
			if current_state == State.NORMAL:
				_update_normal_animation()
		&"hurt":
			# Return to normal after hurt animation
			if not _is_dead:
				_change_state(State.NORMAL)
				_update_normal_animation()
		&"died":
			# Death animation finished - trigger respawn
			SaveManager.respawn(self)
		&"ledge_climb":
			# Climb finished - ensure we're at target and return to normal
			global_position = _ledge_climb_target_pos
			# Safety: verify we're not stuck and recover if needed
			_recover_from_collision()
			_change_state(State.NORMAL)
			_update_normal_animation()


# ============ INPUT HANDLING ============

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer.start()
	elif event.is_action_released("jump"):
		# Variable jump height
		if velocity.y < 0:
			velocity.y *= 0.5
		cat_sprite.speed_scale = 1.5


# ============ IDLE TIMER CALLBACKS ============

func _on_idle_timer_timeout() -> void:
	# Don't interrupt throwing or attacking
	if _is_throwing or current_state == State.ATTACKING:
		return
	_play_random_idle()
	if sit_timer.is_stopped():
		sit_timer.start()
	if sleep_timer.is_stopped():
		sleep_timer.start()


func _on_sit_timer_timeout() -> void:
	# Don't interrupt throwing or attacking
	if _is_throwing or current_state == State.ATTACKING:
		return
	_queue_animation(&"sit")
	idle_timer.stop()


func _on_sleep_timer_timeout() -> void:
	# Don't interrupt throwing or attacking
	if _is_throwing or current_state == State.ATTACKING:
		return
	_queue_animation(&"sleep")
	idle_timer.stop()
	sit_timer.stop()


func _on_jump_buffer_timer_timeout() -> void:
	pass


func _on_hurt_timer_timeout() -> void:
	if current_state == State.HURT and not _is_dead:
		_change_state(State.NORMAL)
		_update_normal_animation()
