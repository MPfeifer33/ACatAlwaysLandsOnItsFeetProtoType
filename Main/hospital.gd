extends Node2D

@onready var area := $Area2D

func _ready():
	# Add to Hospital group so GameManager can find us
	add_to_group("Hospital")
	
	# Make sure we can detect the player (layer 2)
	area.collision_mask = 2
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	# Check for Player class instead of name
	if body is Player:
		SaveManager.set_respawn_position(global_position)
		print("Respawn point set at hospital!")
