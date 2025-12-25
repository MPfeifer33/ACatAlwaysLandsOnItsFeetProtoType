@tool
extends CanvasLayer
class_name LevelBackground

## Animated gradient background for levels
## Drop into any level scene and customize in the inspector

enum BGTheme {
	CUSTOM,
	FOREST_DAY,
	FOREST_NIGHT,
	FOREST_MYSTICAL,
	CAVE,
	CAVE_CRYSTAL,
	SUNSET,
	UNDERWATER,
	SHADOW_WORLD,
	COZY_INTERIOR,
	STARFIELD,
	AURORA_NIGHT
}

@export var bg_theme: BGTheme = BGTheme.CUSTOM:
	set(value):
		bg_theme = value
		if bg_theme != BGTheme.CUSTOM:
			_apply_theme(bg_theme)

# ===== COLORS =====
@export_group("Colors")
@export var color_top: Color = Color(0.1, 0.05, 0.2, 1.0):
	set(value):
		color_top = value
		_update_shader()

@export var color_middle: Color = Color(0.2, 0.1, 0.3, 1.0):
	set(value):
		color_middle = value
		_update_shader()

@export var color_bottom: Color = Color(0.05, 0.15, 0.2, 1.0):
	set(value):
		color_bottom = value
		_update_shader()

# ===== BASIC EFFECTS =====
@export_group("Basic Effects")
@export var enable_shimmer: bool = false:
	set(value):
		enable_shimmer = value
		_update_shader()

@export_range(0.0, 0.5) var shimmer_intensity: float = 0.05:
	set(value):
		shimmer_intensity = value
		_update_shader()

@export_range(0.0, 1.0) var vignette_strength: float = 0.3:
	set(value):
		vignette_strength = value
		_update_shader()

@export var enable_noise: bool = true:
	set(value):
		enable_noise = value
		_update_shader()

@export_range(0.0, 0.1) var noise_intensity: float = 0.02:
	set(value):
		noise_intensity = value
		_update_shader()

# ===== STARS =====
@export_group("Stars")
@export var enable_stars: bool = false:
	set(value):
		enable_stars = value
		_update_shader()

@export_range(0.0, 0.01) var star_density: float = 0.003:
	set(value):
		star_density = value
		_update_shader()

@export_range(0.0, 2.0) var star_brightness: float = 1.0:
	set(value):
		star_brightness = value
		_update_shader()

@export_range(0.0, 5.0) var star_twinkle_speed: float = 2.0:
	set(value):
		star_twinkle_speed = value
		_update_shader()

@export var star_colored: bool = false:
	set(value):
		star_colored = value
		_update_shader()

# ===== DEPTH LAYERS =====
@export_group("Depth Layers (Fake 3D)")
@export var enable_depth_layers: bool = false:
	set(value):
		enable_depth_layers = value
		_update_shader()

@export_range(1, 5) var depth_layer_count: int = 3:
	set(value):
		depth_layer_count = value
		_update_shader()

@export_range(0.0, 0.5) var depth_intensity: float = 0.15:
	set(value):
		depth_intensity = value
		_update_shader()

@export_range(0.0, 1.0) var depth_scroll_speed: float = 0.1:
	set(value):
		depth_scroll_speed = value
		_update_shader()

@export var depth_color: Color = Color(0.0, 0.0, 0.0, 0.3):
	set(value):
		depth_color = value
		_update_shader()

# ===== FLOATING PARTICLES =====
@export_group("Floating Particles")
@export var enable_particles: bool = false:
	set(value):
		enable_particles = value
		_update_shader()

@export_range(0.0, 0.02) var particle_density: float = 0.005:
	set(value):
		particle_density = value
		_update_shader()

@export_range(0.0, 2.0) var particle_speed: float = 0.5:
	set(value):
		particle_speed = value
		_update_shader()

@export_range(0.5, 3.0) var particle_size: float = 1.0:
	set(value):
		particle_size = value
		_update_shader()

@export var particle_color: Color = Color(1.0, 1.0, 1.0, 0.5):
	set(value):
		particle_color = value
		_update_shader()

# ===== PULSING GLOW =====
@export_group("Pulsing Glow")
@export var enable_pulse: bool = false:
	set(value):
		enable_pulse = value
		_update_shader()

