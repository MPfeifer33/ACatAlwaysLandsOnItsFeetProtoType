extends Node2D
## Main scene - the persistent root that holds levels and UI
## No level is loaded initially - GameManager handles loading based on save data

@onready var level_container: Node2D = $LevelContainer
@onready var ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	# Initialize GameManager with our references
	# This will show main menu - no level loaded yet
	GameManager.initialize(self, level_container, ui_layer)
