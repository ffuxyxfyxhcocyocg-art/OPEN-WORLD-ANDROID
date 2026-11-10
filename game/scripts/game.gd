extends Node3D

# New original implementation, following the SR mod's round phases.
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/joystick.gd")
const NetworkScript = preload("res://scripts/network.gd")
const MapScript = preload("res://scripts/minimap.gd")
enum Phase { LOBBY, PLANE, DROP, PLAYING, FINISHED }
const ZONES := [111.0, 75.0, 45.0, 23.0, 9.0]
const STEP_TIME := [27.0, 29.0, 26.0, 25.0]
const SUPPLY_POS := [
	Vector3(-9, 0, -12), Vector3(10, 0, -7), Vector3(-13, 0, 15),
	Vector3(26, 0, -14), Vector3(-32, 0, 17), Vector3(42, 0, 31),
	Vector3(-29, 0, -35), Vector3(63, 0, -20), Vector3(-16, 0, 60),
	Vector3(17, 0, -59), Vector3(-69, 0, 19), Vector3(68, 0, 62),
	Vector3(-51, 0, -67), Vector3(52, 0, -66), Vector3(0, 0, 35),
	Vector3(34, 0, 53), Vector3(-75, 0, -44), Vector3(85, 0, 9)
]

var phase: int = Phase.LOBBY
var phase_time := 0.0
var survival_time := 0.0
var safe_radius := 111.0
var zone_center := Vector2(-7.0, -12.0)
var life := 100.0
var shield := 60.0
var ammo := 36
var clips := [24, 12, 7]
var scores := 0
var kits := 0
var player: CharacterBody3D
var plane: Node3D
var ring: MeshInstance3D
var parachute: MeshInstance3D
var net: Node
var hud: CanvasLayer
var label_phase: Label
var label_stats: Label
var label_zone: Label
var label_weapon: Label
var button_drop: Button
var button_heal: Button
var weapon_slot := 0
var last_fire := 0.0
var crates: Array[Node3D] = []
var crate_types: Array[String] = []
var targets: Array[StaticBody3D] = []
var zone_damage_timer := 0.0

func _ready() -> void:
	var world = WorldScript.new()
	world.name = "NewIsland"
	add_child(world)
	player = PlayerScript.new()
	player.name = "LocalCharacter"
	player.position = Vector3(0, 4, 0)
	add_child(player)
	_make_plane()
	_make_zone()
	_make_loot()
	_make_targets()
	_build_hud()
	net = NetworkScript.new()
	net.name = "RoomNetwork"
	net.setup(player, self)
	add_child(net)
	_enter_phase(Phase.LOBBY)

