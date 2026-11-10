extends CharacterBody3D

var mobile_direction := Vector2.ZERO
var running := false
var gliding := false
var look_yaw := 0.0
var look_pitch := -0.14
var camera_pivot: Node3D

func _ready() -> void:
	_collision()
	_visual()
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.5
	add_child(camera_pivot)
	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 2.2, 6.5)
	camera_pivot.add_child(camera)

func _collision() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)

func _visual() -> void:
	_box(Vector3(0, 1.22, 0), Vector3(0.65, 0.75, 0.40), Color(0.15, 0.31, 0.51))
	_box(Vector3(-0.44, 1.15, 0), Vector3(0.2, 0.68, 0.24), Color(0.23, 0.33, 0.48))
	_box(Vector3(0.44, 1.15, 0), Vector3(0.2, 0.68, 0.24), Color(0.23, 0.33, 0.48))
	_box(Vector3(-0.19, 0.48, 0), Vector3(0.24, 0.94, 0.28), Color(0.19, 0.24, 0.30))
	_box(Vector3(0.19, 0.48, 0), Vector3(0.24, 0.94, 0.28), Color(0.19, 0.24, 0.30))
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	head.mesh = sphere
	head.position = Vector3(0, 1.82, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.69, 0.49, 0.33)
	head.material_override = mat
	add_child(head)

func _box(pos: Vector3, size: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	instance.material_override = mat
	add_child(instance)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= (3.0 if gliding else 9.8) * delta
		if gliding:
			velocity.y = maxf(-4.2, velocity.y)
	else:
		gliding = false
	var key_axis := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var axis := mobile_direction if mobile_direction.length() > 0.08 else key_axis
	var right := Vector3(cos(look_yaw), 0, -sin(look_yaw))
	var forward := Vector3(sin(look_yaw), 0, cos(look_yaw))
	var direction := (right * axis.x - forward * axis.y).normalized()
	var speed := 8.5 if running else 5.6
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 9.0 * delta)
	camera_pivot.rotation.y = look_yaw - rotation.y
	camera_pivot.rotation.x = look_pitch
	move_and_slide()

func move_mobile(value: Vector2) -> void:
	mobile_direction = value.limit_length(1.0)

func set_running(enabled: bool) -> void:
	running = enabled

func jump() -> void:
	if is_on_floor():
		velocity.y = 5.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			look_yaw -= event.relative.x * 0.006
			look_pitch = clampf(look_pitch - event.relative.y * 0.004, -0.65, 0.25)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look_yaw -= event.relative.x * 0.006
		look_pitch = clampf(look_pitch - event.relative.y * 0.004, -0.65, 0.25)
