extends Sprite2D
# Attach to Sprite2D props that the player can talk to / examine.
# Reads its `display_name` and `dialogue` from node metadata, so any sprite
# can become interactable by attaching this script and setting those metas.

signal interacted(node)

var _used: bool = false

func get_display_name() -> String:
	var name_meta = get_meta("display_name", "")
	return name_meta if name_meta != "" else name

func get_dialogue() -> Array:
	return get_meta("dialogue", [])

func is_single_use() -> bool:
	return bool(get_meta("single_use", false))

func interact(actor: Node) -> void:
	if _used:
		return
	interacted.emit(self)
	if is_single_use():
		_used = true
