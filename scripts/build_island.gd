#!/usr/bin/env -S godot --headless --script
# Complete island builder - bigger explorable world, textured terrain, village.
# Props/interactables persist because set_owners_recursive() sets scene ownership.

extends SceneTree

const MAIN_SCENE = "res://scenes/main.tscn"
const TILE = 16

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

# Island config (big explorable world)
const MAP_W = 96
const MAP_H = 72
const DIRT_RADIUS = 8.0
const GRASS_RADIUS = 24.0
const SAND_RADIUS = 32.0

func _init():
	print("Building island...")
	build_tileset()
	build_island()
	print("\nDone! Open scenes/main.tscn and press Play.")
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)

	add_textured_atlas(tileset, SRC_WATER, Color(0.14, 0.34, 0.74), Color(0.08, 0.22, 0.58), Color(0.32, 0.54, 0.92), "water")
	add_textured_atlas(tileset, SRC_SAND, Color(0.84, 0.76, 0.54), Color(0.70, 0.62, 0.40), Color(0.93, 0.87, 0.67), "sand")
	add_textured_atlas(tileset, SRC_GRASS, Color(0.32, 0.66, 0.28), Color(0.22, 0.50, 0.20), Color(0.44, 0.78, 0.36), "grass")
	add_textured_atlas(tileset, SRC_DIRT, Color(0.56, 0.40, 0.22), Color(0.40, 0.28, 0.14), Color(0.68, 0.50, 0.30), "dirt")

	add_pixellab_atlas(tileset, SRC_TRANS_WD, "res://assets/tilesets/generated/sand_water.png")
	add_pixellab_atlas(tileset, SRC_TRANS_SG, "res://assets/tilesets/generated/grass_sand.png")
	add_pixellab_atlas(tileset, SRC_TRANS_GD, "res://assets/tilesets/generated/attempt3_grass_dirt.png")

	ResourceSaver.save(tileset, "res://assets/tilesets/island.tres")
	print("✓ TileSet saved")

