extends Node3D

# Protótipo Android nativo inspirado na estrutura de SR-BattleRoyale:
# lobby -> transporte -> salto -> sobrevivência -> zona que diminui.
# Código original em GDScript; NÃO executa scripts GSC do Call of Duty 4.
enum Phase { LOBBY, FLIGHT, DROP, PLAYING, FINISHED }

var player: CharacterBody3D
var phase: int = Phase.LOBBY
var phase_timer := 0.0
var match_timer := 0.0
var zone_radius := 108.0
var health := 100.0
var shield := 100.0
var supplies := {"ammo": 0, "med": 0, "shield": 0}
var loot_nodes: Array[Node3D] = []
var loot_types: Array[String] = []
var current_stage := 0
var damage_timer := 0.0
var plane: Node3D
var parachute: MeshInstance3D
var zone_mesh: MeshInstance3D
var hud: CanvasLayer
var title_label: Label
var status_label: Label
var zone_label: Label
var inventory_label: Label
var drop_button: Button
var heal_button: Button

const ZONE_STAGES := [108.0, 72.0, 44.0, 22.0, 9.0]
const ZONE_SECONDS := [20.0, 32.0, 30.0, 27.0, 27.0]
const LOOT_POSITIONS := [
	Vector3(-9, 0, -11), Vector3(10, 0, -8), Vector3(-13, 0, 15),
	Vector3(26, 0, -14), Vector3(-35, 0, 16), Vector3(42, 0, 31),
	Vector3(-28, 0, -38), Vector3(63, 0, -20), Vector3(-15, 0, 62),
	Vector3(15, 0, -57), Vector3(-67, 0, 19), Vector3(67, 0, 66),
	Vector3(-54, 0, -66), Vector3(51, 0, -64), Vector3(-6, 0, 42),
	Vector3(33, 0, 52), Vector3(-76, 0, -42), Vector3(82, 0, 10)
]

func setup(character: CharacterBody3D) -> void:
	player = character

func _ready() -> void:
	if player == null:
		push_error("BattleRoyale: personagem não configurado")
		return
	_build_zone()
	_build_transport()
	_build_loot()
	_build_hud()
	_set_phase(Phase.LOBBY)
	_refresh_hud()

func _process(delta: float) -> void:
	if player == null:
		return
	phase_timer += delta
	match phase:
		Phase.LOBBY:
			if phase_timer >= 8.0:
				_start_flight()
		Phase.FLIGHT:
			var ratio := minf(phase_timer / 19.0, 1.0)
			plane.position = Vector3(lerpf(-115.0, 115.0, ratio), 62.0, 4.0)
			player.position = plane.position + Vector3(0, 2.0, 0)
			if ratio >= 1.0:
				_start_drop()
		Phase.DROP:
			if player.is_on_floor():
				player.set("parachuting", false)
				parachute.visible = false
				_set_phase(Phase.PLAYING)
		Phase.PLAYING:
			match_timer += delta
			_tick_zone(delta)
			_tick_loot(delta)
			if health <= 0.0:
				_set_phase(Phase.FINISHED)
		Phase.FINISHED:
			pass
	if phase == Phase.DROP:
		_tick_loot(delta)
	_refresh_hud()

func _set_phase(next: int) -> void:
	phase = next
	phase_timer = 0.0
	if drop_button != null:
		drop_button.visible = (phase == Phase.FLIGHT)
	if phase == Phase.PLAYING:
		match_timer = 0.0
	if phase == Phase.FINISHED:
		player.set("parachuting", false)
		status_label.text = "FIM DA PARTIDA · TREINO SOLO"

func _start_flight() -> void:
	plane.visible = true
	player.set_physics_process(false)
	player.position = Vector3(-115, 64, 4)
	_set_phase(Phase.FLIGHT)

func _start_drop() -> void:
	plane.visible = false
	player.set_physics_process(true)
	player.velocity = Vector3(0, -2.0, 0)
	player.set("parachuting", true)
	parachute.visible = true
	_set_phase(Phase.DROP)

