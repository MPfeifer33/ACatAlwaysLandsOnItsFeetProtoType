@tool
extends EditorScript
## Room Template Previewer - Lists all templates and shows their layouts in console
## Run this to see what each template looks like before stamping

func _run() -> void:
	var templates = RoomTemplates.new()
	var all = templates.get_all_templates()
	
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║           ROOM TEMPLATE GALLERY                              ║")
	print("║   Room Size: 72x40 tiles (1152x648 pixels)                   ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")
	
	for category in all:
		print("┌─── ", category, " ", "─".repeat(50 - category.length()))
		print("│")
		
		for template_name in all[category]:
			var layout = templates.get_template(template_name)
			var stats = _analyze_template(layout)
			
			print("│  📦 ", template_name)
			print("│     Solid tiles: ", stats.solid)
			print("│     Doors: ", stats.doors, " | Items: ", stats.items, " | Enemies: ", stats.enemies)
			print("│")
		
		print("└", "─".repeat(60))
		print("")
	
	print("To stamp a template:")
	print("  1. Open stamp_room_template.gd")
	print("  2. Change TEMPLATE_NAME to your choice")
	print("  3. Set ROOM_OFFSET for placement")
	print("  4. Select your TileMapLayer")
	print("  5. Run the stamp script (Ctrl+Shift+X)")


func _analyze_template(layout: Array) -> Dictionary:
	var stats = {
		"solid": 0,
		"doors": 0,
		"items": 0,
		"enemies": 0,
		"player": 0,
	}
	
	for row in layout:
		for tile in row:
			match tile:
				RoomTemplates.SOLID, RoomTemplates.PLATFORM:
					stats.solid += 1
				RoomTemplates.DOOR:
					stats.doors += 1
				RoomTemplates.ITEM_SPAWN:
					stats.items += 1
				RoomTemplates.ENEMY_SPAWN:
					stats.enemies += 1
				RoomTemplates.PLAYER_SPAWN:
					stats.player += 1
	
	return stats
