extends Control

# Original Godot minimap; reads the battle-mode arena positions.
var player: CharacterBody3D
var battle: Node3D
var expanded := false
var refresh_clock := 0.0

func setup(character: CharacterBody3D, manager: Node3D) -> void:
	player = character
	battle = manager
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	custom_minimum_size = Vector2(186, 186)

func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 0.14:
		refresh_clock = 0.0
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		expanded = not expanded
		_update_size()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		expanded = not expanded
		_update_size()
		accept_event()

func _update_size() -> void:
	if expanded:
		offset_left = -510
		offset_right = -10
		offset_top = 40
		offset_bottom = 540
	else:
		offset_left = -205
		offset_right = -15
		offset_top = 18
		offset_bottom = 208
	queue_redraw()

func _draw() -> void:
	if player == null or battle == null:
		return
	var size := get_rect().size
	var width: float = minf(size.x, size.y)
	var center := size * 0.5
	var unit_scale: float = width / 300.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.13, 0.19, 0.96), true)
	draw_circle(center, 141.0 * unit_scale, Color(0.11, 0.31, 0.51))
	draw_circle(center, 134.0 * unit_scale, Color(0.76, 0.68, 0.44))
	draw_circle(center, 128.0 * unit_scale, Color(0.26, 0.44, 0.26))
	for i in range(-2, 3):
		var x: float = float(i) * 42.0 * unit_scale
		draw_line(center + Vector2(x, -124 * unit_scale), center + Vector2(x, 124 * unit_scale), Color(0.16, 0.22, 0.26), 4.5 * unit_scale)
		draw_line(center + Vector2(-124 * unit_scale, x), center + Vector2(124 * unit_scale, x), Color(0.16, 0.22, 0.26), 4.5 * unit_scale)
	var radius: float = float(battle.get("zone_radius"))
	var zone_origin: Vector2 = battle.get("zone_center")
	draw_arc(center + zone_origin * unit_scale, radius * unit_scale, 0.0, TAU, 96, Color(1, 0.79, 0.27), 3.0)
	var crates: Array = battle.get("loot_nodes")
	for crate in crates:
		if not is_instance_valid(crate) or not crate.visible:
			continue
		var kind := str(crate.name)
		var color := Color(1.0, 0.77, 0.27)
		if "med" in kind:
			color = Color(0.34, 1.0, 0.49)
		elif "shield" in kind:
			color = Color(0.39, 0.79, 1.0)
		var pos: Vector3 = crate.global_position
		draw_rect(Rect2(center + Vector2(pos.x, pos.z) * unit_scale - Vector2(3, 3), Vector2(6, 6)), color)
	var location := player.global_position
	var dot := center + Vector2(location.x, location.z) * unit_scale
	draw_circle(dot, 5.0, Color(1.0, 0.96, 0.61))
	draw_arc(dot, 6.0, 0, TAU, 20, Color(0.09, 0.16, 0.22), 1.2)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.9, 0.92), false, 2.0)
