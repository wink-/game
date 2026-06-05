extends Node2D

func _ready():
	await get_tree().create_timer(0.5).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://render_output.png")
	print("RENDER_COMPLETE")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
