extends Node2D

@export var tileset_path: String = "res://assets/tilesets/generated/attempt1_grass_dirt.png"
@export var tile_size: int = 16
@export var grid_size: int = 5

func _ready():
	preview_tileset()

func preview_tileset():
	var full_img = Image.load_from_file(tileset_path)
	if not full_img:
		push_error("Failed to load tileset: " + tileset_path)
		return
	
	# Extract individual tiles from 4x4 grid
	var tiles: Array[Image] = []
	for row in range(4):
		for col in range(4):
			var tile = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
			full_img.blit_rect(
				tile,
				Rect2i(col * tile_size, row * tile_size, tile_size, tile_size),
				Vector2i(0, 0)
			)
			tiles.append(tile)
	
	# Create a 5x5 grid for testing seamlessness
	var grid_img = Image.create(grid_size * tile_size, grid_size * tile_size, false, Image.FORMAT_RGBA8)
	
	# Simple pattern: mostly grass with dirt patches
	var pattern = [
		[15, 15, 15, 7, 15],
		[15, 0, 1, 3, 15],
		[15, 4, 15, 11, 15],
		[7, 3, 15, 15, 15],
		[15, 15, 15, 15, 15]
	]
	
	for row in range(grid_size):
		for col in range(grid_size):
			var tile_idx = pattern[row][col]
			if tile_idx < tiles.size():
				grid_img.blit_rect(
					tiles[tile_idx],
					Rect2i(0, 0, tile_size, tile_size),
					Vector2i(col * tile_size, row * tile_size)
				)
	
	var tex = ImageTexture.create_from_image(grid_img)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(320, 240)
	sprite.scale = Vector2(4, 4)  # Zoom in for visibility
	add_child(sprite)
	
	print("Preview grid created: ", tileset_path)
	print("Grid size: ", grid_size, "x", grid_size)
	print("Zoom: 4x")
