#!/usr/bin/env -S godot --headless --script
# Setup TileSet from curated tiles and paint test map
# Run: godot --headless --script scripts/setup_tileset.gd

extends SceneTree

const TILESET_PATH = "res://assets/tilesets/tileset.tres"
const TILESET_IMAGE = "res://assets/tilesets/generated/attempt3_grass_dirt.png"
const MAIN_SCENE = "res://scenes/main.tscn"

# CORRECTED Wang tile mapping based on corner analysis:
# Bits [TL, TR, BL, BR] where 1=grass, 0=dirt
const WANG_MAP = {
	0b0000: Vector2i(2, 1),  # pure dirt (all corners dirt)
	0b0001: Vector2i(3, 1),  # BR=grass
	0b0010: Vector2i(2, 2),  # BL=grass
	0b0011: Vector2i(1, 2),  # BL+BR=grass
	0b0100: Vector2i(2, 0),  # TR=grass
	0b0101: Vector2i(3, 2),  # TR+BR=grass
	0b0110: Vector2i(0, 1),  # TR+BL=grass
	0b0111: Vector2i(3, 3),  # TR+BL+BR=grass
	0b1000: Vector2i(1, 1),  # TL=grass
	0b1001: Vector2i(2, 3),  # TL+BR=grass
	0b1010: Vector2i(1, 0),  # TL+BL=grass
	0b1011: Vector2i(0, 2),  # TL+BL+BR=grass
	0b1100: Vector2i(3, 0),  # TL+TR=grass
	0b1101: Vector2i(0, 0),  # TL+TR+BR=grass
	0b1110: Vector2i(1, 3),  # TL+TR+BL=grass
	0b1111: Vector2i(0, 3),  # pure grass (all corners grass)
}

const PURE_DIRT = Vector2i(2, 1)
const PURE_GRASS = Vector2i(0, 3)

func _init():
	print("Setting up TileSet and test map...")
	setup_tileset()
	setup_main_scene()
	print("\nDone! Open scenes/main.tscn in Godot and press Play.")
	quit()

func setup_tileset():
	var img = Image.load_from_file(TILESET_IMAGE)
	if not img:
		push_error("Failed to load: " + TILESET_IMAGE)
		return
	
	var tex = ImageTexture.create_from_image(img)
	
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	
	# Create all 16 tiles
	for row in range(4):
		for col in range(4):
			atlas.create_tile(Vector2i(col, row))
	
	tileset.add_source(atlas, 0)
	
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
	
	var ground = main.get_node("Ground")
	if not ground:
		push_error("Ground layer not found")
		return
	
	var tileset = load(TILESET_PATH)
	if tileset:
		ground.tile_set = tileset
		print("✓ TileSet assigned to Ground")
	else:
		push_error("Failed to load TileSet")
		return
	
	# Paint map: grass island with dirt border and smooth transitions
	var map_w = 20
	var map_h = 15
	
	for x in range(map_w):
		for y in range(map_h):
			var bits = calculate_wang_bits(x, y, map_w, map_h)
			var atlas_coords = WANG_MAP.get(bits, PURE_GRASS)
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

func calculate_wang_bits(x: int, y: int, map_w: int, map_h: int) -> int:
	# For each corner of this tile, check if the adjacent tile should be grass
	# A corner is grass if the tile in that diagonal direction is inner (not edge)
	var bits = 0
	
	# Top-Left corner: check tile at (x-1, y-1)
	if x > 0 and y > 0 and is_grass(x - 1, y - 1, map_w, map_h):
		bits |= 0b1000
	
	# Top-Right corner: check tile at (x+1, y-1)
	if x < map_w - 1 and y > 0 and is_grass(x + 1, y - 1, map_w, map_h):
		bits |= 0b0100
	
	# Bottom-Left corner: check tile at (x-1, y+1)
	if x > 0 and y < map_h - 1 and is_grass(x - 1, y + 1, map_w, map_h):
		bits |= 0b0010
	
	# Bottom-Right corner: check tile at (x+1, y+1)
	if x < map_w - 1 and y < map_h - 1 and is_grass(x + 1, y + 1, map_w, map_h):
		bits |= 0b0001
	
	return bits

func is_grass(x: int, y: int, map_w: int, map_h: int) -> bool:
	# Inner area is grass, border is dirt
	# Create a 2-tile wide border of dirt
	var border = 2
	return x >= border and x < map_w - border and y >= border and y < map_h - border
