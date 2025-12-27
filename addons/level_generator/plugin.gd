@tool
extends EditorPlugin


func _enter_tree() -> void:
	print("[LevelGenerator] Plugin loaded - add level_generator_node.gd script to any Node2D")


func _exit_tree() -> void:
	print("[LevelGenerator] Plugin unloaded")