func _build_transport() -> void:
	plane = Node3D.new()
	plane.name = "TransportPlane"
	add_child(plane)
	_plane_box(Vector3(0, 0, 0), Vector3(3.0, 1.3, 8.0), Color(0.32, 0.4, 0.49))
	_plane_box(Vector3(0, 0.2, -0.5), Vector3(14.0, 0.2, 2.4), Color(0.42, 0.5, 0.58))
	_plane_box(Vector3(0, 1.2, 3.0), Vector3(5.0, 0.18, 1.25), Color(0.42, 0.5, 0.58))
	_plane_box(Vector3(0, 1.7, 3.5), Vector3(0.2, 2.5, 1.1), Color(0.35, 0.42, 0.52))
	plane.visible = false
	parachute = MeshInstance3D.new()
	parachute.name = "ParachuteCanopy"
	var canopy := SphereMesh.new()
	canopy.radius = 2.1
	canopy.height = 0.75
	parachute.mesh = canopy
	parachute.material_override = _mat(Color(0.95, 0.58, 0.15))
	parachute.position = Vector3(0, 3.4, 0)
	player.add_child(parachute)
	parachute.visible = false

func _plane_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = pos
	plane.add_child(mesh)

func _build_zone() -> void:
	zone_mesh = MeshInstance3D.new()
	zone_mesh.name = "SafeZoneBorder"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.985
	ring.outer_radius = 1.0
	ring.rings = 12
	ring.ring_segments = 96
	zone_mesh.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.17)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.05)
	mat.emission_energy_multiplier = 1.1
	zone_mesh.material_override = mat
	zone_mesh.position.y = 0.35
	add_child(zone_mesh)
	_update_zone_ring()

func _update_zone_ring() -> void:
	if zone_mesh != null:
		zone_mesh.scale = Vector3(zone_radius, 1.0, zone_radius)

func _tick_zone(delta: float) -> void:
	var elapsed := match_timer
	var stage_start := 0.0
	for i in range(ZONE_STAGES.size() - 1):
		var stage_length: float = ZONE_SECONDS[i]
		if elapsed < stage_start + stage_length:
			current_stage = i
			var progress := clampf((elapsed - stage_start) / stage_length, 0.0, 1.0)
			zone_radius = lerpf(ZONE_STAGES[i], ZONE_STAGES[i + 1], progress)
			break
		stage_start += stage_length
		current_stage = i + 1
		zone_radius = ZONE_STAGES[i + 1]
	_update_zone_ring()
	var location := Vector2(player.global_position.x, player.global_position.z)
	if location.length() > zone_radius:
		damage_timer += delta
		if damage_timer >= 1.0:
			damage_timer = 0.0
			var remaining_damage := 6.0
			var absorbed := minf(shield, remaining_damage)
			shield -= absorbed
			remaining_damage -= absorbed
			health = maxf(0.0, health - remaining_damage)
	else:
		damage_timer = 0.0

func _build_loot() -> void:
	for i in range(LOOT_POSITIONS.size()):
		var kind := "ammo"
		if i % 3 == 1:
			kind = "med"
		elif i % 3 == 2:
			kind = "shield"
		var color := Color(1.0, 0.76, 0.25)
		if kind == "med":
			color = Color(0.25, 0.92, 0.5)
		elif kind == "shield":
			color = Color(0.25, 0.69, 1.0)
		var node := Node3D.new()
		node.name = "Supply_%d_%s" % [i, kind]
		node.position = LOOT_POSITIONS[i] + Vector3(0, 0.58, 0)
		var crate := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(1.4, 1.1, 1.4)
		crate.mesh = cube
		crate.material_override = _mat(color)
		node.add_child(crate)
		var accent := MeshInstance3D.new()
		var accent_box := BoxMesh.new()
		accent_box.size = Vector3(1.55, 0.16, 1.55)
		accent.mesh = accent_box
		accent.position.y = 0.22
		accent.material_override = _mat(Color(0.1, 0.16, 0.18))
		node.add_child(accent)
		add_child(node)
		loot_nodes.append(node)
		loot_types.append(kind)

