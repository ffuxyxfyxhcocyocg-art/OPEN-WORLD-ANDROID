extends Node3D

# New Android map generated from Godot shapes. No meshes or textures from CoD4.
const HALF := 125.0

func _ready() -> void:
	var sky := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = Sky.new()
	settings.sky.sky_material = ProceduralSkyMaterial.new()
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.72, 0.80, 0.88)
	settings.ambient_light_energy = 0.85
	sky.environment = settings
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.35
	add_child(sun)
	_box(Vector3(0, -2.2, 0), Vector3(360, 0.6, 360), Color(0.09, 0.30, 0.48), false, "Ocean")
	_box(Vector3(0, -0.9, 0), Vector3(255, 0.9, 255), Color(0.82, 0.74, 0.51), false, "Beach")
	_box(Vector3(0, -0.5, 0), Vector3(245, 1.0, 245), Color(0.24, 0.43, 0.26), true, "Island")
	for i in range(-2, 3):
		var line := float(i) * 42.0
		_box(Vector3(line, 0.055, 0), Vector3(7.5, 0.1, 242), Color(0.15, 0.16, 0.18), false, "StreetNS")
		_box(Vector3(0, 0.055, line), Vector3(242, 0.1, 7.5), Color(0.15, 0.16, 0.18), false, "StreetEW")
	for x in range(-3, 3):
		for z in range(-3, 3):
			var px := x * 42.0 + 21.0
			var pz := z * 42.0 + 21.0
			if Vector2(px, pz).length() > 105.0 or (absf(px) < 24.0 and absf(pz) < 24.0):
				continue
			var height := 7.0 + float((absi(x * 3 + z * 7)) % 5) * 2.8
			var tone := Color(0.44 + float(absi(x) % 3) * 0.07, 0.50, 0.51 + float(absi(z) % 3) * 0.05)
			_box(Vector3(px, height * 0.5, pz), Vector3(12.5, height, 12.5), tone, true, "Building")
			_box(Vector3(px, height + 0.16, pz), Vector3(13.5, 0.32, 13.5), Color(0.19, 0.27, 0.31), false, "Roof")
			for f in range(1, int(height / 3.0)):
				for window_x in [-3.6, 0.0, 3.6]:
					_box(Vector3(px + window_x, f * 2.7, pz + 6.34), Vector3(1.55, 1.5, 0.11), Color(0.20, 0.43, 0.54), false, "Window")
	var randomizer := RandomNumberGenerator.new()
	randomizer.seed = 970126
	for i in range(90):
		var xy := Vector2.ZERO
		for attempt in range(80):
			xy = Vector2(randomizer.randf_range(-115, 115), randomizer.randf_range(-115, 115))
			if xy.length() > 115.0:
				continue
			if _near_street(xy.x) or _near_street(xy.y):
				continue
			break
		var h := randomizer.randf_range(3.1, 6.1)
		_cylinder(Vector3(xy.x, h * 0.5, xy.y), 0.29, h, Color(0.40, 0.25, 0.15), "Tree")
		_sphere(Vector3(xy.x, h + 0.6, xy.y), randomizer.randf_range(1.4, 2.2), Color(0.14, 0.36, 0.21), "Leaves")
	_box(Vector3(-73, 7, -71), Vector3(16, 14, 19), Color(0.61, 0.57, 0.51), true, "Outpost")
	_box(Vector3(67, 6, 68), Vector3(19, 12, 16), Color(0.48, 0.52, 0.56), true, "Depot")
	_cylinder(Vector3(7, 11, -101), 2.2, 22, Color(0.90, 0.87, 0.75), "Lighthouse")
	_box(Vector3(7, 22.5, -101), Vector3(6, 2, 6), Color(0.28, 0.36, 0.43), false, "LanternRoom")

func _near_street(value: float) -> bool:
	for i in range(-2, 3):
		if absf(value - i * 42.0) < 8.0:
			return true
	return false

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool, label: String) -> void:
	var container: Node3D
	if solid:
		container = StaticBody3D.new()
	else:
		container = Node3D.new()
	container.name = label
	container.position = pos
	var shape := BoxMesh.new()
	shape.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = _material(color)
	container.add_child(visual)
	if solid:
		var collider := CollisionShape3D.new()
		var form := BoxShape3D.new()
		form.size = size
		collider.shape = form
		container.add_child(collider)
	add_child(container)

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, label: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.position = pos
	add_child(visual)

func _sphere(pos: Vector3, radius: float, color: Color, label: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = pos
	visual.material_override = _material(color)
	add_child(visual)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
