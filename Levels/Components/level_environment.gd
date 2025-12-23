class_name LevelEnvironment
extends Node2D
## Controls per-level visual environment: background and canvas modulate.
## Add as a child of your level scene and configure the exports.

@export var background_texture: Texture2D
@export var background_scale: Vector2 = Vector2(3, 3)
@export var background_offset: Vector2 = Vector2(-312, -160)
@export var canvas_modulate_color: Color = Color.WHITE
@export var apply_on_ready: bool = true

@onready var background_sprite: Sprite2D = $Background/Sprite2D
@onready var canvas_modulate: CanvasModulate = $Background/CanvasModulate


func _ready() -> void:
	if apply_on_ready:
		apply_environment()


func apply_environment() -> void:
	if background_texture and background_sprite:
		background_sprite.texture = background_texture
		background_sprite.scale = background_scale
		background_sprite.position = background_offset
	
	if canvas_modulate:
		canvas_modulate.color = canvas_modulate_color
