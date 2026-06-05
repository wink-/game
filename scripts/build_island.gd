#!/usr/bin/env -S godot --headless --script
# ULTRA-SIMPLE island builder
# Uses solid color tiles - guaranteed correct, no Wang complexity

extends SceneTree

const MAIN_SCENE = "res://scenes/main.tscn"

# Source IDs in TileSet
const WATER_SRC = 0
const SAND_SRC = 1
const GRASS_SRC = 2
const DIRT_SRC = 3

func _init():
	print("Building simple island...")
	build_tileset()
	build_island()
	update_player()
	print("\nDone! Run scenes/main.tscn")
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	# 4 solid-color atlases, 1 tile each
	add_solid_atlas(tileset, WATER_SRC, Color(0.12, 0.35, 0.7))   # Deep blue water
	add_solid_atlas(tileset, SAND_SRC, Color(0.78, 0.72, 0.52))   # Tan sand
	add_solid_atlas(tileset, GRASS_SRC, Color(0.25, 0.65, 0.22))  # Green grass
	add_solid_atlas(tileset, DIRT_SRC, Color(0.55, 0.38, 0.18))   # Brown dirt
	
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

func build_island():
	var packed = load(MAIN_SCENE)
	var main = packed.instantiate()
	var ground = main.get_node("Ground")
	
	ground.tile_set = load("res://assets/tilesets/island.tres")
	
	# Island: 24 wide x 18 tall
	# Rings from outside in: water(3) → sand(2) → grass(5) → dirt(center)
	var map_w = 24
	var map_h = 18
	
	for x in range(map_w):
		for y in range(map_h):
			var dx = abs(x - map_w / 2.0)
			var dy = abs(y - map_h / 2.0)
			var dist = max(dx, dy)  # 0=center, ~12=corner
			
			var src = WATER_SRC
			if dist < 3:
				src = DIRT_SRC      # Center: dirt
			elif dist < 8:
				src = GRASS_SRC     # Middle: grass
			elif dist < 10:
				src = SAND_SRC      # Beach: sand
			else:
				src = WATER_SRC     # Outer: water
			
			ground.set_cell(Vector2i(x, y), src, Vector2i(0, 0), 0)
	
	print("✓ Island painted: ", map_w, "x", map_h)
	
	# Center player
	var player = main.get_node("YSort/Player")
	player.position = Vector2(map_w * 8, map_h * 8)
	
	# Camera
	var camera = player.get_node("Camera2D")
	camera.limit_right = map_w * 16
	camera.limit_bottom = map_h * 16
	
	# Save
	var new_packed = PackedScene.new()
	new_packed.pack(main)
	ResourceSaver.save(new_packed, MAIN_SCENE)
	main.free()
	print("✓ Scene saved")

func update_player():
	# Simple colored player (guaranteed working, no external assets needed)
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
	var colors = {"down": Color.RED, "up": Color.BLUE, "left": Color.GREEN, "right": Color.YELLOW}
	for d in colors:
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(colors[d])
		var tex = ImageTexture.create_from_image(img)
		frames.add_animation("walk_" + d)
		frames.add_frame("walk_" + d, tex)
		frames.set_animation_loop("walk_" + d, true)
		frames.set_animation_speed("walk_" + d, 8)
		frames.add_animation("idle_" + d)
		frames.add_frame("idle_" + d, tex)
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