# Textured atlas: 4 variant tiles per terrain so interiors look natural, not flat.
func add_textured_atlas(tileset: TileSet, source_id: int, base: Color, dark: Color, light: Color, kind: String):
	var img = Image.create(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	for v in range(4):
		var rng = RandomNumberGenerator.new()
		rng.seed = (hash([kind, v]) & 0x7fffffff)
		var ox = v * TILE
		for px in range(TILE):
			for py in range(TILE):
				img.set_pixel(ox + px, py, base)
		match kind:
			"grass":
				_scatter(img, ox, rng, dark, 18)
				_scatter(img, ox, rng, light, 11)
				_blades(img, ox, rng, dark, 6)
			"sand":
				_scatter(img, ox, rng, dark, 20)
				_scatter(img, ox, rng, light, 12)
			"water":
				_waves(img, ox, rng, light, 7)
				_scatter(img, ox, rng, dark, 4)
			"dirt":
				_scatter(img, ox, rng, dark, 16)
				_scatter(img, ox, rng, light, 8)
	var tex = ImageTexture.create_from_image(img)
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for v in range(4):
		atlas.create_tile(Vector2i(v, 0))
	tileset.add_source(atlas, source_id)

func _scatter(img: Image, ox: int, rng: RandomNumberGenerator, color: Color, count: int):
	for i in range(count):
		var x = rng.randi_range(0, TILE - 1)
		var y = rng.randi_range(0, TILE - 1)
		img.set_pixel(ox + x, y, color)

func _blades(img: Image, ox: int, rng: RandomNumberGenerator, color: Color, count: int):
	for i in range(count):
		var x = rng.randi_range(0, TILE - 1)
		var y = rng.randi_range(0, TILE - 2)
		img.set_pixel(ox + x, y, color)
		img.set_pixel(ox + x, y + 1, color)

func _waves(img: Image, ox: int, rng: RandomNumberGenerator, color: Color, count: int):
	for i in range(count):
		var x = rng.randi_range(0, TILE - 3)
		var y = rng.randi_range(0, TILE - 1)
		img.set_pixel(ox + x, y, color)
		img.set_pixel(ox + x + 1, y, color)
		img.set_pixel(ox + x + 2, y, color)

func add_pixellab_atlas(tileset: TileSet, source_id: int, path: String):
	var img = Image.load_from_file(path)
	if not img:
		push_error("Failed to load: " + path)
		return
	var tex = ImageTexture.create_from_image(img)
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE, TILE)
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

	# Build terrain grid with an organic (non-circular) coastline.
	var terrain_grid = []
	for x in range(MAP_W):
		terrain_grid.append([])
		for y in range(MAP_H):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx * dx + dy * dy)
			var angle = atan2(dy, dx)
			var wob = 1.8 * sin(angle * 3.0 + 0.5) + 1.0 * sin(angle * 5.0 + 2.0)

			if dist < DIRT_RADIUS + wob:
				terrain_grid[x].append(T_DIRT)
			elif dist < GRASS_RADIUS + wob:
				terrain_grid[x].append(T_GRASS)
			elif dist < SAND_RADIUS + wob:
				terrain_grid[x].append(T_SAND)
			else:
				terrain_grid[x].append(T_WATER)

	# Carve a winding dirt road from the west shore to the village.
	for x in range(4, int(center_x) - 7):
		var py = int(round(center_y + 3.5 * sin(x * 0.22)))
		_carve(terrain_grid, x, py, T_DIRT)
		_carve(terrain_grid, x, py + 1, T_DIRT)
	# Village clearing (dirt plaza) west of center.
	var vcx = int(center_x) - 7
	var vcy = int(center_y) - 1
	for x in range(vcx - 4, vcx + 5):
		for y in range(vcy - 3, vcy + 4):
			_carve(terrain_grid, x, y, T_DIRT)

	# Paint tiles
	for x in range(MAP_W):
		for y in range(MAP_H):
			var current = terrain_grid[x][y]
			var result = get_tile_for_position(x, y, current, terrain_grid)
			ground.set_cell(Vector2i(x, y), result.source_id, result.atlas_coords, 0)

	print("✓ Island painted")

	# Scatter nature across the grasslands.
	place_props_as_sprites(ysort, terrain_grid, center_x, center_y)
	# Dense forest on the eastern side.
	place_forest(ysort, terrain_grid, int(center_x) + 9, int(center_y) - 6, 14, 11)

	# Village: buildings, well, fences, and interactables.
	place_prop_sprite(ysort, "res://assets/sprites/buildings/house.png", vcx - 2, vcy - 1, terrain_grid)
	place_prop_sprite(ysort, "res://assets/sprites/buildings/house.png", vcx + 3, vcy - 1, terrain_grid)
	place_prop_sprite(ysort, "res://assets/sprites/props/well.png", vcx, vcy + 1, terrain_grid)
	place_prop_sprite(ysort, "res://assets/sprites/props/campfire.png", vcx + 2, vcy + 2, terrain_grid)
	for fx in range(vcx - 4, vcx + 5, 2):
		place_prop_sprite(ysort, "res://assets/sprites/props/fence.png", fx, vcy + 3, terrain_grid)
	place_interactable(ysort, "res://assets/sprites/items/chest.png", vcx - 2, vcy + 2, "Chest", [
		"You found a weathered wooden chest.",
		"Inside lies a faintly glowing Herb of Tides.",
		"Obtained: Herb of Tides!",
	])
	place_interactable(ysort, "res://assets/sprites/props/signpost.png", vcx + 1, vcy - 3, "Signpost", [
		"\"Heron Village — pop. few.\"",
		"\"The eastern woods are said to be enchanted. Tread carefully.\"",
	])
	place_npc(ysort, vcx + 5, vcy + 1, terrain_grid)

	# A lone signpost where the road meets the sand (west entrance).
	place_interactable(ysort, "res://assets/sprites/props/signpost.png", 6, int(center_y), "Signpost", [
		"\"Welcome to Heron Island.\"",
		"\"Follow the road east to reach the village.\"",
	])

	# Center player in the village plaza.
	var player = main.get_node("YSort/Player")
	player.position = Vector2(vcx * TILE, (vcy + 1) * TILE)

	# Camera: close JRPG-style follow, clamped to the map bounds.
	var camera = player.get_node("Camera2D")
	if camera:
		camera.zoom = Vector2(2, 2)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 6.0
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = MAP_W * TILE
		camera.limit_bottom = MAP_H * TILE

	# Set owner on all dynamically-added nodes so they persist into the packed scene.
	set_owners_recursive(main, main)

	# Save
	var new_packed = PackedScene.new()
	new_packed.pack(main)
	ResourceSaver.save(new_packed, MAIN_SCENE)
	main.free()
	print("✓ Scene saved")

func _carve(grid: Array, x: int, y: int, terrain: int):
	if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
		grid[x][y] = terrain

func set_owners_recursive(node: Node, root: Node):
	for child in node.get_children():
		if child.owner != root:
			child.owner = root
		set_owners_recursive(child, root)

