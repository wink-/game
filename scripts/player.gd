extends CharacterBody2D

@export var move_speed: float = 120.0
@export var grid_snap: bool = true
var tile_size: int = 16
var target_position: Vector2
var is_moving: bool = false
var current_direction: Vector2i = Vector2i.DOWN
var dialogue_box: Control = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var tilemap: TileMapLayer = get_node("../../Ground")

func _ready():
	target_position = global_position
	tile_size = get_global_tile_size()
	setup_sprites()
	sprite.play("idle_down")

func get_global_tile_size() -> int:
	var g = get_node("/root/Global")
	return g.get_tile_size() if g else 16

func setup_sprites():
	var frames = SpriteFrames.new()
	var dirs = {"down": "south", "up": "north", "right": "east", "left": "west"}
	for d in dirs:
		var img = Image.load_from_file("res://assets/sprites/player/e3399290/rotations/" + dirs[d] + ".png")
		var tex = ImageTexture.create_from_image(img) if img else null
		if not tex:
			var fallback = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			fallback.fill(Color.RED if d == "down" else Color.BLUE if d == "up" else Color.GREEN if d == "left" else Color.YELLOW)
			tex = ImageTexture.create_from_image(fallback)
		frames.add_animation("walk_" + d)
		frames.add_frame("walk_" + d, tex)
		frames.set_animation_loop("walk_" + d, true)
		frames.set_animation_speed("walk_" + d, 8)
		frames.add_animation("idle_" + d)
		frames.add_frame("idle_" + d, tex)
		frames.set_animation_loop("idle_" + d, true)
	sprite.sprite_frames = frames

func _physics_process(delta: float):
	if dialogue_box and dialogue_box.is_active():
		return
	if not is_moving:
		handle_input()
	else:
		move_towards_target(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

func try_interact() -> void:
	if dialogue_box and dialogue_box.is_active():
		return
	if is_moving:
		return
	var target_pos = global_position + Vector2(current_direction.x, current_direction.y) * tile_size
	var target_cell = Vector2i(floori(target_pos.x / tile_size), floori(target_pos.y / tile_size))
	var parent_node = get_parent()
	if not parent_node:
		return
	for sibling in parent_node.get_children():
		if sibling == self or sibling == dialogue_box:
			continue
		if sibling.has_method("interact") and sibling.has_method("get_dialogue"):
			var cell = Vector2i(floori(sibling.position.x / tile_size), floori(sibling.position.y / tile_size))
			if cell == target_cell:
				sibling.interact(self)
				get_viewport().set_input_as_handled()
				dialogue_box.start(sibling.get_display_name(), sibling.get_dialogue())
				return

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
	# Check if target is water using tilemap
	if tilemap:
		var cell = tilemap.get_cell_source_id(tilemap.local_to_map(pos))
		if cell == 0:  # Water source ID
			return false
	return true

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
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / tile_size) * tile_size, round(pos.y / tile_size) * tile_size)
