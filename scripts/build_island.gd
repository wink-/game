#!/usr/bin/env -S godot --headless --script
# Complete island builder - no per-tile physics collision

extends SceneTree

const MAIN_SCENE = "res://scenes/main.tscn"

# Source IDs
const SRC_WATER = 0
const SRC_SAND = 1
const SRC_GRASS = 2
const SRC_DIRT = 3
const SRC_TRANS_WD = 4
const SRC_TRANS_SG = 5
const SRC_TRANS_GD = 6

# Terrain values
const T_WATER = 0
const T_SAND = 1
const T_GRASS = 2
const T_DIRT = 3

# Island config
const MAP_W = 32
const MAP_H = 24
const DIRT_RADIUS = 4.0
const GRASS_RADIUS = 9.0
const SAND_RADIUS = 12.0

func _init():
	print("Building island...")
	build_tileset()
	build_island()
	print("\nDone! Open scenes/main.tscn and press Play.")
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	add_solid_atlas(tileset, SRC_WATER, Color(0.12, 0.32, 0.72))
	add_solid_atlas(tileset, SRC_SAND, Color(0.82, 0.75, 0.55))
	add_solid_atlas(tileset, SRC_GRASS, Color(0.28, 0.68, 0.24))
	add_solid_atlas(tileset, SRC_DIRT, Color(0.58, 0.40, 0.20))
	
	add_pixellab_atlas(tileset, SRC_TRANS_WD, "res://assets/tilesets/generated/sand_water.png")
	add_pixellab_atlas(tileset, SRC_TRANS_SG, "res://assets/tilesets/generated/grass_sand.png")
	add_pixellab_atlas(tileset, SRC_TRANS_GD, "res://assets/tilesets/generated/attempt3_grass_dirt.png")
	
	ResourceSaver.save(tileset, "res://assets/tilesets/island.tres")
	print("✓ TileSet saved")

func add_solid_atlas(tileset: TileSet, source_id: int, color: Color):
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex = ImageTexture.create_from_image(img)
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i(0, 0))
	tileset.add_source(atlas, source_id)

func add_pixellab_atlas(tileset: TileSet, source_id: int, path: String):
	var img = Image.load_from_file(path)
	if not img:
		push_error("Failed to load: " + path)
		return
	var tex = ImageTexture.create_from_image(img)
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	for row in range(4):
		for col in range(4):
			atlas.create_tile(Vector2i(col, row))
	tileset.add_source(atlas, source_id)

func build_island():
	var packed = load(MAIN_SCENE)
	var main = packed.instantiate()
	var ground = main.get_node("Ground")
	var props_layer = main.get_node("Props")
	var ysort = main.get_node("YSort")
	
	ground.clear()
	props_layer.clear()
	
	ground.tile_set = load("res://assets/tilesets/island.tres")
	props_layer.tile_set = load("res://assets/tilesets/island.tres")
	
	var center_x = MAP_W / 2.0
	var center_y = MAP_H / 2.0
	
	# Build terrain grid
	var terrain_grid = []
	for x in range(MAP_W):
		terrain_grid.append([])
		for y in range(MAP_H):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist < DIRT_RADIUS:
				terrain_grid[x].append(T_DIRT)
			elif dist < GRASS_RADIUS:
				terrain_grid[x].append(T_GRASS)
			elif dist < SAND_RADIUS:
				terrain_grid[x].append(T_SAND)
			else:
				terrain_grid[x].append(T_WATER)
	
	# Paint tiles
	for x in range(MAP_W):
		for y in range(MAP_H):
			var current = terrain_grid[x][y]
			var result = get_tile_for_position(x, y, current, terrain_grid)
			ground.set_cell(Vector2i(x, y), result.source_id, result.atlas_coords, 0)
	
	print("✓ Island painted")
	
	# Place props
	place_props_as_sprites(ysort, terrain_grid, center_x, center_y)
	
	# Place key features
	place_prop_sprite(ysort, "res://assets/sprites/buildings/house.png", center_x - 3, center_y - 2, terrain_grid)
	place_interactable(ysort, "res://assets/sprites/items/chest.png", center_x - 1, center_y + 3, "Chest", [
		"You found a wooden chest.",
		"Inside lies a faintly glowing Herb of Tides.",
		"Obtained: Herb of Tides!",
	])
	place_prop_sprite(ysort, "res://assets/sprites/props/well.png", center_x + 6, center_y - 3, terrain_grid)
	place_prop_sprite(ysort, "res://assets/sprites/props/campfire.png", center_x, center_y, terrain_grid)
	place_interactable(ysort, "res://assets/sprites/props/signpost.png", center_x + 2, center_y - 4, "Signpost", [
		"\"Welcome to Heron Island.\"",
		"\"Beware the tides at the southern shore.\"",
	])
	place_npc(ysort, center_x + 4, center_y + 2, terrain_grid)
	
	# Center player
	var player = main.get_node("YSort/Player")
	player.position = Vector2(center_x * 16, (center_y + 2) * 16)
	
	# Camera
	var camera = player.get_node("Camera2D")
	if camera:
		camera.zoom = Vector2(0.5, 0.5)
		camera.limit_right = MAP_W * 16
		camera.limit_bottom = MAP_H * 16
	
	# Set owner on all dynamically-added nodes so they persist into the packed scene.
	# (Nodes added via add_child() without owner are dropped by PackedScene.pack().)
	set_owners_recursive(main, main)

	# Save
	var new_packed = PackedScene.new()
	new_packed.pack(main)
	ResourceSaver.save(new_packed, MAIN_SCENE)
	main.free()
	print("✓ Scene saved")