func _tick_loot(delta: float) -> void:
	for i in range(loot_nodes.size()):
		var node := loot_nodes[i]
		if not is_instance_valid(node) or not node.visible:
			continue
		node.rotate_y(delta * 0.5)
		if Vector2(node.global_position.x - player.global_position.x,
				node.global_position.z - player.global_position.z).length() < 2.1:
			node.visible = false
			var kind := loot_types[i]
			supplies[kind] += 1
			if kind == "med":
				health = minf(100.0, health + 35.0)
			elif kind == "shield":
				shield = minf(100.0, shield + 35.0)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "BattleRoyaleHUD"
	add_child(hud)
	title_label = _label("SR BATTLE ROYALE · ANDROID", Vector2(16, 108), 21, Color(1.0, 0.92, 0.68))
	status_label = _label("PREPARANDO PARTIDA", Vector2(16, 139), 19, Color.WHITE)
	zone_label = _label("ZONA SEGURA", Vector2(16, 173), 17, Color(1.0, 0.75, 0.32))
	inventory_label = _label("VIDA 100 · ESCUDO 100", Vector2(16, 204), 18, Color(0.78, 1.0, 0.81))
	drop_button = Button.new()
	drop_button.text = "SALTAR DO AVIÃO"
	drop_button.anchor_left = 0.5
	drop_button.anchor_right = 0.5
	drop_button.anchor_top = 0.75
	drop_button.anchor_bottom = 0.75
	drop_button.offset_left = -105
	drop_button.offset_right = 105
	drop_button.offset_top = -30
	drop_button.offset_bottom = 35
	drop_button.add_theme_font_size_override("font_size", 20)
	hud.add_child(drop_button)
	drop_button.pressed.connect(_start_drop)
	heal_button = Button.new()
	heal_button.text = "USAR KIT"
	heal_button.anchor_left = 1.0
	heal_button.anchor_right = 1.0
	heal_button.anchor_top = 1.0
	heal_button.anchor_bottom = 1.0
	heal_button.offset_left = -380
	heal_button.offset_right = -245
	heal_button.offset_top = -112
	heal_button.offset_bottom = -53
	hud.add_child(heal_button)
	heal_button.pressed.connect(_use_medkit)

func _label(txt: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = txt
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(label)
	return label

func take_damage(amount: float) -> void:
	if phase != Phase.PLAYING:
		return
	var remaining := maxf(amount, 0.0)
	var absorbed := minf(shield, remaining)
	shield -= absorbed
	remaining -= absorbed
	health = maxf(0.0, health - remaining)
	_refresh_hud()
	if health <= 0.0:
		_set_phase(Phase.FINISHED)

func _use_medkit() -> void:
	if int(supplies["med"]) > 0 and health < 100.0:
		supplies["med"] -= 1
		health = minf(100.0, health + 45.0)

func _refresh_hud() -> void:
	if status_label == null:
		return
	match phase:
		Phase.LOBBY:
			status_label.text = "LOBBY · INÍCIO EM %ds" % maxi(0, int(ceil(8.0 - phase_timer)))
		Phase.FLIGHT:
			status_label.text = "AVIÃO · TOQUE EM SALTAR"
		Phase.DROP:
			status_label.text = "PARAQUEDAS · PREPARE O POUSO"
		Phase.PLAYING:
			status_label.text = "PARTIDA SOLO · SOBREVIVA"
		Phase.FINISHED:
			status_label.text = "FIM DE PARTIDA · TREINO SOLO"
	zone_label.text = "ZONA SEGURA · %dm · FASE %d" % [int(zone_radius), current_stage + 1]
	inventory_label.text = "VIDA %d · ESCUDO %d  |  MUNIÇÃO %d  KIT %d  ESCUDO %d" % [
		int(health), int(shield), int(supplies["ammo"]), int(supplies["med"]), int(supplies["shield"])
	]
	heal_button.disabled = int(supplies["med"]) < 1 or health >= 100.0

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