@export_range(0.0, 3.0) var pulse_speed: float = 1.0:
	set(value):
		pulse_speed = value
		_update_shader()

@export_range(0.0, 0.3) var pulse_intensity: float = 0.1:
	set(value):
		pulse_intensity = value
		_update_shader()

@export var pulse_color: Color = Color(1.0, 0.8, 0.5, 1.0):
	set(value):
		pulse_color = value
		_update_shader()

# ===== AURORA =====
@export_group("Aurora / Northern Lights")
@export var enable_aurora: bool = false:
	set(value):
		enable_aurora = value
		_update_shader()

@export_range(0.0, 2.0) var aurora_speed: float = 0.3:
	set(value):
		aurora_speed = value
		_update_shader()

@export_range(0.0, 1.0) var aurora_intensity: float = 0.3:
	set(value):
		aurora_intensity = value
		_update_shader()

@export var aurora_color1: Color = Color(0.0, 1.0, 0.5, 1.0):
	set(value):
		aurora_color1 = value
		_update_shader()

@export var aurora_color2: Color = Color(0.3, 0.5, 1.0, 1.0):
	set(value):
		aurora_color2 = value
		_update_shader()

# ===== FOG WISPS =====
@export_group("Fog Wisps")
@export var enable_fog: bool = false:
	set(value):
		enable_fog = value
		_update_shader()

@export_range(0.0, 1.0) var fog_speed: float = 0.2:
	set(value):
		fog_speed = value
		_update_shader()

@export_range(0.0, 1.0) var fog_density: float = 0.3:
	set(value):
		fog_density = value
		_update_shader()

@export var fog_color: Color = Color(0.8, 0.8, 0.9, 0.3):
	set(value):
		fog_color = value
		_update_shader()

# ===== PLAYER MOTION =====
@export_group("Player Motion Effects")
@export var enable_motion_effects: bool = true:
	set(value):
		enable_motion_effects = value
		_update_shader()

@export_range(0.0, 2.0) var motion_influence: float = 1.0:
	set(value):
		motion_influence = value
		_update_shader()

@export var player_max_speed: float = 400.0

@export var pause_auto_animation: bool = false:
	set(value):
		pause_auto_animation = value
		_update_shader()

@onready var color_rect: ColorRect = $ColorRect
var player: CharacterBody2D = null
var cumulative_offset: Vector2 = Vector2.ZERO

func _ready():
	layer = -100
	_update_shader()
	
	if not Engine.is_editor_hint():
		call_deferred("_find_player")

func _find_player():
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
	else:
		var root = get_tree().current_scene
		player = _find_node_by_class(root, "Player")

func _find_node_by_class(node: Node, class_name_str: String) -> CharacterBody2D:
	if node.get_class() == class_name_str or (node.get_script() and node.get_script().get_global_name() == class_name_str):
		return node as CharacterBody2D
	for child in node.get_children():
		var result = _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null

func _process(delta: float):
	if Engine.is_editor_hint():
		return
	
	if not player or not is_instance_valid(player):
		return
	
	if not color_rect or not color_rect.material:
		return
	
	var mat = color_rect.material as ShaderMaterial
	if not mat:
		return
	
	var velocity = player.velocity
	cumulative_offset += velocity * delta
	
	var speed = velocity.length()
	var speed_normalized = clamp(speed / player_max_speed, 0.0, 1.0)
	
	mat.set_shader_parameter("player_velocity", cumulative_offset)
	mat.set_shader_parameter("player_speed_normalized", speed_normalized)

