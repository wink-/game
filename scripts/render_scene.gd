extends Node2D

func _ready():
	await get_tree().create_timer(0.5).timeout
	
	# Find and zoom out the camera
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		cameras[0].zoom = Vector2(0.5, 0.5)
		cameras[0].position = Vector2(240, 176)
	
	# Alternative: find camera by type
	for node in get_tree().get_nodes_in_group("camera"):
		if node is Camera2D:
			node.zoom = Vector2(0.5, 0.5)
			node.position = Vector2(240, 176)
			break
	
	await get_tree().create_timer(0.2).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://render_output.png")
	print("RENDER_COMPLETE")
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
