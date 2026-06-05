extends CharacterBody2D

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
	
	var colors = {
		"down": Color.RED,
		"up": Color.BLUE,
		"left": Color.GREEN,
		"right": Color.YELLOW
	}
	
	for dir_name in ["down", "up", "left", "right"]:
		var anim_name = "walk_" + dir_name
		frames.add_animation(anim_name)
		for i in range(4):
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(colors[dir_name])
			var tex = ImageTexture.create_from_image(img)
			frames.add_frame(anim_name, tex)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 8)
		
		anim_name = "idle_" + dir_name
		frames.add_animation(anim_name)
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(colors[dir_name])
		var tex = ImageTexture.create_from_image(img)
		frames.add_frame(anim_name, tex)
		frames.set_animation_loop(anim_name, true)
	
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