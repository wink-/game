extends CharacterBody2D

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
		var tex = load("res://assets/sprites/player/e3399290/rotations/" + dirs[d] + ".png")
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
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(colors[d])
			var fallback_tex = ImageTexture.create_from_image(img)
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