func set_owners_recursive(node: Node, root: Node):
	for child in node.get_children():
		if child.owner != root:
			child.owner = root
		set_owners_recursive(child, root)

func get_tile_for_position(x: int, y: int, current: int, grid: Array) -> Dictionary:
	var result = {"source_id": SRC_WATER, "atlas_coords": Vector2i(0, 0)}
	
	var has_different_neighbor = false
	var neighbors = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
					 Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	
	for n in neighbors:
		var nx = x + n.x
		var ny = y + n.y
		if nx >= 0 and nx < MAP_W and ny >= 0 and ny < MAP_H:
			if grid[nx][ny] != current:
				has_different_neighbor = true
				break
	
	if not has_different_neighbor:
		match current:
			T_WATER: result = {"source_id": SRC_WATER, "atlas_coords": Vector2i(0, 0)}
			T_SAND: result = {"source_id": SRC_SAND, "atlas_coords": Vector2i(0, 0)}
			T_GRASS: result = {"source_id": SRC_GRASS, "atlas_coords": Vector2i(0, 0)}
			T_DIRT: result = {"source_id": SRC_DIRT, "atlas_coords": Vector2i(0, 0)}
		return result
	
	var bits = 0
	if x > 0 and y > 0 and is_upper_terrain(grid[x - 1][y - 1], current):
		bits |= 0b1000
	if x < MAP_W - 1 and y > 0 and is_upper_terrain(grid[x + 1][y - 1], current):
		bits |= 0b0100
	if x > 0 and y < MAP_H - 1 and is_upper_terrain(grid[x - 1][y + 1], current):
		bits |= 0b0010
	if x < MAP_W - 1 and y < MAP_H - 1 and is_upper_terrain(grid[x + 1][y + 1], current):
		bits |= 0b0001
	
	match current:
		T_WATER: result = wang_water_sand(bits)
		T_SAND:
			if has_neighbor_type(x, y, grid, T_WATER):
				result = wang_water_sand(bits)
			else:
				result = wang_sand_grass(bits)
		T_GRASS:
			if has_neighbor_type(x, y, grid, T_SAND):
				result = wang_sand_grass(bits)
			else:
				result = wang_grass_dirt(bits)
		T_DIRT: result = wang_grass_dirt(bits)
	
	return result

func is_upper_terrain(neighbor: int, current: int) -> bool:
	return neighbor > current

func has_neighbor_type(x: int, y: int, grid: Array, terrain_type: int) -> bool:
	var neighbors = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for n in neighbors:
		var nx = x + n.x
		var ny = y + n.y
		if nx >= 0 and nx < MAP_W and ny >= 0 and ny < MAP_H:
			if grid[nx][ny] == terrain_type:
				return true
	return false

func wang_water_sand(bits: int) -> Dictionary:
	var map = {
		0b0000: Vector2i(0, 0), 0b0001: Vector2i(1, 0), 0b0010: Vector2i(2, 0), 0b0011: Vector2i(3, 0),
		0b0100: Vector2i(0, 1), 0b0101: Vector2i(1, 1), 0b0110: Vector2i(2, 1), 0b0111: Vector2i(3, 1),
		0b1000: Vector2i(0, 2), 0b1001: Vector2i(1, 2), 0b1010: Vector2i(2, 2), 0b1011: Vector2i(3, 2),
		0b1100: Vector2i(0, 3), 0b1101: Vector2i(1, 3), 0b1110: Vector2i(2, 3), 0b1111: Vector2i(3, 3)
	}
	return {"source_id": SRC_TRANS_WD, "atlas_coords": map.get(bits, Vector2i(0, 0))}

func wang_sand_grass(bits: int) -> Dictionary:
	var map = {
		0b0000: Vector2i(2, 1), 0b0001: Vector2i(3, 1), 0b0010: Vector2i(2, 2), 0b0011: Vector2i(1, 2),
		0b0100: Vector2i(2, 0), 0b0101: Vector2i(3, 2), 0b0110: Vector2i(0, 1), 0b0111: Vector2i(3, 3),
		0b1000: Vector2i(1, 1), 0b1001: Vector2i(2, 3), 0b1010: Vector2i(1, 0), 0b1011: Vector2i(0, 2),
		0b1100: Vector2i(3, 0), 0b1101: Vector2i(0, 0), 0b1110: Vector2i(1, 3), 0b1111: Vector2i(0, 3)
	}
	return {"source_id": SRC_TRANS_SG, "atlas_coords": map.get(bits, Vector2i(2, 1))}

