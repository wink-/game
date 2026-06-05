#!/usr/bin/env -S godot --headless --script
# Setup TileSet from curated tiles and paint test map
# Run: godot --headless --script scripts/setup_tileset.gd

extends SceneTree

const TILESET_PATH = "res://assets/tilesets/tileset.tres"
const TILESET_IMAGE = "res://assets/tilesets/generated/attempt3_grass_dirt.png"
const MAIN_SCENE = "res://scenes/main.tscn"

func _init():
	print("Setting up TileSet and test map...")
	setup_tileset()
	setup_main_scene()
	print("\nDone! Open scenes/main.tscn in Godot and press Play.")
	quit()

func setup_tileset():
	# Load the 64x64 tileset image
	var img = Image.load_from_file(TILESET_IMAGE)
	if not img:
		push_error("Failed to load: " + TILESET_IMAGE)
		return
	
	var tex = ImageTexture.create_from_image(img)
	
	# Create TileSet
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	# Create atlas source - 4x4 grid of 16x16 tiles
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	
	# Create all 16 tiles in the atlas
	for row in range(4):
		for col in range(4):
			atlas.create_tile(Vector2i(col, row))
	
	# Add atlas to tileset
	tileset.add_source(atlas, 0)
	
	# Save
	var err = ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("✓ TileSet saved: " + TILESET_PATH)
	else:
		push_error("Failed to save TileSet: " + str(err))

func setup_main_scene():
	var packed_scene = load(MAIN_SCENE)
	if not packed_scene:
		push_error("Failed to load: " + MAIN_SCENE)
		return
	
	var main = packed_scene.instantiate()
	
	# Find Ground TileMapLayer
	var ground = main.get_node("Ground")
	if not ground:
		push_error("Ground layer not found")
		return
	
	# Assign TileSet
	var tileset = load(TILESET_PATH)
	if tileset:
		ground.tile_set = tileset
		print("✓ TileSet assigned to Ground")
	else:
		push_error("Failed to load TileSet")
		return
	
	# Paint a 20x15 map: grass center with dirt border
	var map_w = 20
	var map_h = 15
	
	# Atlas coords for key tiles:
	# (0,0)=pure_dirt, (3,3)=pure_grass
	# Transition tiles fill the grid
	var pure_dirt = Vector2i(0, 0)
	var pure_grass = Vector2i(3, 3)
	
	# Wang corner tile map for transitions (row, col in 4x4 atlas)
	# We define transitions by which corners are grass (1) vs dirt (0)
	# Bits: [TL, TR, BL, BR]
	var transition_tiles = {
		0b0000: Vector2i(0, 0),  # all dirt
		0b0001: Vector2i(1, 0),  # BR grass
		0b0010: Vector2i(2, 0),  # BL grass
		0b0011: Vector2i(3, 0),  # BL+BR grass
		0b0100: Vector2i(0, 1),  # TR grass
		0b0101: Vector2i(1, 1),  # TR+BR grass
		0b0110: Vector2i(2, 1),  # TR+BL grass
		0b0111: Vector2i(3, 1),  # TR+BL+BR grass
		0b1000: Vector2i(0, 2),  # TL grass
		0b1001: Vector2i(1, 2),  # TL+BR grass
		0b1010: Vector2i(2, 2),  # TL+BL grass
		0b1011: Vector2i(3, 2),  # TL+BL+BR grass
		0b1100: Vector2i(0, 3),  # TL+TR grass
		0b1101: Vector2i(1, 3),  # TL+TR+BR grass
		0b1110: Vector2i(2, 3),  # TL+TR+BL grass
		0b1111: Vector2i(3, 3),  # all grass
	}
	
	for x in range(map_w):
		for y in range(map_h):
			var is_edge = (x == 0 or x == map_w - 1 or y == 0 or y == map_h - 1)
			var is_near_edge = (x == 1 or x == map_w - 2 or y == 1 or y == map_h - 2)
			
			var atlas_coords = pure_grass
			
			if is_edge:
				# Outer dirt ring
				atlas_coords = pure_dirt
			elif is_near_edge:
				# Transition layer - calculate corner bits based on neighbors
				var bits = 0
				# Top-left corner
				if x > 1 and y > 1:
					bits |= 0b1000
				# Top-right corner
				if x < map_w - 2 and y > 1:
					bits |= 0b0100
				# Bottom-left corner
				if x > 1 and y < map_h - 2:
					bits |= 0b0010
				# Bottom-right corner
				if x < map_w - 2 and y < map_h - 2:
					bits |= 0b0001
				
				atlas_coords = transition_tiles.get(bits, pure_dirt)
			
			ground.set_cell(Vector2i(x, y), 0, atlas_coords, 0)
	
	print("✓ Map painted: ", map_w, "x", map_h)
	
	# Center the player
	var player = main.get_node("YSort/Player")
	if player:
		player.position = Vector2(map_w * 8, map_h * 8)
		print("✓ Player centered at: ", player.position)
	
	# Set camera limits
	var camera = player.get_node("Camera2D")
	if camera:
		camera.limit_right = map_w * 16
		camera.limit_bottom = map_h * 16
		print("✓ Camera limits: ", camera.limit_right, "x", camera.limit_bottom)
	
	# Save scene
	var new_packed = PackedScene.new()
	var pack_err = new_packed.pack(main)
	if pack_err == OK:
		var save_err = ResourceSaver.save(new_packed, MAIN_SCENE)
		if save_err == OK:
			print("✓ Scene saved: " + MAIN_SCENE)
		else:
			push_error("Failed to save scene")
	else:
		push_error("Failed to pack scene")
	
	main.free()
