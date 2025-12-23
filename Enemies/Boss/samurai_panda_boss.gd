class_name SamuraiPandaBoss
extends CharacterBody2D
## Samurai Panda Boss - A formidable boss with multiple attack patterns.
## States: IDLE, RUN, ATTACK_1, ATTACK_2, ATTACK_3, DASH, DASH_ATTACK, DEFEND, HURT, DEAD

# ============ SIGNALS ============
signal boss_defeated
signal phase_changed(phase: int)

# ============ ENUMS ============
enum State {
	IDLE,
	RUN,
	ATTACK_ONE,
	ATTACK_TWO,
	ATTACK_THREE,
	DASH,
	DASH_ATTACK,
	DEFEND,
	HURT,
	DEAD
}

# ============ NODE REFERENCES ============
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

# ============ CONFIGURATION ============
@export_group("Movement")
@export var gravity: float = 1200.0
@export var run_speed: float = 120.0
@export var dash_speed: float = 350.0
@export var dash_attack_speed: float = 280.0

@export_group("Combat")
@export var attack_one_damage: int = 8
@export var attack_two_damage: int = 10
@export var attack_three_damage: int = 15
@export var dash_attack_damage: int = 12
@export var contact_damage: int = 5

@export_group("Ranges")
@export var attack_range: float = 50.0  # Close range for melee attacks
@export var dash_attack_range: float = 150.0  # Mid range triggers dash attack
@export var aggro_range: float = 200.0  # Detection range

@export_group("Timing")
@export var action_cooldown: float = 1.0  # Time between actions
@export var defend_duration: float = 0.8
@export var defend_chance: float = 0.25  # 25% chance to defend when hit
@export var hurt_duration: float = 0.3

# ============ STATE ============
var current_state: State = State.IDLE
var direction: int = 1  # 1 = left (sprite default), -1 = right
var _player: Player = null

# Timers
var _action_cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _defend_timer: float = 0.0

# Attack tracking
var _current_attack_damage: int = 0
var _has_hit_player: bool = false
var _is_dashing: bool = false
var _is_defending: bool = false

# Phase system (optional - for scaling difficulty)
var _current_phase: int = 1
var _hits_taken_this_phase: int = 0


func _ready() -> void:
	# Connect signals
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	sprite.animation_finished.connect(_on_animation_finished)
	hitbox.hit.connect(_on_hitbox_hit)
	
	# Initial setup
	hitbox.active = false
	hitbox.damage = contact_damage
	sprite.play(&"idle")
	
	# Find player
	_find_player()


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Update cooldown
	if _action_cooldown_timer > 0:
		_action_cooldown_timer -= delta
	
	# State machine
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.RUN:
			_state_run(delta)
		State.ATTACK_ONE, State.ATTACK_TWO, State.ATTACK_THREE:
			_state_attack(delta)
		State.DASH:
			_state_dash(delta)
		State.DASH_ATTACK:
			_state_dash_attack(delta)
		State.DEFEND:
			_state_defend(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			velocity.x = 0
	
	move_and_slide()


# ============ STATE FUNCTIONS ============

func _state_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 400.0 * delta)
	
	if not _player or not is_instance_valid(_player):
		_find_player()
		return
	
	var dist = _distance_to_player()
	
	# Face the player
	_face_player()
	
	# Decide next action when cooldown is ready
	if _action_cooldown_timer <= 0:
		if dist <= attack_range:
			_choose_melee_attack()
		elif dist <= dash_attack_range:
			# Mid range - dash attack or close in
			if randf() < 0.6:
				_change_state(State.DASH_ATTACK)
			else:
				_change_state(State.DASH)
		elif dist <= aggro_range:
			_change_state(State.RUN)


func _state_run(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_change_state(State.IDLE)
		return
	
	_face_player()
	velocity.x = direction * run_speed
	
	var dist = _distance_to_player()
	
	if dist <= attack_range and _action_cooldown_timer <= 0:
		_choose_melee_attack()
	elif dist > aggro_range:
		_change_state(State.IDLE)


func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 600.0 * delta)
	# Animation handles timing - hitbox activated via animation or timer


