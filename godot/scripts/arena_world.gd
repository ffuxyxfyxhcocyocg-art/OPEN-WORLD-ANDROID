extends Node3D

# Android procedural island: original geometry, not the CoD4 Blackout BSP map.
# Designed to run in Godot 4 Compatibility renderer without external textures.
const ISLAND_RADIUS := 128.0
const TREE_COUNT := 128

func _ready() -> void:
	_create_land()
	_create_districts()
	_create_vegetation()
	_create_landmarks()
	_create_atmosphere()

func _create_land() -> void:
	_make_box(Vector3(0, -2.0, 0), Vector3(450, 1.0, 450), Color(0.07, 0.30, 0.52), false, "Ocean")
	_make_cylinder(Vector3(0, -0.48, 0), 140.0, Color(0.81, 0.72, 0.46), "SandyCoast")
	_make_cylinder(Vector3(0, -0.18, 0), ISLAND_RADIUS, Color(0.25, 0.45, 0.27), "IslandBase")
	# Flat collision surface independent of textured environment.
	_make_box(Vector3(0, -0.55, 0), Vector3(257, 1.1, 257), Color(0.26, 0.46, 0.28), true, "GrassGround")
	# Start apron is kept clear for the opening parachute sequence.
	_make_box(Vector3(0, 0.018, 0), Vector3(18, 0.04, 18), Color(0.35, 0.53, 0.35), false, "ArrivalField")
	_apply_procedural_surface("Ocean", Color(0.07, 0.34, 0.57), true)
	_apply_procedural_surface("GrassGround", Color(0.25, 0.48, 0.25), false)
	_apply_procedural_surface("SandyCoast", Color(0.82, 0.72, 0.51), false)

func _create_districts() -> void:
	var road_color := Color(0.14, 0.17, 0.20)
	var lane_color := Color(0.94, 0.78, 0.37)
	for i in range(-2, 3):
		var offset: float = i * 42.0
		_make_box(Vector3(offset, 0.05, 0), Vector3(7.7, 0.09, 248), road_color, false, "AvenueNS")
		_make_box(Vector3(0, 0.05, offset), Vector3(248, 0.09, 7.7), road_color, false, "AvenueEW")
		for marker in range(-5, 6):
			var mark: float = marker * 19.0
			_make_box(Vector3(offset, 0.112, mark), Vector3(0.22, 0.015, 7.0), lane_color, false, "RoadMark")
			_make_box(Vector3(mark, 0.112, offset), Vector3(7.0, 0.015, 0.22), lane_color, false, "RoadMark")
	var palette := [
		Color(0.69, 0.71, 0.67), Color(0.74, 0.65, 0.52),
		Color(0.56, 0.66, 0.69), Color(0.81, 0.72, 0.56), Color(0.59, 0.64, 0.58)
	]
	for x in range(-3, 3):
		for z in range(-3, 3):
			var xx: float = float(x) * 42.0 + 21.0
			var zz: float = float(z) * 42.0 + 21.0
			if Vector2(xx, zz).length() > 106.0:
				continue
			if absf(xx) < 22.0 and absf(zz) < 22.0:
				continue
			var index: int = absi(x * 7 + z * 11)
			var height: float = 5.0 + float(index % 6) * 2.5
			var color: Color = palette[index % palette.size()]
			_make_box(Vector3(xx, height * 0.5, zz), Vector3(12.0, height, 12.0), color, true, "Block_%d_%d" % [x, z])
			_make_box(Vector3(xx, height + 0.15, zz), Vector3(13.2, 0.3, 13.2), Color(0.23, 0.30, 0.35), false, "Roof")
			for floor_idx in range(1, maxi(2, int(height / 3.0))):
				var y: float = float(floor_idx) * 2.6
				for col in [-3.3, 0.0, 3.3]:
					_make_box(Vector3(xx + col, y, zz + 6.04), Vector3(1.65, 1.5, 0.12), Color(0.24, 0.48, 0.56), false, "Window")
					_make_box(Vector3(xx + col, y, zz - 6.04), Vector3(1.65, 1.5, 0.12), Color(0.24, 0.48, 0.56), false, "Window")

