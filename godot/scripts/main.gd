extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/mobile_joystick.gd")
var player: CharacterBody3D

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()

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
	var layer := CanvasLayer.new()
	add_child(layer)
	var joystick := Control.new()
	joystick.set_script(JoystickScript)
	joystick.anchor_left = 0.03
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_top = -180
	joystick.offset_bottom = -20
	joystick.offset_right = 180
	layer.add_child(joystick)
	joystick.direction_changed.connect(player.set_mobile_direction)

	var jump_button := _make_button("PULAR", Vector2(-150, -105))
	layer.add_child(jump_button)
	jump_button.pressed.connect(player.jump)
	var run_button := _make_button("CORRER", Vector2(-150, -45))
	layer.add_child(run_button)
	run_button.toggle_mode = true
	run_button.toggled.connect(player.set_running)

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
