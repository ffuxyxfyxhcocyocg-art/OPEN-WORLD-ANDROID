extends SceneTree

# CI-only native scene integration test (works under headless Godot).
func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		printerr("SMOKE FAIL: main.tscn missing")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var arena := scene.get_node_or_null("IslandArena3D")
	var battle := scene.get_node_or_null("SRBattleRoyale")
	var network := scene.get_node_or_null("LANMultiplayer")
	var combat := scene.get_node_or_null("ArcadeCombat")
	var controlled := scene.get("player") as CharacterBody3D
	var okay := arena != null and battle != null and combat != null and network != null and controlled != null
	if not okay:
		printerr("SMOKE FAIL: native scene missing game systems")
		quit(1)
		return
	var loot_nodes: Array = battle.get("loot_nodes")
	var drones: Array = combat.get("targets")
	var has_terrain := arena.has_node("Ocean") and arena.has_node("IslandArena3D") == false
	print("SCENE: island=", has_terrain, " supplies=", loot_nodes.size(), " drone_targets=", drones.size())
	var model_found := controlled.find_child("Midas3D", true, false) != null
	print("CHARACTER: Midas import=", model_found, " fallback_active=", not model_found)
	if not has_terrain or loot_nodes.size() != 18 or drones.size() != 9:
		printerr("SMOKE FAIL: scenery or gameplay content not initialized")
		quit(1)
		return
	print("SMOKE PASS: native 3D world, loot, combat, network and player initialized.")
	quit(0)
