extends Node

func _ready():
	var main_scene = load("res://scenes/main.tscn")
	var main_instance = main_scene.instantiate()
	get_tree().root.add_child(main_instance)