extends CharacterBody3D

@export var move_speed := 6.0
@export var run_speed := 9.0
@export var jump_velocity := 5.0
var mobile_direction := Vector2.ZERO
var running := false
var camera_yaw := 0.0
var camera_pitch := -0.22
var camera_pivot: Node3D

func _ready() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.32, 0.82)
	body_mesh.material_override = material
	add_child(body_mesh)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.45
	add_child(camera_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.0, 6.5)
	camera.current = true
	camera_pivot.add_child(camera)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_dir := mobile_direction if mobile_direction.length() > 0.12 else keyboard
	var forward := Vector3(sin(camera_yaw), 0, cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var direction := (right * input_dir.x - forward * input_dir.y).normalized()
	var speed := run_speed if running else move_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	move_and_slide()

func set_mobile_direction(value: Vector2) -> void:
	mobile_direction = value.limit_length(1.0)

func set_running(value: bool) -> void:
	running = value

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
