#!/usr/bin/env -S godot --headless --script
# Complete island builder with proper Wang transitions, props, collision, NPCs

extends SceneTree

const MAIN_SCENE = "res://scenes/main.tscn"

# Source IDs
const SRC_WATER = 0
const SRC_SAND = 1
const SRC_GRASS = 2
const SRC_DIRT = 3
const SRC_TRANS_WD = 4   # water-dirt transitions (attempt3 reused)
const SRC_TRANS_SG = 5   # sand-grass transitions
const SRC_TRANS_GD = 6   # grass-dirt transitions (attempt3)

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
	print("Building complete island...")
	build_tileset()
	build_island()
	update_player()
	print("\nDone! Open scenes/main.tscn and press Play.")
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	# 0: Water
	add_solid_atlas(tileset, SRC_WATER, Color(0.12, 0.32, 0.72))
	# 1: Sand
	add_solid_atlas(tileset, SRC_SAND, Color(0.82, 0.75, 0.55))
	# 2: Grass
	add_solid_atlas(tileset, SRC_GRASS, Color(0.28, 0.68, 0.24))
	# 3: Dirt
	add_solid_atlas(tileset, SRC_DIRT, Color(0.58, 0.40, 0.20))
	
	# 4: Water-Sand transitions (from Pixellab)
	add_pixellab_atlas(tileset, SRC_TRANS_WD, "res://assets/tilesets/generated/sand_water.png")
	
	# 5: Sand-Grass transitions
	add_pixellab_atlas(tileset, SRC_TRANS_SG, "res://assets/tilesets/generated/grass_sand.png")
	
	# 6: Grass-Dirt transitions (verified working)
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
	
	# Clear old data
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
	
	# Paint tiles with proper transitions
	for x in range(MAP_W):
		for y in range(MAP_H):
			var current = terrain_grid[x][y]
			var result = get_tile_for_position(x, y, current, terrain_grid)
			ground.set_cell(Vector2i(x, y), result.source_id, result.atlas_coords, 0)
	
	print("✓ Island painted")
	
	# Place props as Sprite2D nodes in YSort
	place_props_as_sprites(ysort, terrain_grid, center_x, center_y)
	
	# Place house
	place_building(ysort, "res://assets/sprites/buildings/house.png", center_x - 3, center_y - 2, terrain_grid)
	
	# Place Elder NPC
	place_npc(ysort, "elder", center_x + 4, center_y + 2, terrain_grid)
	
	# Place chest near house
	place_prop_sprite(ysort, "res://assets/sprites/items/chest.png", center_x - 1, center_y + 3, terrain_grid)
	
	# Place well in grass area
	place_prop_sprite(ysort, "res://assets/sprites/props/well.png", center_x + 6, center_y - 3, terrain_grid)
	
	# Place campfire in dirt center
	place_prop_sprite(ysort, "res://assets/sprites/props/campfire.png", center_x, center_y, terrain_grid)
	
	# Add water collision - create StaticBody2D nodes for all water tiles
	add_water_collision(main, terrain_grid)
	
	# Center player
	var player = main.get_node("YSort/Player")
	player.position = Vector2(center_x * 16, (center_y + 2) * 16)
	
	# Camera - show full island
	var camera = player.get_node("Camera2D")
	if camera:
		camera.position = Vector2(0, 0)  # Center on player
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = MAP_W * 16
		camera.limit_bottom = MAP_H * 16
		camera.zoom = Vector2(0.6, 0.6)  # Zoom out more to see entire island
	
	# Save
	var new_packed = PackedScene.new()
	new_packed.pack(main)
	ResourceSaver.save(new_packed, MAIN_SCENE)
	main.free()
	print("✓ Scene saved with props, NPCs, and buildings")

