extends CharacterBody3D

@export var move_speed := 6.0
@export var run_speed := 9.0
@export var jump_velocity := 5.0
var mobile_direction := Vector2.ZERO
var running := false
var parachuting := false
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
	# Use the Midas GLB bundled at build time; preserve its imported orientation.
	# Never rotate it blindly: the source node already has a -90 degree transform.
	_try_load_character_model(body_mesh)

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
		velocity.y -= (2.5 if parachuting else 9.8) * delta
		if parachuting:
			velocity.y = maxf(velocity.y, -4.5)
	else:
		if parachuting:
			parachuting = false
		if Input.is_action_just_pressed("ui_accept"):
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
	camera_pivot.rotation.y = camera_yaw - rotation.y
	camera_pivot.rotation.x = camera_pitch
	move_and_slide()

func set_mobile_direction(value: Vector2) -> void:
	mobile_direction = value.limit_length(1.0)

func set_running(value: bool) -> void:
	running = value

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var screen_width := get_viewport().get_visible_rect().size.x
		if event.position.x > screen_width * 0.44:
			camera_yaw -= event.relative.x * 0.006
			camera_pitch = clampf(camera_pitch - event.relative.y * 0.004, -0.65, 0.20)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.004, -0.65, 0.20)

func _try_load_character_model(fallback_mesh: MeshInstance3D) -> void:
	var asset_path := "res://models/midas.glb"
	if not ResourceLoader.exists(asset_path):
		return
	var asset := load(asset_path)
	if not (asset is PackedScene):
		return
	var visual := (asset as PackedScene).instantiate() as Node3D
	if visual == null:
		return
	visual.name = "Midas3D"
	add_child(visual)
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.force_update_transform()
	var mesh_nodes := visual.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		visual.queue_free()
		return
	var all_bounds := AABB()
	var first_mesh := true
	var visual_inverse := visual.global_transform.affine_inverse()
	for item in mesh_nodes:
		var part := item as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		var local_bounds := (visual_inverse * part.global_transform) * part.get_aabb()
		if first_mesh:
			all_bounds = local_bounds
			first_mesh = false
		else:
			all_bounds = all_bounds.merge(local_bounds)
	if first_mesh or all_bounds.size.y < 0.05 or all_bounds.size.y > 100000.0:
		visual.queue_free()
		return
	var factor := 1.8 / all_bounds.size.y
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(
		-all_bounds.get_center().x * factor,
		-all_bounds.position.y * factor,
		-all_bounds.get_center().z * factor
	)
	fallback_mesh.visible = false
