extends Node2D

@onready var ground_tilemap: TileMapLayer = $Ground
@onready var props_tilemap: TileMapLayer = $Props
@onready var player = $YSort/Player

func _ready():
	setup_tilemaps()
	setup_camera_limits()

func setup_tilemaps():
	ground_tilemap.z_index = 0
	props_tilemap.z_index = 1

func setup_camera_limits():
	pass

func _on_tilemap_ready():
	var map_size = ground_tilemap.get_used_rect().size * get_global_tile_size()
	player.camera.limit_right = map_size.x
	player.camera.limit_bottom = map_size.y

func get_global_tile_size() -> int:
	var global_script = get_node("/root/Global")
	if global_script:
		return global_script.get_tile_size()
	return 16