func _update_shader():
	if not is_inside_tree():
		return
	if not color_rect:
		color_rect = get_node_or_null("ColorRect")
	if not color_rect or not color_rect.material:
		return
	
	var mat = color_rect.material as ShaderMaterial
	if not mat:
		return
	
	# Colors
	mat.set_shader_parameter("color_top", color_top)
	mat.set_shader_parameter("color_middle", color_middle)
	mat.set_shader_parameter("color_bottom", color_bottom)
	
	# Basic effects
	mat.set_shader_parameter("enable_shimmer", enable_shimmer)
	mat.set_shader_parameter("shimmer_intensity", shimmer_intensity)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("enable_noise", enable_noise)
	mat.set_shader_parameter("noise_intensity", noise_intensity)
	
	# Stars
	mat.set_shader_parameter("enable_stars", enable_stars)
	mat.set_shader_parameter("star_density", star_density)
	mat.set_shader_parameter("star_brightness", star_brightness)
	mat.set_shader_parameter("star_twinkle_speed", star_twinkle_speed)
	mat.set_shader_parameter("star_colored", star_colored)
	
	# Depth layers
	mat.set_shader_parameter("enable_depth_layers", enable_depth_layers)
	mat.set_shader_parameter("depth_layer_count", depth_layer_count)
	mat.set_shader_parameter("depth_intensity", depth_intensity)
	mat.set_shader_parameter("depth_scroll_speed", depth_scroll_speed)
	mat.set_shader_parameter("depth_color", depth_color)
	
	# Particles
	mat.set_shader_parameter("enable_particles", enable_particles)
	mat.set_shader_parameter("particle_density", particle_density)
	mat.set_shader_parameter("particle_speed", particle_speed)
	mat.set_shader_parameter("particle_size", particle_size)
	mat.set_shader_parameter("particle_color", particle_color)
	
	# Pulse
	mat.set_shader_parameter("enable_pulse", enable_pulse)
	mat.set_shader_parameter("pulse_speed", pulse_speed)
	mat.set_shader_parameter("pulse_intensity", pulse_intensity)
	mat.set_shader_parameter("pulse_color", pulse_color)
	
	# Aurora
	mat.set_shader_parameter("enable_aurora", enable_aurora)
	mat.set_shader_parameter("aurora_speed", aurora_speed)
	mat.set_shader_parameter("aurora_intensity", aurora_intensity)
	mat.set_shader_parameter("aurora_color1", aurora_color1)
	mat.set_shader_parameter("aurora_color2", aurora_color2)
	
	# Fog
	mat.set_shader_parameter("enable_fog", enable_fog)
	mat.set_shader_parameter("fog_speed", fog_speed)
	mat.set_shader_parameter("fog_density", fog_density)
	mat.set_shader_parameter("fog_color", fog_color)
	
	# Motion effects
	mat.set_shader_parameter("enable_motion_effects", enable_motion_effects)
	mat.set_shader_parameter("motion_influence", motion_influence)
	mat.set_shader_parameter("pause_auto_animation", pause_auto_animation)

