extends Node2D

func _ready():
	var cam = get_node_or_null("OverviewCamera")
	if cam:
		cam.make_current()
	await get_tree().create_timer(0.8).timeout
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://render_output.png")
		print("RENDER_COMPLETE")
	else:
		print("IMAGE_NULL")
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