func _process(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.LOBBY:
			if phase_time >= 7.0:
				_launch_plane()
		Phase.PLANE:
			var percent := minf(phase_time / 18.0, 1.0)
			plane.position = Vector3(lerpf(-116, 116, percent), 57.0, 0)
			player.position = plane.position + Vector3(0, 1.4, 0)
			if percent >= 1.0:
				_drop()
		Phase.DROP:
			if player.is_on_floor():
				player.gliding = false
				parachute.visible = false
				_enter_phase(Phase.PLAYING)
		Phase.PLAYING:
			survival_time += delta
			_tick_zone(delta)
			_tick_loot(delta)
			if life <= 0:
				_enter_phase(Phase.FINISHED)
		Phase.FINISHED:
			pass
	_update_ui()

func _enter_phase(value: int) -> void:
	phase = value
	phase_time = 0.0
	if button_drop != null:
		button_drop.visible = phase == Phase.PLANE
	if phase == Phase.PLAYING:
		survival_time = 0.0

func _launch_plane() -> void:
	plane.visible = true
	player.set_physics_process(false)
	_enter_phase(Phase.PLANE)

func _drop() -> void:
	plane.visible = false
	player.set_physics_process(true)
	player.velocity = Vector3(0, -1.0, 0)
	player.gliding = true
	parachute.visible = true
	_enter_phase(Phase.DROP)

func _make_plane() -> void:
	plane = Node3D.new()
	plane.name = "Transport"
	add_child(plane)
	_plane_box(Vector3.ZERO, Vector3(2.6, 1.15, 8.0), Color(0.33, 0.43, 0.48))
	_plane_box(Vector3(0, 0.1, 0), Vector3(13.0, 0.22, 2.3), Color(0.42, 0.50, 0.54))
	_plane_box(Vector3(0, 1.1, 2.4), Vector3(5.0, 0.19, 1.3), Color(0.37, 0.46, 0.50))
	plane.visible = false
	parachute = MeshInstance3D.new()
	var balloon := SphereMesh.new()
	balloon.radius = 2.3
	balloon.height = 0.75
	parachute.mesh = balloon
	parachute.material_override = _mat(Color(0.91, 0.57, 0.14))
	parachute.position = Vector3(0, 3.4, 0)
	player.add_child(parachute)
	parachute.visible = false

func _plane_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = _mat(color)
	instance.position = pos
	plane.add_child(instance)

func _make_zone() -> void:
	ring = MeshInstance3D.new()
	ring.name = "VisibleSafeZone"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.991
	torus.outer_radius = 1.0
	torus.ring_segments = 96
	ring.mesh = torus
	ring.material_override = _mat(Color(1.0, 0.75, 0.16))
	ring.position = Vector3(zone_center.x, 0.25, zone_center.y)
	add_child(ring)
	_refresh_ring()

func _refresh_ring() -> void:
	ring.scale = Vector3(safe_radius, 1, safe_radius)

func _tick_zone(delta: float) -> void:
	var elapsed := survival_time
	var before := 0.0
	for i in range(STEP_TIME.size()):
		var duration: float = STEP_TIME[i]
		if elapsed <= before + duration:
			safe_radius = lerpf(ZONES[i], ZONES[i + 1], clampf((elapsed - before) / duration, 0, 1))
			break
		safe_radius = ZONES[i + 1]
		before += duration
	_refresh_ring()
	var distance := Vector2(player.position.x, player.position.z).distance_to(zone_center)
	if distance > safe_radius:
		zone_damage_timer += delta
		if zone_damage_timer >= 1.0:
			zone_damage_timer = 0
			take_damage(8)
	else:
		zone_damage_timer = 0

func _make_loot() -> void:
	for i in range(SUPPLY_POS.size()):
		var type := "ammo"
		var tint := Color(1.0, 0.75, 0.19)
		if i % 3 == 1:
			type = "heal"
			tint = Color(0.31, 0.93, 0.48)
		elif i % 3 == 2:
			type = "shield"
			tint = Color(0.27, 0.69, 1.0)
		var node := Node3D.new()
		node.name = "Loot_%s_%d" % [type, i]
		node.position = SUPPLY_POS[i] + Vector3(0, 0.62, 0)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.45, 1.18, 1.45)
		mesh.mesh = box
		mesh.material_override = _mat(tint)
		node.add_child(mesh)
		add_child(node)
		crates.append(node)
		crate_types.append(type)

func _tick_loot(delta: float) -> void:
	for i in range(crates.size()):
		var crate := crates[i]
		if not crate.visible:
			continue
		crate.rotate_y(0.65 * delta)
		if crate.global_position.distance_to(player.global_position) < 2.6:
			crate.visible = false
			var kind := crate_types[i]
			if kind == "ammo":
				ammo += 20
			elif kind == "heal":
				kits += 1
			elif kind == "shield":
				shield = minf(100, shield + 35)

func _make_targets() -> void:
	for i in range(9):
		var angle := float(i) / 9.0 * TAU
		var location := Vector3(cos(angle) * 38, 0, sin(angle) * 38)
		var body := StaticBody3D.new()
		body.name = "Target_%d" % i
		body.position = location
		body.set_meta("target_health", 50.0)
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.95
		collision.shape = sphere
		collision.position.y = 2.0
		body.add_child(collision)
		var mesh := MeshInstance3D.new()
		var visual := SphereMesh.new()
		visual.radius = 0.95
		visual.height = 1.9
		mesh.mesh = visual
		mesh.position.y = 2.0
		mesh.material_override = _mat(Color(0.96, 0.60, 0.22))
		body.add_child(mesh)
		add_child(body)
		targets.append(body)

func _fire() -> void:
	if phase != Phase.PLAYING:
		return
	var seconds := Time.get_ticks_msec() * 0.001
	if seconds - last_fire < [0.19, 0.41, 0.13][weapon_slot]:
		return
	if clips[weapon_slot] <= 0:
		return
	last_fire = seconds
	clips[weapon_slot] -= 1
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.global_position
	var to := origin - camera.global_transform.basis.z * 95.0
	var ray := PhysicsRayQueryParameters3D.create(origin, to)
	ray.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(ray)
	if not result.is_empty():
		to = result["position"]
		var collider = result["collider"]
		if collider is StaticBody3D:
			var other := collider as StaticBody3D
			if other.has_meta("target_health"):
				var hp := float(other.get_meta("target_health")) - 18.0
				if hp <= 0:
					hp = 50.0
					scores += 1
					other.visible = false
					other.collision_layer = 0
					get_tree().create_timer(7).timeout.connect(func():
						if is_instance_valid(other):
							other.visible = true
							other.collision_layer = 1
					)
				other.set_meta("target_health", hp)
			elif other.has_meta("remote_peer"):
				net.report_hit(int(other.get_meta("remote_peer")), 18.0)
	_tracer(origin, to)

