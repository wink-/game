#!/usr/bin/env -S godot --headless --script

# TileSet Validation Script
# Run: godot --headless --script scripts/validate_tileset.gd --path assets/tilesets/curated

@tool
extends SceneTree

var tileset_path: String = "assets/tilesets/curated"
var tile_size: Vector2i = Vector2i(16, 16)
var max_colors: int = 16
var errors: Array[String] = []
var warnings: Array[String] = []

func _init():
	parse_args()
	validate_tileset()
	print_report()
	quit(errors.size())

func parse_args():
	var args = get_command_line_args()
	for i in range(args.size()):
		if args[i] == "--path" and i + 1 < args.size():
			tileset_path = args[i + 1]
		elif args[i] == "--size" and i + 1 < args.size():
			var parts = args[i + 1].split("x")
			if parts.size() == 2:
				tile_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif args[i] == "--max-colors" and i + 1 < args.size():
			max_colors = args[i + 1].to_int()

func validate_tileset():
	var dir = DirAccess.open(tileset_path)
	if not dir:
		errors.append("Directory not found: %s" % tileset_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.begins_with(".") and (file_name.ends_with(".png") or file_name.ends_with(".tscn")):
			validate_tile("%s/%s" % [tileset_path, file_name], file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func validate_tile(full_path: String, file_name: String):
	var img = Image.load_from_file(full_path)
	if not img:
		errors.append("%s: Failed to load image" % file_name)
		return

	# Check dimensions
	if img.get_size() != tile_size:
		errors.append("%s: Expected %s, got %s" % [file_name, tile_size, img.get_size()])

	# Check color count
	var unique_colors = get_unique_colors(img)
	if unique_colors > max_colors:
		errors.append("%s: %d colors (max %d)" % [file_name, unique_colors, max_colors])
	elif unique_colors > max_colors * 0.8:
		warnings.append("%s: %d colors (approaching max %d)" % [file_name, unique_colors, max_colors])

	# Check seamless tiling (basic edge comparison)
	if not check_seamless(img):
		warnings.append("%s: Edges may not tile seamlessly" % file_name)

func get_unique_colors(img: Image) -> int:
	var colors: Dictionary = {}
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			var key = "%d,%d,%d,%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255), int(c.a * 255)]
			colors[key] = true
	return colors.size()

func check_seamless(img: Image) -> bool:
	# Compare left/right edges
	for y in range(img.get_height()):
		var left = img.get_pixel(0, y)
		var right = img.get_pixel(img.get_width() - 1, y)
		if not colors_similar(left, right):
			return false

	# Compare top/bottom edges
	for x in range(img.get_width()):
		var top = img.get_pixel(x, 0)
		var bottom = img.get_pixel(x, img.get_height() - 1)
		if not colors_similar(top, bottom):
			return false
	return true

func colors_similar(a: Color, b: Color, threshold: float = 0.02) -> bool:
	return abs(a.r - b.r) < threshold and abs(a.g - b.g) < threshold and abs(a.b - b.b) < threshold and abs(a.a - b.a) < threshold

func print_report():
	print("\n=== TileSet Validation Report ===")
	print("Path: %s" % tileset_path)
	print("Tile size: %s" % tile_size)
	print("Max colors: %d" % max_colors)
	print("Errors: %d" % errors.size())
	print("Warnings: %d" % warnings.size())

	if errors:
		print("\n--- ERRORS ---")
		for e in errors:
			print("  ✗ %s" % e)

	if warnings:
		print("\n--- WARNINGS ---")
		for w in warnings:
			print("  ⚠ %s" % w)

	if not errors and not warnings:
		print("\n✓ All checks passed!")