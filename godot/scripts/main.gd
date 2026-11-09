extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/mobile_joystick.gd")
const CURRENT_VERSION := "0.1.0"
const UPDATE_INFO_URL := "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/godot-native/update_info.json"

var player: CharacterBody3D
var hud_layer: CanvasLayer
var update_request: HTTPRequest
var update_button: Button
var update_status: Label
var update_download_url := ""

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	_setup_updater()
	_check_for_updates()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.79, 0.9)
	environment.ambient_light_energy = 0.65
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.1
	add_child(sun)

	_add_box(Vector3(0, -0.5, 0), Vector3(260, 1, 260), Color(0.24, 0.43, 0.25), true)
	for i in range(-2, 3):
		_add_box(Vector3(i * 36.0, 0.015, 0), Vector3(9, 0.04, 250), Color(0.12, 0.13, 0.15), false)
		_add_box(Vector3(0, 0.02, i * 36.0), Vector3(250, 0.04, 9), Color(0.12, 0.13, 0.15), false)
	for x in range(-2, 3):
		for z in range(-2, 3):
			if x == 0 and z == 0:
				continue
			var h := 8.0 + float(abs(x * 7 + z * 11) % 5) * 2.2
			var w := 13.0 + float((x + z + 8) % 3) * 2.0
			var color := Color(0.48 + 0.04 * float(abs(x) % 3), 0.5, 0.55, 1)
			_add_box(Vector3(x * 36.0 + 18.0, h * 0.5, z * 36.0 + 18.0), Vector3(w, h, w), color, true)

func _add_box(pos: Vector3, dimensions: Vector3, color: Color, solid: bool) -> void:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = Vector3(0, 2, 0)
	add_child(player)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var joystick := Control.new()
	joystick.set_script(JoystickScript)
	joystick.anchor_left = 0.03
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_top = -180
	joystick.offset_bottom = -20
	joystick.offset_right = 180
	hud_layer.add_child(joystick)
	joystick.direction_changed.connect(player.set_mobile_direction)

	var jump_button := _make_button("PULAR", Vector2(-150, -105))
	hud_layer.add_child(jump_button)
	jump_button.pressed.connect(player.jump)
	var run_button := _make_button("CORRER", Vector2(-150, -45))
	hud_layer.add_child(run_button)
	run_button.toggle_mode = true
	run_button.toggled.connect(player.set_running)

func _setup_updater() -> void:
	update_request = HTTPRequest.new()
	update_request.timeout = 15.0
	add_child(update_request)
	update_request.request_completed.connect(_on_update_info_received)

	update_status = Label.new()
	update_status.text = "Versão " + CURRENT_VERSION
	update_status.add_theme_font_size_override("font_size", 18)
	update_status.add_theme_color_override("font_color", Color.WHITE)
	update_status.anchor_left = 0.0
	update_status.anchor_right = 0.0
	update_status.anchor_top = 0.0
	update_status.anchor_bottom = 0.0
	update_status.offset_left = 18
	update_status.offset_top = 14
	update_status.offset_right = 330
	update_status.offset_bottom = 44
	update_status.add_theme_color_override("font_shadow_color", Color.BLACK)
	update_status.add_theme_constant_override("shadow_offset_x", 2)
	update_status.add_theme_constant_override("shadow_offset_y", 2)
	hud_layer.add_child(update_status)

	update_button = Button.new()
	update_button.text = "VERIFICAR ATUALIZAÇÃO"
	update_button.add_theme_font_size_override("font_size", 16)
	update_button.anchor_left = 0.0
	update_button.anchor_right = 0.0
	update_button.anchor_top = 0.0
	update_button.anchor_bottom = 0.0
	update_button.offset_left = 18
	update_button.offset_top = 48
	update_button.offset_right = 270
	update_button.offset_bottom = 94
	hud_layer.add_child(update_button)
	update_button.pressed.connect(_on_update_button_pressed)

func _check_for_updates() -> void:
	if update_request.request(UPDATE_INFO_URL) != OK:
		update_status.text = "Não foi possível verificar atualizações"

func _on_update_button_pressed() -> void:
	if not update_download_url.is_empty():
		OS.shell_open(update_download_url)
	else:
		update_status.text = "Verificando atualização..."
		_check_for_updates()

func _on_update_info_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_status.text = "Sem conexão para verificar atualizações"
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("version") or not data.has("download_url"):
		update_status.text = "Não foi possível ler a versão disponível"
		return
	var latest := str(data["version"])
	update_download_url = str(data["download_url"])
	if _is_newer_version(latest, CURRENT_VERSION):
		update_status.text = "Nova versão disponível: " + latest
		update_button.text = "BAIXAR ATUALIZAÇÃO"
	else:
		update_status.text = "Jogo atualizado • v" + CURRENT_VERSION
		update_button.text = "VERIFICAR NOVAMENTE"

func _is_newer_version(remote: String, local: String) -> bool:
	var remote_parts := remote.split(".")
	var local_parts := local.split(".")
	for i in range(3):
		var remote_value := int(remote_parts[i]) if i < remote_parts.size() else 0
		var local_value := int(local_parts[i]) if i < local_parts.size() else 0
		if remote_value > local_value:
			return true
		if remote_value < local_value:
			return false
	return false

func _make_button(caption: String, offset: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = offset.x - 112
	button.offset_right = offset.x
	button.offset_top = offset.y - 48
	button.offset_bottom = offset.y
	button.custom_minimum_size = Vector2(112, 48)
	return button
