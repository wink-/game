extends Node

const TILE_SIZE = 16
const MAP_WIDTH = 120
const MAP_HEIGHT = 90

var current_map: String = "overworld"

func get_tile_size() -> int:
	return TILE_SIZE

func world_to_map(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))

func map_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)

func change_map(map_name: String):
	current_map = map_name
	# TODO: Implement scene transition