func _apply_theme(t: BGTheme):
	# Reset all effects first
	enable_stars = false
	enable_depth_layers = false
	enable_particles = false
	enable_pulse = false
	enable_aurora = false
	enable_fog = false
	enable_noise = true
	
	match t:
		BGTheme.FOREST_DAY:
			color_top = Color(0.4, 0.6, 0.9)
			color_middle = Color(0.5, 0.7, 0.5)
			color_bottom = Color(0.2, 0.35, 0.2)
			shimmer_intensity = 0.08
			enable_particles = true
			particle_color = Color(1.0, 1.0, 0.8, 0.3)
			particle_density = 0.003
			particle_speed = 0.2
			
		BGTheme.FOREST_NIGHT:
			color_top = Color(0.02, 0.02, 0.08)
			color_middle = Color(0.05, 0.08, 0.15)
			color_bottom = Color(0.02, 0.05, 0.03)
			shimmer_intensity = 0.02
			vignette_strength = 0.5
			enable_stars = true
			star_density = 0.004
			star_brightness = 0.8
			enable_particles = true
			particle_color = Color(0.5, 0.8, 1.0, 0.2)
			particle_density = 0.002
			
		BGTheme.FOREST_MYSTICAL:
			color_top = Color(0.1, 0.05, 0.2)
			color_middle = Color(0.15, 0.2, 0.3)
			color_bottom = Color(0.05, 0.1, 0.1)
			shimmer_intensity = 0.1
			enable_particles = true
			particle_color = Color(0.8, 1.0, 0.6, 0.5)
			particle_density = 0.008
			particle_speed = 0.3
			enable_fog = true
			fog_color = Color(0.4, 0.5, 0.6, 0.2)
			fog_density = 0.2
			enable_pulse = true
			pulse_color = Color(0.5, 0.8, 1.0, 1.0)
			pulse_intensity = 0.05
			
		BGTheme.CAVE:
			color_top = Color(0.05, 0.03, 0.08)
			color_middle = Color(0.08, 0.05, 0.1)
			color_bottom = Color(0.02, 0.02, 0.03)
			shimmer_intensity = 0.02
			vignette_strength = 0.7
			enable_depth_layers = true
			depth_layer_count = 4
			depth_intensity = 0.2
			depth_color = Color(0.0, 0.0, 0.0, 0.4)
			
		BGTheme.CAVE_CRYSTAL:
			color_top = Color(0.08, 0.05, 0.15)
			color_middle = Color(0.1, 0.08, 0.2)
			color_bottom = Color(0.03, 0.03, 0.08)
			shimmer_intensity = 0.15
			vignette_strength = 0.5
			enable_stars = true
			star_density = 0.002
			star_brightness = 1.5
			star_colored = true
			enable_pulse = true
			pulse_color = Color(0.6, 0.4, 1.0, 1.0)
			pulse_intensity = 0.08
			pulse_speed = 0.5
			
		BGTheme.SUNSET:
			color_top = Color(0.2, 0.1, 0.3)
			color_middle = Color(0.9, 0.4, 0.2)
			color_bottom = Color(0.3, 0.15, 0.2)
			shimmer_intensity = 0.1
			enable_depth_layers = true
			depth_layer_count = 2
			depth_intensity = 0.1
			depth_color = Color(0.1, 0.0, 0.1, 0.3)
			
		BGTheme.UNDERWATER:
			color_top = Color(0.1, 0.3, 0.5)
			color_middle = Color(0.05, 0.2, 0.4)
			color_bottom = Color(0.02, 0.08, 0.2)
			shimmer_intensity = 0.12
			enable_particles = true
			particle_color = Color(0.8, 0.9, 1.0, 0.4)
			particle_density = 0.01
			particle_speed = 0.8
			particle_size = 0.8
			enable_depth_layers = true
			depth_intensity = 0.1
			depth_color = Color(0.0, 0.1, 0.2, 0.3)
			
		BGTheme.SHADOW_WORLD:
			color_top = Color(0.1, 0.0, 0.15)
			color_middle = Color(0.05, 0.0, 0.1)
			color_bottom = Color(0.0, 0.0, 0.02)
			shimmer_intensity = 0.05
			vignette_strength = 0.8
			noise_intensity = 0.04
			enable_depth_layers = true
			depth_layer_count = 5
			depth_intensity = 0.25
			depth_scroll_speed = 0.15
			depth_color = Color(0.1, 0.0, 0.15, 0.5)
			enable_particles = true
			particle_color = Color(0.5, 0.0, 0.8, 0.3)
			particle_density = 0.004
			particle_speed = 0.2
			
		BGTheme.COZY_INTERIOR:
			color_top = Color(0.25, 0.18, 0.12)
			color_middle = Color(0.3, 0.2, 0.1)
			color_bottom = Color(0.15, 0.1, 0.05)
			shimmer_intensity = 0.06
			vignette_strength = 0.4
			enable_particles = true
			particle_color = Color(1.0, 0.9, 0.7, 0.2)
			particle_density = 0.002
			particle_speed = 0.1
			enable_pulse = true
			pulse_color = Color(1.0, 0.7, 0.4, 1.0)
			pulse_intensity = 0.05
			pulse_speed = 0.3
			
		BGTheme.STARFIELD:
			color_top = Color(0.0, 0.0, 0.02)
			color_middle = Color(0.02, 0.01, 0.05)
			color_bottom = Color(0.0, 0.0, 0.01)
			shimmer_intensity = 0.0
			vignette_strength = 0.2
			enable_stars = true
			star_density = 0.008
			star_brightness = 1.2
			star_twinkle_speed = 3.0
			star_colored = true
			
		BGTheme.AURORA_NIGHT:
			color_top = Color(0.01, 0.02, 0.05)
			color_middle = Color(0.02, 0.04, 0.08)
			color_bottom = Color(0.01, 0.01, 0.02)
			shimmer_intensity = 0.02
			enable_stars = true
			star_density = 0.005
			star_brightness = 0.6
			enable_aurora = true
			aurora_intensity = 0.4
			aurora_color1 = Color(0.2, 1.0, 0.5, 1.0)
			aurora_color2 = Color(0.3, 0.5, 1.0, 1.0)
	
	_update_shader()