func _tracer(origin: Vector3, to: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.08, 0.08, maxf(0.1, origin.distance_to(to)))
	beam.mesh = shape
	beam.material_override = _mat(Color(1.0, 0.87, 0.25))
	add_child(beam)
	beam.global_position = (origin + to) * 0.5
	if origin.distance_to(to) > 0.1:
		beam.look_at(to, Vector3.UP)
	get_tree().create_timer(0.11).timeout.connect(func():
		if is_instance_valid(beam):
			beam.queue_free()
	)

func _reload() -> void:
	var max_clip := [24, 12, 7][weapon_slot]
	var missing: int = max_clip - clips[weapon_slot]
	var amount: int = mini(missing, ammo)
	clips[weapon_slot] += amount
	ammo -= amount

func _heal() -> void:
	if kits > 0 and life < 100:
		kits -= 1
		life = minf(100, life + 45)

func take_damage(amount: float) -> void:
	if phase != Phase.PLAYING:
		return
	var absorbed := minf(shield, amount)
	shield -= absorbed
	life = maxf(0, life - (amount - absorbed))

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	label_phase = _label("LOBBY", Vector2(15, 9), 22)
	label_stats = _label("VIDA 100", Vector2(15, 39), 18)
	label_zone = _label("ZONA", Vector2(15, 67), 16)
	label_weapon = _label("ENERGIA", Vector2(15, 94), 16)
	var joystick = JoystickScript.new()
	joystick.position = Vector2(25, 500)
	joystick.size = Vector2(185, 185)
	hud.add_child(joystick)
	joystick.direction_changed.connect(player.move_mobile)
	var jump := _button("PULAR", -142, -192, 125, 47)
	jump.pressed.connect(player.jump)
	var run := _button("CORRER", -142, -139, 125, 47)
	run.toggle_mode = true
	run.toggled.connect(player.set_running)
	button_drop = _button("SALTAR", -275, -220, 125, 52)
	button_drop.pressed.connect(_drop)
	button_heal = _button("KIT", -275, -159, 125, 47)
	button_heal.pressed.connect(_heal)
	var fire := _button("PULSO", -142, -86, 125, 65)
	fire.pressed.connect(_fire)
	var reload := _button("RECARGA", -275, -105, 125, 47)
	reload.pressed.connect(_reload)
	var slots := ["RIFLE", "PISTOLA", "RAIO"]
	for i in range(3):
		var selection := i
		var slot := _button(slots[i], -412 + i * 130, -45, 120, 38)
		slot.pressed.connect(func(): weapon_slot = selection)
	var minimap = MapScript.new()
	minimap.name = "BattleMinimap"
	minimap.position = Vector2(1040, 16)
	minimap.size = Vector2(195, 195)
	minimap.setup(player, self)
	hud.add_child(minimap)

func _label(content: String, pos: Vector2, point_size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.position = pos
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	hud.add_child(label)
	return label

func _button(content: String, offset_x: float, offset_y: float, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = content
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = offset_x
	button.offset_right = offset_x + width
	button.offset_top = offset_y
	button.offset_bottom = offset_y + height
	hud.add_child(button)
	return button

func _update_ui() -> void:
	if label_phase == null:
		return
	match phase:
		Phase.LOBBY:
			label_phase.text = "LOBBY · INÍCIO %ds" % maxi(0, int(ceil(7 - phase_time)))
		Phase.PLANE:
			label_phase.text = "AVIÃO · SALTE AGORA"
		Phase.DROP:
			label_phase.text = "PARAQUEDAS · POUSANDO"
		Phase.PLAYING:
			label_phase.text = "SOBREVIVA · ALVOS %d" % scores
		Phase.FINISHED:
			label_phase.text = "FIM DA RODADA"
	label_stats.text = "VIDA %d · ESCUDO %d · KITS %d" % [int(life), int(shield), kits]
	label_zone.text = "ZONA %dm · TEMPO %ds" % [int(safe_radius), int(survival_time)]
	label_weapon.text = "%s · %d / %d" % [["RIFLE", "PISTOLA", "RAIO"][weapon_slot], clips[weapon_slot], ammo]
	if button_heal != null:
		button_heal.disabled = kits == 0 or life >= 100

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	return material