func get_tile_for_position(x: int, y: int, current: int, grid: Array) -> Dictionary:
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

	# Pure terrain interior: pick a textured variant by hashing the cell so it tiles naturally.
	if not has_different_neighbor:
		var src = SRC_WATER
		match current:
			T_WATER: src = SRC_WATER
			T_SAND: src = SRC_SAND
			T_GRASS: src = SRC_GRASS
			T_DIRT: src = SRC_DIRT
		var h = (x * 73856093) ^ (y * 19349663)
		var variant = posmod(h, 4)
		return {"source_id": src, "atlas_coords": Vector2i(variant, 0)}

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
		T_WATER: return wang_water_sand(bits)
		T_SAND:
			if has_neighbor_type(x, y, grid, T_WATER):
				return wang_water_sand(bits)
			else:
				return wang_sand_grass(bits)
		T_GRASS:
			if has_neighbor_type(x, y, grid, T_SAND):
				return wang_sand_grass(bits)
			else:
				return wang_grass_dirt(bits)
		T_DIRT: return wang_grass_dirt(bits)
	return {"source_id": SRC_WATER, "atlas_coords": Vector2i(0, 0)}

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
	rng.seed = 1337

	# Sample within the island's grass disk so points don't waste away in the ocean.
	var tree_paths = ["res://assets/sprites/props/tree.png", "res://assets/sprites/props/oak_tree.png"]
	var tree_count = 0
	for i in range(220):
		var p = _sample_grass(rng, center_x, center_y)
		if is_valid_prop_location(p.x, p.y, grid, T_GRASS):
			var path = tree_paths[rng.randi_range(0, 1)]
			if _add_sprite(ysort, path, p.x, p.y, "Tree_" + str(tree_count)):
				tree_count += 1

	var rock_count = 0
	for i in range(60):
		var p = _sample_grass(rng, center_x, center_y)
		if is_valid_prop_location(p.x, p.y, grid, T_GRASS) or is_valid_prop_location(p.x, p.y, grid, T_SAND):
			if _add_sprite(ysort, "res://assets/sprites/props/rock.png", p.x, p.y, "Rock_" + str(rock_count)):
				rock_count += 1

	var flower_count = 0
	for i in range(140):
		var p = _sample_grass(rng, center_x, center_y)
		if is_valid_prop_location(p.x, p.y, grid, T_GRASS):
			if _add_sprite(ysort, "res://assets/sprites/props/flower.png", p.x, p.y, "Flower_" + str(flower_count)):
				flower_count += 1

	var bush_count = 0
	for i in range(80):
		var p = _sample_grass(rng, center_x, center_y)
		if is_valid_prop_location(p.x, p.y, grid, T_GRASS):
			if _add_sprite(ysort, "res://assets/sprites/props/bush.png", p.x, p.y, "Bush_" + str(bush_count)):
				bush_count += 1

	print("✓ Props placed: ", tree_count, " trees, ", rock_count, " rocks, ", flower_count, " flowers, ", bush_count, " bushes")

func _sample_grass(rng: RandomNumberGenerator, cx: float, cy: float) -> Vector2i:
	var angle = rng.randf() * TAU
	var radius = rng.randf_range(DIRT_RADIUS + 2.0, GRASS_RADIUS - 2.0)
	return Vector2i(int(round(cx + cos(angle) * radius)), int(round(cy + sin(angle) * radius)))

# Clustered forest in a rectangular region (denser, woods-like).
func place_forest(ysort: Node, grid: Array, ox: int, oy: int, w: int, h: int):
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var paths = ["res://assets/sprites/props/tree.png", "res://assets/sprites/props/oak_tree.png"]
	var n = 0
	for i in range(w * h):
		var x = ox + rng.randi_range(0, w - 1)
		var y = oy + rng.randi_range(0, h - 1)
		if is_valid_prop_location(x, y, grid, T_GRASS) and rng.randf() < 0.55:
			var p = paths[rng.randi_range(0, 1)]
			if _add_sprite(ysort, p, x, y, "ForestTree_" + str(n)):
				n += 1
	print("✓ Forest placed: ", n, " trees")

func is_valid_prop_location(x: int, y: int, grid: Array, required_terrain: int) -> bool:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
		return false
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

func _add_sprite(ysort: Node, texture_path: String, tx: int, ty: int, node_name: String) -> bool:
	var img = Image.load_from_file(texture_path)
	if not img:
		return false
	var tex = ImageTexture.create_from_image(img)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(tx * TILE + TILE / 2, ty * TILE + TILE / 2)
	sprite.name = node_name
	ysort.add_child(sprite)
	return true

func place_prop_sprite(ysort: Node, texture_path: String, tx: float, ty: float, grid: Array):
	var ix = int(tx)
	var iy = int(ty)
	if ix < 0 or ix >= MAP_W or iy < 0 or iy >= MAP_H:
		return
	_add_sprite(ysort, texture_path, ix, iy, texture_path.get_file().get_basename().capitalize() + "_" + str(ix) + "_" + str(iy))

func place_interactable(ysort: Node, texture_path: String, tx: float, ty: float, display_name: String, dialogue: Array):
	var ix = int(tx)
	var iy = int(ty)
	if ix < 0 or ix >= MAP_W or iy < 0 or iy >= MAP_H:
		return
	var img = Image.load_from_file(texture_path)
	if not img:
		return
	var tex = ImageTexture.create_from_image(img)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(ix * TILE + TILE / 2, iy * TILE + TILE / 2)
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
		sprite.position = Vector2(tx * TILE + TILE / 2, ty * TILE + TILE / 2)
		sprite.name = "Elder_NPC"
		sprite.set_script(load("res://scripts/interactable.gd"))
		sprite.set_meta("display_name", "Elder")
		sprite.set_meta("dialogue", [
			"Ah, a new face in Heron Village.",
			"These isles have known peace for many a tide...",
			"...but the eastern woods grow restless of late.",
			"If you would aid us, seek what stirs among the trees.",
		])
		ysort.add_child(sprite)
		print("✓ Elder NPC placed")
