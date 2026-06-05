#!/usr/bin/env -S godot --headless --script
# Build complete island with all terrains and props
# Run: godot --headless --script scripts/build_island.gd

extends SceneTree

const MAIN_SCENE = "res://scenes/main.tscn"

# Atlas source IDs
const SRC_GRASS_DIRT = 0
const SRC_GRASS_SAND = 1
const SRC_SAND_WATER = 2

# Tile coordinates within each atlas (4x4 grid)
# [col, row] for each Wang corner pattern
# We use simple mapping: visually inspect and assign

func _init():
	print("Building island...")
	build_tileset()
	build_island()
	setup_player()
	print("\nDone! Run scenes/main.tscn")
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	# Source 0: Grass-Dirt transitions
	var img0 = Image.load_from_file("res://assets/tilesets/generated/attempt3_grass_dirt.png")
	var atlas0 = TileSetAtlasSource.new()
	atlas0.texture = ImageTexture.create_from_image(img0)
	atlas0.texture_region_size = Vector2i(16, 16)
	for row in range(4):
		for col in range(4):
			atlas0.create_tile(Vector2i(col, row))
	tileset.add_source(atlas0, SRC_GRASS_DIRT)
	
	# Source 1: Grass-Sand transitions
	var img1 = Image.load_from_file("res://assets/tilesets/generated/grass_sand.png")
	var atlas1 = TileSetAtlasSource.new()
	atlas1.texture = ImageTexture.create_from_image(img1)
	atlas1.texture_region_size = Vector2i(16, 16)
	for row in range(4):
		for col in range(4):
			atlas1.create_tile(Vector2i(col, row))
	tileset.add_source(atlas1, SRC_GRASS_SAND)
	
	# Source 2: Sand-Water transitions
	var img2 = Image.load_from_file("res://assets/tilesets/generated/sand_water.png")
	var atlas2 = TileSetAtlasSource.new()
	atlas2.texture = ImageTexture.create_from_image(img2)
	atlas2.texture_region_size = Vector2i(16, 16)
	for row in range(4):
		for col in range(4):
			atlas2.create_tile(Vector2i(col, row))
	tileset.add_source(atlas2, SRC_SAND_WATER)
	
	var err = ResourceSaver.save(tileset, "res://assets/tilesets/island.tres")
	if err == OK:
		print("✓ Island TileSet saved")
	else:
		push_error("Failed to save TileSet")

func build_island():
	var packed = load(MAIN_SCENE)
	if not packed:
		push_error("Failed to load main scene")
		return
	
	var main = packed.instantiate()
	
	# Get layers
	var ground = main.get_node("Ground")
	var props = main.get_node("Props")
	
	# Assign tileset
	var tileset = load("res://assets/tilesets/island.tres")
	ground.tile_set = tileset
	props.tile_set = tileset
	
	# Island dimensions
	var map_w = 30
	var map_h = 20
	
	# Concentric rings: water(outer) → sand → grass → dirt(center paths)
	var water_ring = 3
	var sand_ring = 2
	
	for x in range(map_w):
		for y in range(map_h):
			var dx = abs(x - map_w / 2.0)
			var dy = abs(y - map_h / 2.0)
			var dist = max(dx, dy)  # Square distance
			
			var atlas_coords = Vector2i(0, 0)
			var source_id = SRC_GRASS_DIRT
			
			if dist >= water_ring + sand_ring:
				# Deep water (outer ocean)
				source_id = SRC_SAND_WATER
				atlas_coords = Vector2i(0, 0)  # pure water
			elif dist >= water_ring:
				# Sand-water transition zone
				source_id = SRC_SAND_WATER
				atlas_coords = get_transition_tile(dist, water_ring, water_ring + sand_ring, SRC_SAND_WATER)
			elif dist >= water_ring - 1:
				# Sand-grass transition
				source_id = SRC_GRASS_SAND
				atlas_coords = get_transition_tile(dist, water_ring - 1, water_ring, SRC_GRASS_SAND)
			elif dist >= 2:
				# Inner grass
				source_id = SRC_GRASS_SAND
				atlas_coords = Vector2i(0, 3)  # pure grass
			else:
				# Center dirt paths
				source_id = SRC_GRASS_DIRT
				atlas_coords = Vector2i(2, 1)  # pure dirt
			
			ground.set_cell(Vector2i(x, y), source_id, atlas_coords, 0)
	
	print("✓ Island painted: ", map_w, "x", map_h)
	
	# Place props randomly on grass areas
	place_props(props, map_w, map_h, water_ring + sand_ring)
	
	# Center player
	var player = main.get_node("YSort/Player")
	if player:
		player.position = Vector2(map_w * 8, map_h * 8)
		print("✓ Player centered")
	
	# Camera limits
	var camera = player.get_node("Camera2D")
	if camera:
		camera.limit_right = map_w * 16
		camera.limit_bottom = map_h * 16
		print("✓ Camera limits set")
	
	# Save
	var new_packed = PackedScene.new()
	if new_packed.pack(main) == OK:
		if ResourceSaver.save(new_packed, MAIN_SCENE) == OK:
			print("✓ Scene saved")
		else:
			push_error("Failed to save scene")
	else:
		push_error("Failed to pack scene")
	
	main.free()