func _create_vegetation() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 1.0
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 1.0
	leaf_mesh.height = 2.0
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 5
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = TREE_COUNT
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = leaf_mesh
	crowns.instance_count = TREE_COUNT
	var rand := RandomNumberGenerator.new()
	rand.seed = 41982026
	for i in range(TREE_COUNT):
		var point := Vector2.ZERO
		for _attempt in range(40):
			point = Vector2(rand.randf_range(-121, 121), rand.randf_range(-121, 121))
			var away_from_road: bool = true
			for line in [-84.0, -42.0, 0.0, 42.0, 84.0]:
				if absf(point.x - line) < 9.0 or absf(point.y - line) < 9.0:
					away_from_road = false
			if point.length() < 119.0 and away_from_road:
				break
		var tree_height: float = rand.randf_range(3.2, 6.8)
		var location := Vector3(point.x, 0, point.y)
		trunks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, tree_height, 1)), location + Vector3(0, tree_height * 0.5, 0)))
		crowns.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(rand.randf_range(1.5, 2.2), rand.randf_range(1.4, 2.2), 1.8)), location + Vector3(0, tree_height + 1.2, 0)))
	var trunk_node := MultiMeshInstance3D.new()
	trunk_node.multimesh = trunks
	trunk_node.material_override = _material(Color(0.38, 0.23, 0.14))
	add_child(trunk_node)
	var crown_node := MultiMeshInstance3D.new()
	crown_node.multimesh = crowns
	crown_node.material_override = _material(Color(0.12, 0.37, 0.23))
	add_child(crown_node)

func _create_landmarks() -> void:
	# Visual landmarks and stronger material silhouettes for map navigation.
	_make_box(Vector3(0, 0.2, -79), Vector3(25, 0.35, 25), Color(0.72, 0.69, 0.57), false, "Helipad")
	_make_cylinder(Vector3(0, 14, -79), 2.7, Color(0.84, 0.87, 0.90), "Lighthouse")
	_make_box(Vector3(0, 29, -79), Vector3(7, 1.0, 7), Color(0.18, 0.32, 0.39), false, "LighthouseCap")
	_make_box(Vector3(-91, 5.0, 21), Vector3(14, 10, 10), Color(0.42, 0.37, 0.33), true, "CliffDepot")
	_make_box(Vector3(67, 5.0, -56), Vector3(18, 10, 15), Color(0.57, 0.60, 0.62), true, "HarborWarehouse")
	for i in range(8):
		var bx: float = -85.0 + float(i) * 4.0
		_make_box(Vector3(bx, 0.25, 103), Vector3(2.7, 0.5, 7), Color(0.56, 0.35, 0.20), false, "DockTimber")

func _create_atmosphere() -> void:
	var haze := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.75, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.77, 0.83, 0.91)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	haze.environment = env
	add_child(haze)

func _make_cylinder(position: Vector3, radius: float, color: Color, name: String) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.45 if name != "Lighthouse" else 28.0
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	node.name = name
	add_child(node)

func _make_box(position: Vector3, size: Vector3, color: Color, solid: bool, name: String) -> void:
	var node: Node3D
	if solid:
		node = StaticBody3D.new()
	else:
		node = Node3D.new()
	node.name = name
	node.position = position
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var col_shape := BoxShape3D.new()
		col_shape.size = size
		collision.shape = col_shape
		node.add_child(collision)
	add_child(node)

# Compact animated water and procedural color variation authored for Godot.
# No borrowed CoD4 textures or other proprietary files.
func _apply_procedural_surface(node_name: String, color: Color, is_water: bool) -> void:
	var scene_node := get_node_or_null(node_name)
	if scene_node == null or scene_node.get_child_count() == 0:
		return
	var surface := scene_node.get_child(0) as MeshInstance3D
	if surface == null:
		return
	var shader := Shader.new()
	if is_water:
		shader.code = """
shader_type spatial;
render_mode unshaded;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float ripple = sin(world_pos.x * 0.22 + TIME * 0.8) * sin(world_pos.z * 0.27 + TIME * 0.65);
	float glint = smoothstep(0.69, 0.98, ripple);
	ALBEDO = mix(vec3(0.04, 0.21, 0.42), vec3(0.15, 0.45, 0.65), ripple * 0.27 + 0.31) + vec3(0.1) * glint;
	ROUGHNESS = 0.46;
}
"""
	else:
		shader.code = """
shader_type spatial;
uniform vec4 tint : source_color = vec4(0.5, 0.6, 0.4, 1.0);
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 cell = floor(world_pos.xz * 1.8);
	float speckle = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = tint.rgb * (0.91 + 0.18 * speckle);
	ROUGHNESS = 0.93;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	if not is_water:
		material.set_shader_parameter("tint", color)
	surface.material_override = material

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.89
	return material