func get_tile_for_position(x: int, y: int, current: int, grid: Array) -> Dictionary:
	var result = {"source_id": SRC_WATER, "atlas_coords": Vector2i(0, 0)}
	
	# Check if we're at a terrain boundary
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
		# Pure terrain - no transitions needed
		match current:
			T_WATER: result = {"source_id": SRC_WATER, "atlas_coords": Vector2i(0, 0)}
			T_SAND: result = {"source_id": SRC_SAND, "atlas_coords": Vector2i(0, 0)}
			T_GRASS: result = {"source_id": SRC_GRASS, "atlas_coords": Vector2i(0, 0)}
			T_DIRT: result = {"source_id": SRC_DIRT, "atlas_coords": Vector2i(0, 0)}
		return result
	
	# At boundary - use transitions
	# Calculate Wang corner bits from diagonal neighbors
	var bits = 0
	
	# TL corner: check (-1, -1)
	if x > 0 and y > 0:
		var tl = grid[x - 1][y - 1]
		if is_upper_terrain(tl, current):
			bits |= 0b1000
	
	# TR corner: check (1, -1)
	if x < MAP_W - 1 and y > 0:
		var tr = grid[x + 1][y - 1]
		if is_upper_terrain(tr, current):
			bits |= 0b0100
	
	# BL corner: check (-1, 1)
	if x > 0 and y < MAP_H - 1:
		var bl = grid[x - 1][y + 1]
		if is_upper_terrain(bl, current):
			bits |= 0b0010
	
	# BR corner: check (1, 1)
	if x < MAP_W - 1 and y < MAP_H - 1:
		var br = grid[x + 1][y + 1]
		if is_upper_terrain(br, current):
			bits |= 0b0001
	
	# Determine which atlas to use based on terrain pair
	match current:
		T_WATER:
			# Water at boundary - neighbors are sand
			result = wang_water_sand(bits)
		T_SAND:
			# Sand at boundary - could be water or grass
			if has_neighbor_type(x, y, grid, T_WATER):
				result = wang_water_sand(bits)
			else:
				result = wang_sand_grass(bits)
		T_GRASS:
			# Grass at boundary - could be sand or dirt
			if has_neighbor_type(x, y, grid, T_SAND):
				result = wang_sand_grass(bits)
			else:
				result = wang_grass_dirt(bits)
		T_DIRT:
			# Dirt at boundary - neighbors are grass
			result = wang_grass_dirt(bits)
	
	return result

func is_upper_terrain(neighbor: int, current: int) -> bool:
	# "Upper" terrain is the one closer to center (higher value)
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
	# Water-sand atlas mapping (from Pixellab sand_water.png)
	# bits: sand presence at corners (1 = sand, 0 = water)
	# Pure water (0000) -> [0,0], Pure sand (1111) -> [3,3]
	var map = {
		0b0000: Vector2i(0, 0), 0b0001: Vector2i(1, 0), 0b0010: Vector2i(2, 0), 0b0011: Vector2i(3, 0),
		0b0100: Vector2i(0, 1), 0b0101: Vector2i(1, 1), 0b0110: Vector2i(2, 1), 0b0111: Vector2i(3, 1),
		0b1000: Vector2i(0, 2), 0b1001: Vector2i(1, 2), 0b1010: Vector2i(2, 2), 0b1011: Vector2i(3, 2),
		0b1100: Vector2i(0, 3), 0b1101: Vector2i(1, 3), 0b1110: Vector2i(2, 3), 0b1111: Vector2i(3, 3)
	}
	return {"source_id": SRC_TRANS_WD, "atlas_coords": map.get(bits, Vector2i(0, 0))}

func wang_sand_grass(bits: int) -> Dictionary:
	# Sand-grass atlas mapping (from Pixellab grass_sand.png)
	# bits: grass presence at corners (1 = grass, 0 = sand)
	var map = {
		0b0000: Vector2i(2, 1), 0b0001: Vector2i(3, 1), 0b0010: Vector2i(2, 2), 0b0011: Vector2i(1, 2),
		0b0100: Vector2i(2, 0), 0b0101: Vector2i(3, 2), 0b0110: Vector2i(0, 1), 0b0111: Vector2i(3, 3),
		0b1000: Vector2i(1, 1), 0b1001: Vector2i(2, 3), 0b1010: Vector2i(1, 0), 0b1011: Vector2i(0, 2),
		0b1100: Vector2i(3, 0), 0b1101: Vector2i(0, 0), 0b1110: Vector2i(1, 3), 0b1111: Vector2i(0, 3)
	}
	return {"source_id": SRC_TRANS_SG, "atlas_coords": map.get(bits, Vector2i(2, 1))}

