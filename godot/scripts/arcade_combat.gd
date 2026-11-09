extends Node3D

# Fictional arcade combat, with original geometries, non-graphic effects and target drones.
# Includes three loadout slots, magazine/ammo management, recoil and multiplayer hit events.
const MODE_NAMES := ["RIFLE", "PISTOLA", "ENERGIA"]
const MAGAZINE_MAX := [24, 12, 8]
const POWER := [16.0, 25.0, 13.0]
const COOLDOWN := [0.14, 0.34, 0.08]
const DRONE_POINTS := [
	Vector3(-25, 0, -18), Vector3(25, 0, 19), Vector3(51, 0, 17),
	Vector3(-49, 0, 26), Vector3(28, 0, -52), Vector3(-65, 0, -38),
	Vector3(0, 0, 49), Vector3(73, 0, 47), Vector3(-34, 0, 63)
]

var player: CharacterBody3D
var battle: Node3D
var network: Node3D
var hud: CanvasLayer
var ammo_label: Label
var hits_label: Label
var fire_button: Button
var selected_mode := 0
var magazines := [24, 12, 8]
var reserve := [96, 36, 24]
var last_shot := 0.0
var last_mode := 0
var targets: Array[StaticBody3D] = []
var score := 0
var reticle: Label

func setup(character: CharacterBody3D, game: Node3D, multiplayer_node: Node3D) -> void:
	player = character
	battle = game
	network = multiplayer_node

func _ready() -> void:
	_make_hud()
	_make_targets()
	_refresh()

func _make_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "ArcadeCombatHUD"
	add_child(hud)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -295
	panel.offset_right = -8
	panel.offset_top = -175
	panel.offset_bottom = -10
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	ammo_label = Label.new()
	ammo_label.text = "RIFLE"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ammo_label)
	var slots := HBoxContainer.new()
	column.add_child(slots)
	for i in range(MODE_NAMES.size()):
		var slot := Button.new()
		slot.text = MODE_NAMES[i]
		slot.custom_minimum_size = Vector2(87, 37)
		slots.add_child(slot)
		var selected := i
		slot.pressed.connect(func(): _choose(selected))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	fire_button = Button.new()
	fire_button.text = "DISPARAR"
	fire_button.custom_minimum_size = Vector2(168, 55)
	actions.add_child(fire_button)
	fire_button.pressed.connect(_fire)
	var reload := Button.new()
	reload.text = "RECARGA"
	reload.custom_minimum_size = Vector2(103, 55)
	actions.add_child(reload)
	reload.pressed.connect(_reload)
	reticle = Label.new()
	reticle.text = "+"
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.50
	reticle.anchor_bottom = 0.50
	reticle.offset_left = -12
	reticle.offset_right = 12
	reticle.offset_top = -16
	reticle.offset_bottom = 17
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 25)
	reticle.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70))
	hud.add_child(reticle)
	hits_label = Label.new()
	hits_label.text = "ALVOS 0"
	hits_label.position = Vector2(16, 234)
	hits_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(hits_label)

func _choose(mode: int) -> void:
	selected_mode = clampi(mode, 0, MODE_NAMES.size() - 1)
	_refresh()

func _fire() -> void:
	if int(battle.get("phase")) != 3:
		return
	var seconds := Time.get_ticks_msec() / 1000.0
	if seconds - last_shot < COOLDOWN[selected_mode]:
		return
	if magazines[selected_mode] <= 0:
		_reload()
		return
	last_shot = seconds
	magazines[selected_mode] -= 1
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.global_transform.origin
	var end := origin + (-camera.global_transform.basis.z) * 90.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"]
		var collider = hit["collider"]
		if collider is StaticBody3D:
			var actor := collider as StaticBody3D
			if actor.has_meta("peer_id"):
				network.request_hit(int(actor.get_meta("peer_id")), POWER[selected_mode])
			elif actor.has_meta("target_hp"):
				_hit_target(actor)
	_impact_effect(end)
	_tracer_effect(origin + Vector3(0, -0.14, 0), end)
	_refresh()

func _hit_target(actor: StaticBody3D) -> void:
	var hp: float = float(actor.get_meta("target_hp", 60.0))
	hp -= POWER[selected_mode]
	if hp > 0.0:
		actor.set_meta("target_hp", hp)
		return
	actor.set_meta("target_hp", 60.0)
	score += 1
	actor.visible = false
	actor.collision_layer = 0
	hits_label.text = "ALVOS " + str(score)
	var timer := get_tree().create_timer(7.0)
	timer.timeout.connect(func():
		if is_instance_valid(actor):
			actor.visible = true
			actor.collision_layer = 1
	)

func _tracer_effect(start: Vector3, end: Vector3) -> void:
	if start.distance_to(end) < 0.5:
		return
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.065, 0.065, start.distance_to(end))
	beam.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.21)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.48, 0.12)
	beam.material_override = material
	get_tree().current_scene.add_child(beam)
	beam.global_position = (start + end) * 0.5
	beam.look_at(end, Vector3.UP)
	var timer := get_tree().create_timer(0.075)
	timer.timeout.connect(func(): if is_instance_valid(beam): beam.queue_free())

func _impact_effect(position: Vector3) -> void:
	var hit_flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	hit_flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.28)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.08)
	hit_flash.material_override = material
	get_tree().current_scene.add_child(hit_flash)
	hit_flash.global_position = position
	var tween := create_tween()
	tween.tween_property(hit_flash, "scale", Vector3(0.01, 0.01, 0.01), 0.22)
	tween.finished.connect(func(): if is_instance_valid(hit_flash): hit_flash.queue_free())

func _reload() -> void:
	var missing: int = MAGAZINE_MAX[selected_mode] - magazines[selected_mode]
	if missing <= 0:
		return
	# One ammo supply crate contributes 24 reserve shots.
	if reserve[selected_mode] < missing and int(battle.supplies.get("ammo", 0)) > 0:
		battle.supplies["ammo"] = int(battle.supplies["ammo"]) - 1
		reserve[selected_mode] += 24
	var available: int = mini(missing, reserve[selected_mode])
	magazines[selected_mode] += available
	reserve[selected_mode] -= available
	_refresh()

func _refresh() -> void:
	if ammo_label != null:
		ammo_label.text = "%s  %d / %d" % [MODE_NAMES[selected_mode], magazines[selected_mode], reserve[selected_mode]]

func _make_targets() -> void:
	for i in range(DRONE_POINTS.size()):
		var actor := StaticBody3D.new()
		actor.name = "TrainingDrone_%d" % i
		actor.set_meta("target_hp", 60.0)
		actor.position = DRONE_POINTS[i]
		var collider := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.83
		collider.shape = shape
		collider.position.y = 1.9
		actor.add_child(collider)
		var mesh := MeshInstance3D.new()
		var body := SphereMesh.new()
		body.radius = 0.83
		body.height = 1.66
		body.radial_segments = 10
		body.rings = 6
		mesh.mesh = body
		mesh.position.y = 1.9
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.56, 0.21)
		material.metallic = 0.35
		material.roughness = 0.43
		mesh.material_override = material
		actor.add_child(mesh)
		var accent := MeshInstance3D.new()
		var glow := SphereMesh.new()
		glow.radius = 0.28
		glow.height = 0.56
		accent.mesh = glow
		accent.position = Vector3(0, 2.05, -0.73)
		var eye := StandardMaterial3D.new()
		eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.albedo_color = Color(0.29, 0.88, 0.97)
		accent.material_override = eye
		actor.add_child(accent)
		add_child(actor)
		targets.append(actor)