func wang_grass_dirt(bits: int) -> Dictionary:
	var map = {
		0b0000: Vector2i(2, 1), 0b0001: Vector2i(3, 1), 0b0010: Vector2i(2, 2), 0b0011: Vector2i(1, 2),
		0b0100: Vector2i(2, 0), 0b0101: Vector2i(3, 2), 0b0110: Vector2i(0, 1), 0b0111: Vector2i(3, 3),
		0b1000: Vector2i(1, 1), 0b1001: Vector2i(2, 3), 0b1010: Vector2i(1, 0), 0b1011: Vector2i(0, 2),
		0b1100: Vector2i(3, 0), 0b1101: Vector2i(0, 0), 0b1110: Vector2i(1, 3), 0b1111: Vector2i(0, 3)
	}
	return {"source_id": SRC_TRANS_GD, "atlas_coords": map.get(bits, Vector2i(2, 1))}

func place_props_as_sprites(ysort: Node, grid: Array, center_x: float, center_y: float):
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	
	var tree_paths = ["res://assets/sprites/props/tree.png", "res://assets/sprites/props/oak_tree.png"]
	
	# Place trees
	var tree_count = 0
	for i in range(15):
		var tx = rng.randi_range(2, MAP_W - 3)
		var ty = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(tx, ty, grid, T_GRASS):
			var path = tree_paths[rng.randi_range(0, 1)]
			var img = Image.load_from_file(path)
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
				sprite.name = "Tree_" + str(tree_count)
				ysort.add_child(sprite)
				tree_count += 1
	
	# Place rocks
	var rock_count = 0
	for i in range(5):
		var rx = rng.randi_range(2, MAP_W - 3)
		var ry = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(rx, ry, grid, T_GRASS):
			var img = Image.load_from_file("res://assets/sprites/props/rock.png")
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(rx * 16 + 8, ry * 16 + 8)
				sprite.name = "Rock_" + str(rock_count)
				ysort.add_child(sprite)
				rock_count += 1
	
	# Place flowers
	var flower_count = 0
	for i in range(10):
		var fx = rng.randi_range(2, MAP_W - 3)
		var fy = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(fx, fy, grid, T_GRASS):
			var img = Image.load_from_file("res://assets/sprites/props/flower.png")
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(fx * 16 + 8, fy * 16 + 8)
				sprite.name = "Flower_" + str(flower_count)
				ysort.add_child(sprite)
				flower_count += 1
	
	# Place bushes
	var bush_count = 0
	for i in range(6):
		var bx = rng.randi_range(2, MAP_W - 3)
		var by = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(bx, by, grid, T_GRASS):
			var img = Image.load_from_file("res://assets/sprites/props/bush.png")
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(bx * 16 + 8, by * 16 + 8)
				sprite.name = "Bush_" + str(bush_count)
				ysort.add_child(sprite)
				bush_count += 1
	
	print("✓ Props placed: ", tree_count, " trees, ", rock_count, " rocks, ", flower_count, " flowers, ", bush_count, " bushes")

func is_valid_prop_location(x: int, y: int, grid: Array, required_terrain: int) -> bool:
	if grid[x][y] != required_terrain:
		return false
	var neighbors = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for n in neighbors:
		var nx = x + n.x
		var ny = y + n.y
		if nx >= 0 and nx < MAP_W and ny >= 0 and ny < MAP_H:
			if grid[nx][ny] != required_terrain:
				return false
	return true

func place_prop_sprite(ysort: Node, texture_path: String, tx: float, ty: float, grid: Array):
	var ix = int(tx)
	var iy = int(ty)
	if ix < 0 or ix >= MAP_W or iy < 0 or iy >= MAP_H:
		return
	
	var img = Image.load_from_file(texture_path)
	var tex = ImageTexture.create_from_image(img) if img else null
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
		sprite.name = texture_path.get_file().get_basename().capitalize()
		ysort.add_child(sprite)

func place_interactable(ysort: Node, texture_path: String, tx: float, ty: float, display_name: String, dialogue: Array):
	var ix = int(tx)
	var iy = int(ty)
	if ix < 0 or ix >= MAP_W or iy < 0 or iy >= MAP_H:
		return
	var img = Image.load_from_file(texture_path)
	var tex = ImageTexture.create_from_image(img) if img else null
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
		sprite.name = display_name
		sprite.set_script(load("res://scripts/interactable.gd"))
		sprite.set_meta("display_name", display_name)
		sprite.set_meta("dialogue", dialogue)
		ysort.add_child(sprite)
		print("✓ Interactable placed: ", display_name)

func place_npc(ysort: Node, tx: float, ty: float, grid: Array):
	var img = Image.load_from_file("res://assets/sprites/npcs/elder/22f59e29/rotations/south.png")
	var tex = ImageTexture.create_from_image(img) if img else null
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
		sprite.name = "Elder_NPC"
		sprite.set_script(load("res://scripts/interactable.gd"))
		sprite.set_meta("display_name", "Elder")
		sprite.set_meta("dialogue", [
			"Greetings, young traveler.",
			"This island has watched over many seasons.",
			"Seek the chest near my home. It may aid your journey.",
		])
		ysort.add_child(sprite)
		print("✓ Elder NPC placed")
