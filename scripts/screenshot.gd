extends Node2D

func _ready():
	# Wait for everything to render
	await get_tree().create_timer(0.5).timeout
	
	# Capture viewport
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("Screenshot saved to screenshot.png")
	
	# Quit after save
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
