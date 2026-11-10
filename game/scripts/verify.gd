extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		printerr("ZERO FAIL: scene")
		quit(1)
		return
	var current := packed.instantiate()
	root.add_child(current)
	current_scene = current
	await process_frame
	await process_frame
	if current.get_node_or_null("NewIsland") == null:
		printerr("ZERO FAIL: world")
		quit(1)
		return
	if current.get_node_or_null("LocalCharacter") == null:
		printerr("ZERO FAIL: character")
		quit(1)
		return
	if current.get_node_or_null("RoomNetwork") == null:
		printerr("ZERO FAIL: LAN")
		quit(1)
		return
	var crates: Array = current.get("crates")
	var targets: Array = current.get("targets")
	if crates.size() != 18 or targets.size() != 9:
		printerr("ZERO FAIL: loot or training actors")
		quit(1)
		return
	print("ZERO PASS: clean game + 3D world + player + 18 crates + 9 targets + LAN initialized")
	quit(0)