func wang_grass_dirt(bits: int) -> Dictionary:
	# Grass-dirt atlas mapping (verified from attempt3 analysis)
	# bits: grass presence at corners (1 = grass, 0 = dirt)
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
	
	# Place trees on grass (not on boundaries)
	var tree_count = 0
	for i in range(30):
		var tx = rng.randi_range(2, MAP_W - 3)
		var ty = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(tx, ty, grid, T_GRASS):
			var img = Image.load_from_file("res://assets/sprites/props/tree.png")
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
				sprite.name = "Tree_" + str(tree_count)
				ysort.add_child(sprite)
				tree_count += 1
	
	# Place rocks on grass
	var rock_count = 0
	for i in range(8):
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
	
	# Place flowers on grass
	var flower_count = 0
	for i in range(15):
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
	
	# Place fences on dirt
	var fence_count = 0
	for i in range(6):
		var fix = rng.randi_range(2, MAP_W - 3)
		var fiy = rng.randi_range(2, MAP_H - 3)
		if is_valid_prop_location(fix, fiy, grid, T_DIRT):
			var img = Image.load_from_file("res://assets/sprites/props/fence.png")
			var tex = ImageTexture.create_from_image(img) if img else null
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				sprite.position = Vector2(fix * 16 + 8, fiy * 16 + 8)
				sprite.name = "Fence_" + str(fence_count)
				ysort.add_child(sprite)
				fence_count += 1
	
	# Place bushes on grass
	var bush_count = 0
	for i in range(8):
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
	
	print("✓ Props placed: ", tree_count, " trees, ", rock_count, " rocks, ", flower_count, " flowers, ", fence_count, " fences, ", bush_count, " bushes")

func is_valid_prop_location(x: int, y: int, grid: Array, required_terrain: int) -> bool:
	if grid[x][y] != required_terrain:
		return false
	# Check not on boundary
	var neighbors = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for n in neighbors:
		var nx = x + n.x
		var ny = y + n.y
		if nx >= 0 and nx < MAP_W and ny >= 0 and ny < MAP_H:
			if grid[nx][ny] != required_terrain:
				return false
	return true

func add_water_collision(main: Node, grid: Array):
	# Create a StaticBody2D for water collision
	var water_body = StaticBody2D.new()
	water_body.name = "WaterCollision"
	water_body.collision_layer = 2
	water_body.collision_mask = 0
	
	for x in range(MAP_W):
		for y in range(MAP_H):
			if grid[x][y] == T_WATER:
				var collision = CollisionShape2D.new()
				var shape = RectangleShape2D.new()
				shape.size = Vector2(16, 16)
				collision.shape = shape
				collision.position = Vector2(x * 16 + 8, y * 16 + 8)
				water_body.add_child(collision)
	
	main.add_child(water_body)
	print("✓ Water collision added")

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

func place_building(ysort: Node, texture_path: String, tx: float, ty: float, grid: Array):
	var img = Image.load_from_file(texture_path)
	var tex = ImageTexture.create_from_image(img) if img else null
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
		sprite.name = "House"
		# Add collision for building
		var area = Area2D.new()
		area.name = "HouseArea"
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(24, 24)
		collision.shape = shape
		area.add_child(collision)
		sprite.add_child(area)
		ysort.add_child(sprite)
		print("✓ House placed")

func place_npc(ysort: Node, npc_name: String, tx: float, ty: float, grid: Array):
	var img = Image.load_from_file("res://assets/sprites/npcs/elder/22f59e29/rotations/south.png")
	var tex = ImageTexture.create_from_image(img) if img else null
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = Vector2(tx * 16 + 8, ty * 16 + 8)
		sprite.name = "Elder_NPC"
		ysort.add_child(sprite)
		print("✓ Elder NPC placed")

