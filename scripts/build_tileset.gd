#!/usr/bin/env -S godot --headless --script
# TileSet Builder — generates .tres from curated tiles
# Run: godot --headless --script scripts/build_tileset.gd

extends SceneTree

@export var source_dir: String = "res://assets/tilesets/curated"
@export var output_path: String = "res://assets/tilesets/tileset.tres"
@export var tile_size: int = 16

func _init():
	build_tileset()
	quit()

func build_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(tile_size, tile_size)
	
	var atlas = TileSetAtlasSource.new()
	
	# Collect all PNG files
	var files = get_png_files(source_dir)
	if files.is_empty():
		print("No PNG files found in ", source_dir)
		return
	
	# Build atlas texture
	var atlas_tex = build_atlas_texture(files)
	atlas.texture = atlas_tex
	
	# Add tiles to atlas
	for i in range(files.size()):
		var coords = Vector2i(i % 16, i / 16)
		atlas.create_tile(coords)
		# Add collision to water tiles ( heuristic: filename contains "water" )
		if files[i].contains("water"):
			var physics = TileData.new()
			physics.add_collision_polygon(0)
			# Physics polygon would be set here
	
	tileset.add_source(atlas, 0)
	
	var err = ResourceSaver.save(tileset, output_path)
	if err == OK:
		print("TileSet saved to ", output_path)
		print("Tiles: ", files.size())
	else:
		print("Failed to save TileSet: ", err)

func get_png_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".png"):
			result.append(dir_path + "/" + file)
		file = dir.get_next()
	dir.list_dir_end()
	
	result.sort()
	return result

func build_atlas_texture(files: Array[String]) -> ImageTexture:
	var cols = 16
	var rows = (files.size() + cols - 1) / cols
	var atlas_img = Image.create(cols * tile_size, rows * tile_size, false, Image.FORMAT_RGBA8)
	
	for i in range(files.size()):
		var img = Image.load_from_file(files[i])
		if img:
			var x = (i % cols) * tile_size
			var y = (i / cols) * tile_size
			atlas_img.blit_rect(img, Rect2i(0, 0, tile_size, tile_size), Vector2i(x, y))
	
	return ImageTexture.create_from_image(atlas_img)