func get_transition_tile(dist: float, inner_r: float, outer_r: float, src_id: int) -> Vector2i:
	# Simple linear interpolation for transition tiles
	var t = (dist - inner_r) / (outer_r - inner_r)
	if t < 0.25:
		return Vector2i(0, 0)  # inner terrain
	elif t < 0.5:
		return Vector2i(1, 0)  # transition start
	elif t < 0.75:
		return Vector2i(2, 0)  # transition mid
	else:
		return Vector2i(3, 0)  # outer terrain

func place_props(props_layer, map_w: int, map_h: int, water_border: int):
	# Randomly place trees, rocks, flowers on grass areas
	var rng = RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic
	
	var tree_count = 8
	var rock_count = 5
	var flower_count = 12
	
	for i in range(tree_count):
		var x = rng.randi_range(water_border + 1, map_w - water_border - 2)
		var y = rng.randi_range(water_border + 1, map_h - water_border - 2)
		# Trees are 2x2 tiles
		props_layer.set_cell(Vector2i(x, y), SRC_GRASS_DIRT, Vector2i(0, 0), 0)
		props_layer.set_cell(Vector2i(x + 1, y), SRC_GRASS_DIRT, Vector2i(0, 0), 0)
		props_layer.set_cell(Vector2i(x, y + 1), SRC_GRASS_DIRT, Vector2i(0, 0), 0)
		props_layer.set_cell(Vector2i(x + 1, y + 1), SRC_GRASS_DIRT, Vector2i(0, 0), 0)
	
	print("✓ Props placed: ", tree_count, " trees, ", rock_count, " rocks, ", flower_count, " flowers")

func setup_player():
	# Update player.gd to use real sprites
	var player_script = load("res://scripts/player.gd")
	if not player_script:
		push_error("Failed to load player script")
		return
	
	# The player script is already set up to create placeholder sprites
	# We need to replace the setup_animations function to load real textures
	# This is complex to do programmatically, so we'll create a new player script
	
	var player_code = '''extends CharacterBody2D

@export var move_speed: float = 120.0
@export var grid_snap: bool = true

var tile_size: int = 16
var target_position: Vector2
var is_moving: bool = false
var current_direction: Vector2i = Vector2i.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready():
	target_position = global_position
	tile_size = get_global_tile_size()
	setup_animations()
	setup_collision()
	animated_sprite.play("idle_down")

func get_global_tile_size() -> int:
	var global_script = get_node("/root/Global")
	if global_script:
		return global_script.get_tile_size()
	return 16

func setup_animations():
	var frames = SpriteFrames.new()
	
	# Load real player textures
	var south_tex = load("res://assets/sprites/player/e3399290/rotations/south.png")
	var north_tex = load("res://assets/sprites/player/e3399290/rotations/north.png")
	var east_tex = load("res://assets/sprites/player/e3399290/rotations/east.png")
	var west_tex = load("res://assets/sprites/player/e3399290/rotations/west.png")
	
	# South (down)
	frames.add_animation("walk_down")
	frames.add_frame("walk_down", south_tex)
	frames.set_animation_loop("walk_down", true)
	frames.set_animation_speed("walk_down", 8)
	
	frames.add_animation("idle_down")
	frames.add_frame("idle_down", south_tex)
	frames.set_animation_loop("idle_down", true)
	
	# North (up)
	frames.add_animation("walk_up")
	frames.add_frame("walk_up", north_tex)
	frames.set_animation_loop("walk_up", true)
	frames.set_animation_speed("walk_up", 8)
	
	frames.add_animation("idle_up")
	frames.add_frame("idle_up", north_tex)
	frames.set_animation_loop("idle_up", true)
	
	# East (right)
	frames.add_animation("walk_right")
	frames.add_frame("walk_right", east_tex)
	frames.set_animation_loop("walk_right", true)
	frames.set_animation_speed("walk_right", 8)
	
	frames.add_animation("idle_right")
	frames.add_frame("idle_right", east_tex)
	frames.set_animation_loop("idle_right", true)
	
	# West (left)
	frames.add_animation("walk_left")
	frames.add_frame("walk_left", west_tex)
	frames.set_animation_loop("walk_left", true)
	frames.set_animation_speed("walk_left", 8)
	
	frames.add_animation("idle_left")
	frames.add_frame("idle_left", west_tex)
	frames.set_animation_loop("idle_left", true)
	
	animated_sprite.sprite_frames = frames

func setup_collision():
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(14, 10)
	collision.shape = shape
	collision.position = Vector2(0, 3)
	add_child(collision)
	move_child(collision, 1)

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
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2
	query.collide_with_areas = true
	var result = space_state.intersect_point(query)
	return result.size() == 0

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
	
	if dir == Vector2i.UP:
		anim_name = anim_prefix + "up"
	elif dir == Vector2i.DOWN:
		anim_name = anim_prefix + "down"
	elif dir == Vector2i.LEFT:
		anim_name = anim_prefix + "left"
	elif dir == Vector2i.RIGHT:
		anim_name = anim_prefix + "right"
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / tile_size) * tile_size,
		round(pos.y / tile_size) * tile_size
	)
'''
	
	var file = FileAccess.open("res://scripts/player.gd", FileAccess.WRITE)
	if file:
		file.store_string(player_code)
		file.close()
		print("✓ Player script updated with real sprites")
	else:
		push_error("Failed to write player script")