func update_player():
	var code = '''extends CharacterBody2D

@export var move_speed: float = 120.0
@export var grid_snap: bool = true
var tile_size: int = 16
var target_position: Vector2
var is_moving: bool = false
var current_direction: Vector2i = Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	target_position = global_position
	tile_size = get_global_tile_size()
	setup_sprites()
	setup_collision()
	sprite.play("idle_down")

func get_global_tile_size() -> int:
	var g = get_node("/root/Global")
	return g.get_tile_size() if g else 16

func setup_sprites():
	var frames = SpriteFrames.new()
	var dirs = {"down": "south", "up": "north", "right": "east", "left": "west"}
	var colors = {"down": Color.RED, "up": Color.BLUE, "right": Color.YELLOW, "left": Color.GREEN}
	for d in dirs:
		var img = Image.load_from_file("res://assets/sprites/player/e3399290/rotations/" + dirs[d] + ".png")
		var tex = ImageTexture.create_from_image(img) if img else null
		if tex:
			frames.add_animation("walk_" + d)
			frames.add_frame("walk_" + d, tex)
			frames.set_animation_loop("walk_" + d, true)
			frames.set_animation_speed("walk_" + d, 8)
			frames.add_animation("idle_" + d)
			frames.add_frame("idle_" + d, tex)
			frames.set_animation_loop("idle_" + d, true)
		else:
			# Fallback to colored squares
			var fallback_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			fallback_img.fill(colors[d])
			var fallback_tex = ImageTexture.create_from_image(fallback_img)
			frames.add_animation("walk_" + d)
			frames.add_frame("walk_" + d, fallback_tex)
			frames.set_animation_loop("walk_" + d, true)
			frames.set_animation_speed("walk_" + d, 8)
			frames.add_animation("idle_" + d)
			frames.add_frame("idle_" + d, fallback_tex)
			frames.set_animation_loop("idle_" + d, true)
	sprite.sprite_frames = frames

func setup_collision():
	var c = CollisionShape2D.new()
	c.name = "CollisionShape2D"
	var s = RectangleShape2D.new()
	s.size = Vector2(14, 10)
	c.shape = s
	c.position = Vector2(0, 3)
	add_child(c)
	move_child(c, 1)

func _physics_process(delta: float):
	if not is_moving:
		handle_input()
	else:
		move_towards_target(delta)

func handle_input():
	var input_dir = Vector2i.ZERO
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("move_up_alt"):
		input_dir.y = -1
	elif Input.is_action_pressed("move_down") or Input.is_action_pressed("move_down_alt"):
		input_dir.y = 1
	elif Input.is_action_pressed("move_left") or Input.is_action_pressed("move_left_alt"):
		input_dir.x = -1
	elif Input.is_action_pressed("move_right") or Input.is_action_pressed("move_right_alt"):
		input_dir.x = 1
	if input_dir != Vector2i.ZERO:
		start_move(input_dir)

func start_move(dir: Vector2i):
	var next_pos = global_position + Vector2(dir.x, dir.y) * tile_size
	if grid_snap:
		next_pos = snap_to_grid(next_pos)
	if can_move_to(next_pos):
		target_position = next_pos
		current_direction = dir
		is_moving = true
		update_animation(dir, true)

func can_move_to(pos: Vector2) -> bool:
	var ss = get_world_2d().direct_space_state
	var q = PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 2
	q.collide_with_areas = true
	return ss.intersect_point(q).size() == 0

func move_towards_target(delta: float):
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	if distance < move_speed * delta:
		global_position = target_position
		is_moving = false
		update_animation(current_direction, false)
	else:
		global_position += direction * move_speed * delta

func update_animation(dir: Vector2i, moving: bool):
	var anim_prefix = "walk_" if moving else "idle_"
	var anim_name = ""
	if dir == Vector2i.UP: anim_name = anim_prefix + "up"
	elif dir == Vector2i.DOWN: anim_name = anim_prefix + "down"
	elif dir == Vector2i.LEFT: anim_name = anim_prefix + "left"
	elif dir == Vector2i.RIGHT: anim_name = anim_prefix + "right"
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / tile_size) * tile_size, round(pos.y / tile_size) * tile_size)
'''
	var file = FileAccess.open("res://scripts/player.gd", FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
		print("✓ Player script updated")