func _state_dash(delta: float) -> void:
	velocity.x = direction * dash_speed
	_state_timer -= delta
	
	if _state_timer <= 0:
		_change_state(State.IDLE)


func _state_dash_attack(delta: float) -> void:
	if _is_dashing:
		velocity.x = direction * dash_attack_speed
	else:
		velocity.x = move_toward(velocity.x, 0, 800.0 * delta)


func _state_defend(delta: float) -> void:
	velocity.x = 0
	_defend_timer -= delta
	
	if _defend_timer <= 0:
		_is_defending = false
		_change_state(State.IDLE)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 500.0 * delta)
	_state_timer -= delta
	
	if _state_timer <= 0:
		_change_state(State.IDLE)


# ============ STATE CHANGES ============

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	# Exit current state
	_exit_state(current_state)
	
	# Enter new state
	current_state = new_state
	_enter_state(new_state)


func _exit_state(state: State) -> void:
	match state:
		State.ATTACK_ONE, State.ATTACK_TWO, State.ATTACK_THREE, State.DASH_ATTACK:
			hitbox.active = false
			_has_hit_player = false
		State.DASH:
			_is_dashing = false
		State.DEFEND:
			_is_defending = false


func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			sprite.play(&"idle")
			_action_cooldown_timer = action_cooldown * 0.5
		
		State.RUN:
			sprite.play(&"run")
		
		State.ATTACK_ONE:
			sprite.play(&"attack_one")
			_current_attack_damage = attack_one_damage
			hitbox.damage = _current_attack_damage
			_action_cooldown_timer = action_cooldown
			_schedule_hitbox(0.15, 0.2)  # Activate hitbox during swing
		
		State.ATTACK_TWO:
			sprite.play(&"attack_two")
			_current_attack_damage = attack_two_damage
			hitbox.damage = _current_attack_damage
			_action_cooldown_timer = action_cooldown
			_schedule_hitbox(0.1, 0.15)
		
		State.ATTACK_THREE:
			sprite.play(&"attack_three")
			_current_attack_damage = attack_three_damage
			hitbox.damage = _current_attack_damage
			_action_cooldown_timer = action_cooldown * 1.2  # Slightly longer recovery
			_schedule_hitbox(0.12, 0.18)
		
		State.DASH:
			sprite.play(&"dash")
			_is_dashing = true
			_state_timer = 0.35  # Dash duration
			_action_cooldown_timer = action_cooldown * 0.7
		
		State.DASH_ATTACK:
			sprite.play(&"dash_attack")
			_is_dashing = true
			_current_attack_damage = dash_attack_damage
			hitbox.damage = _current_attack_damage
			_action_cooldown_timer = action_cooldown * 1.5
			_schedule_dash_attack_hitbox()
		
		State.DEFEND:
			sprite.play(&"defend")
			_is_defending = true
			_defend_timer = defend_duration
			_action_cooldown_timer = action_cooldown * 0.3
		
		State.HURT:
			sprite.play(&"was_hit")
			_state_timer = hurt_duration
			hitbox.active = false
		
		State.DEAD:
			sprite.play(&"died")
			hitbox.active = false
			hurtbox.set_deferred("monitoring", false)
			# Disable collision with player
			set_collision_layer_value(3, false)
			set_collision_mask_value(2, false)


# ============ ATTACK SELECTION ============

func _choose_melee_attack() -> void:
	# Weight attacks based on phase/situation
	var roll = randf()
	
	if _current_phase >= 2 and roll < 0.3:
		_change_state(State.ATTACK_THREE)  # Heavy attack more common in phase 2+
	elif roll < 0.5:
		_change_state(State.ATTACK_ONE)
	elif roll < 0.8:
		_change_state(State.ATTACK_TWO)
	else:
		_change_state(State.ATTACK_THREE)


# ============ HITBOX SCHEDULING ============

func _schedule_hitbox(delay: float, duration: float) -> void:
	# Activate hitbox after delay, deactivate after duration
	get_tree().create_timer(delay).timeout.connect(func():
		if current_state in [State.ATTACK_ONE, State.ATTACK_TWO, State.ATTACK_THREE]:
			hitbox.active = true
			_has_hit_player = false
			get_tree().create_timer(duration).timeout.connect(func():
				hitbox.active = false
			)
	)


func _schedule_dash_attack_hitbox() -> void:
	# Dash attack has longer active window
	get_tree().create_timer(0.2).timeout.connect(func():
		if current_state == State.DASH_ATTACK:
			hitbox.active = true
			_has_hit_player = false
	)
	# Deactivate dashing after initial rush
	get_tree().create_timer(0.5).timeout.connect(func():
		_is_dashing = false
	)
	# Deactivate hitbox near end
	get_tree().create_timer(0.8).timeout.connect(func():
		hitbox.active = false
	)


# ============ SIGNAL CALLBACKS ============

func _on_damaged(_amount: int, _current: int) -> void:
	if current_state == State.DEAD:
		return
	
	# Check for defend
	if _is_defending:
		# Reduced damage while defending (handled by taking less damage or could block entirely)
		print("Panda blocked!")
		return
	
	# Chance to defend next hit
	if current_state != State.HURT and randf() < defend_chance:
		_change_state(State.DEFEND)
		return
	
	# Take the hit
	_change_state(State.HURT)
	
	# Knockback away from player
	if _player and is_instance_valid(_player):
		var knockback_dir = sign(global_position.x - _player.global_position.x)
		velocity.x = knockback_dir * 100.0
		velocity.y = -80.0
	
	# Phase tracking
	_hits_taken_this_phase += 1
	_check_phase_transition()


func _on_died() -> void:
	_change_state(State.DEAD)
	boss_defeated.emit()


func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK_ONE, State.ATTACK_TWO, State.ATTACK_THREE:
			_change_state(State.IDLE)
		State.DASH:
			_change_state(State.IDLE)
		State.DASH_ATTACK:
			_change_state(State.IDLE)
		State.DEFEND:
			_change_state(State.IDLE)
		State.HURT:
			_change_state(State.IDLE)
		State.DEAD:
			# Could queue_free() here or leave corpse
			pass


func _on_hitbox_hit(hit_hurtbox: HurtboxComponent) -> void:
	if _has_hit_player:
		return
	
	var body = hit_hurtbox.get_parent()
	if body is Player:
		_has_hit_player = true


# ============ UTILITY FUNCTIONS ============

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_player = players[0] as Player


func _distance_to_player() -> float:
	if not _player or not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func _face_player() -> void:
	if not _player or not is_instance_valid(_player):
		return
	
	var dir_to_player = sign(_player.global_position.x - global_position.x)
	if dir_to_player != 0:
		direction = int(dir_to_player)
		# Sprite faces left by default, so flip when facing right
		sprite.flip_h = direction > 0
		# Flip hitbox position based on direction
		_update_hitbox_direction()


func _update_hitbox_direction() -> void:
	# Adjust hitbox position based on facing direction
	# Sprite faces left by default, so negative X is forward
	if hitbox:
		hitbox.position.x = abs(hitbox.position.x) * -direction


func _check_phase_transition() -> void:
	var health_percent = health.get_health_percent()
	
	if health_percent <= 0.3 and _current_phase < 3:
		_current_phase = 3
		phase_changed.emit(3)
		_on_phase_change()
	elif health_percent <= 0.6 and _current_phase < 2:
		_current_phase = 2
		phase_changed.emit(2)
		_on_phase_change()


func _on_phase_change() -> void:
	# Could add visual effects, speed increases, new attacks, etc.
	match _current_phase:
		2:
			run_speed *= 1.15
			action_cooldown *= 0.9
			print("Panda Boss entered Phase 2!")
		3:
			run_speed *= 1.1
			action_cooldown *= 0.85
			defend_chance = 0.35
			print("Panda Boss entered Phase 3!")


# ============ PUBLIC API ============

func start_boss_fight() -> void:
	"""Call this to activate the boss (e.g., when player enters arena)."""
	_find_player()
	_change_state(State.IDLE)


func is_alive() -> bool:
	return current_state != State.DEAD and health.is_alive()


func take_damage(amount: int) -> void:
	"""Public method for taking damage (used by player attacks)."""
	if current_state == State.DEAD:
		return
	health.take_damage(amount)
