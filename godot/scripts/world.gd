extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var move_pad: VirtualJoystick
var trees := []
var remote_settings: Dictionary = {}

func _ready() -> void:
    var updater = preload("res://scripts/remote_updater.gd").new()
    add_child(updater)
    remote_settings = await updater.fetch_config()
    _make_environment()
    _make_world()
    _make_road_details()
    _add_mansion()
    _make_player()
    _make_camera()
    _make_hud()

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.sky.sky_material = ProceduralSkyMaterial.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.72, 0.78, 0.83)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -30, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = _mat(color)
    parent.add_child(n)
    var body := StaticBody3D.new()
    body.position = pos
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)
    return n

func _make_world() -> void:
    _box(self, Vector3(180, 0.3, 180), Vector3(0, -0.2, 0), Color(0.28, 0.48, 0.22))
    _box(self, Vector3(14, 0.12, 180), Vector3(0, 0, 0), Color(0.16, 0.17, 0.19))
    _box(self, Vector3(180, 0.12, 14), Vector3(0, 0.01, 0), Color(0.16, 0.17, 0.19))
    var radius := int(remote_settings.get("grid_radius", 4))
    var spacing := float(remote_settings.get("block_spacing", 19.0))
    for i in range(-radius, radius + 1):
        if i == 0:
            continue
        _building(Vector3(float(i) * spacing, 0, -22.0))
        _building(Vector3(float(i) * spacing, 0, 25.0))
    for x in range(-radius * 2, radius * 2 + 1):
        for z in [-7, 7]:
            _tree(Vector3(float(x) * 9.0 + 4.0, 0, float(z) * 2.2))
    for z in range(-radius * 2, radius * 2 + 1):
        for x in [-8, 8]:
            _tree(Vector3(float(x) * 2.1, 0, float(z) * 9.0 + 3.0))

func _building(p: Vector3) -> void:
    var h := randf_range(7.0, 15.0)
    var b := _box(self, Vector3(randf_range(8, 12), h, randf_range(8, 12)), p + Vector3(0, h / 2.0, 0), Color(randf_range(0.35,0.65), randf_range(0.35,0.58), randf_range(0.28,0.48)))
    b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for y in range(1, int(h / 2.5)):
        for side in [-1, 1]:
            _box(self, Vector3(1.1, 1.0, 0.12), p + Vector3(side * 2.0, float(y) * 2.4, 5.06), Color(0.08, 0.28, 0.38))

func _tree(p: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var tm := CylinderMesh.new()
    tm.top_radius = 0.22
    tm.bottom_radius = 0.34
    tm.height = 2.0
    trunk.mesh = tm
    trunk.position = p + Vector3(0, 1, 0)
    trunk.material_override = _mat(Color(0.28, 0.16, 0.08))
    add_child(trunk)
    var crown := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = 1.55
    cm.height = 3.4
    crown.mesh = cm
    crown.position = p + Vector3(0, 3.2, 0)
    crown.material_override = _mat(Color(0.06, randf_range(0.28, 0.42), 0.12))
    add_child(crown)

func _make_road_details() -> void:
    var sidewalk := Color(0.56, 0.57, 0.54)
    var paint := Color(0.92, 0.88, 0.68)
    _box(self, Vector3(3.0, 0.18, 180), Vector3(-8.5, 0.02, 0), sidewalk)
    _box(self, Vector3(3.0, 0.18, 180), Vector3(8.5, 0.02, 0), sidewalk)
    _box(self, Vector3(180, 0.18, 3.0), Vector3(0, 0.03, -8.5), sidewalk)
    _box(self, Vector3(180, 0.18, 3.0), Vector3(0, 0.03, 8.5), sidewalk)
    for i in range(-8, 9):
        var offset := float(i) * 10.0
        _box(self, Vector3(0.18, 0.025, 5.0), Vector3(offset, 0.075, 0), paint)
        _box(self, Vector3(5.0, 0.025, 0.18), Vector3(0, 0.075, offset), paint)
    for side in [-1.0, 1.0]:
        for z in [-24.0, 24.0]:
            _box(self, Vector3(0.16, 5.2, 0.16), Vector3(side * 11.0, 2.6, z), Color(0.12, 0.14, 0.16))
            _box(self, Vector3(1.0, 0.18, 0.42), Vector3(side * 11.0, 5.25, z), Color(0.95, 0.82, 0.58))

func _character_piece(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos
    part.material_override = _mat(color)
    parent.add_child(part)
    return part

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1, 0)
    var visual := Node3D.new()
    visual.name = "CharacterVisual"
    player.add_child(visual)
    var skin := Color(0.66, 0.43, 0.29)
    var shirt := Color(0.10, 0.28, 0.58)
    var pants := Color(0.09, 0.12, 0.18)
    var shoes := Color(0.045, 0.05, 0.06)
    var torso := BoxMesh.new()
    torso.size = Vector3(0.78, 0.82, 0.42)
    _character_piece(visual, torso, Vector3(0, 0.95, 0), shirt)
    var head := SphereMesh.new()
    head.radius = 0.25
    head.height = 0.5
    _character_piece(visual, head, Vector3(0, 1.58, 0), skin)
    var hair := SphereMesh.new()
    hair.radius = 0.255
    hair.height = 0.22
    _character_piece(visual, hair, Vector3(0, 1.76, 0), Color(0.08, 0.055, 0.04))
    for side in [-1.0, 1.0]:
        var arm := CapsuleMesh.new()
        arm.radius = 0.12
        arm.height = 0.72
        var arm_node := _character_piece(visual, arm, Vector3(side * 0.51, 0.98, 0), skin)
        arm_node.rotation_degrees.z = side * -10.0
        var leg := CapsuleMesh.new()
        leg.radius = 0.15
        leg.height = 0.78
        _character_piece(visual, leg, Vector3(side * 0.20, 0.38, 0), pants)
        var shoe := BoxMesh.new()
        shoe.size = Vector3(0.30, 0.16, 0.42)
        _character_piece(visual, shoe, Vector3(side * 0.20, 0.08, -0.08), shoes)
    var shape := CollisionShape3D.new()
    var cs := CapsuleShape3D.new()
    cs.radius = 0.38
    cs.height = 1.8
    shape.shape = cs
    player.add_child(shape)
    player.set_script(PLAYER_SCRIPT)
    add_child(player)

func _make_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 7, 11)
    camera.rotation_degrees = Vector3(-22, 0, 0)
    camera.current = true
    add_child(camera)

func _process(delta: float) -> void:
    if player and camera:
        var camera_height := float(remote_settings.get("camera_height", 6.5))
        var camera_distance := float(remote_settings.get("camera_distance", 10.5))
        var target := player.global_position + Vector3(0, camera_height, camera_distance)
        camera.global_position = camera.global_position.lerp(target, min(delta * 5.0, 1.0))
        camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _make_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var title := Label.new()
    title.text = "OPEN WORLD BR  •  3D NATIVO"
    title.position = Vector2(22, 18)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color.WHITE)
    hud.add_child(title)
    var help := Label.new()
    help.text = "Use o analógico para andar"
    help.position = Vector2(22, 52)
    help.add_theme_font_size_override("font_size", 16)
    help.add_theme_color_override("font_color", Color.WHITE)
    hud.add_child(help)
    move_pad = VirtualJoystick.new()
    move_pad.position = Vector2(30, 480)
    hud.add_child(move_pad)

class VirtualJoystick:
    extends Control
    var vector := Vector2.ZERO
    var finger := -1
    func _ready() -> void:
        custom_minimum_size = Vector2(170, 170)
        queue_redraw()
    func _gui_input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            if event.pressed:
                finger = event.index
                _update_value(event.position)
            elif event.index == finger:
                finger = -1
                vector = Vector2.ZERO
                queue_redraw()
        elif event is InputEventScreenDrag and event.index == finger:
            _update_value(event.position)
    func _update_value(p: Vector2) -> void:
        vector = ((p - size / 2.0) / 65.0).limit_length(1.0)
        queue_redraw()
    func _draw() -> void:
        draw_circle(size / 2.0, 72.0, Color(0.05,0.08,0.12,0.35))
        draw_circle(size / 2.0 + vector * 48.0, 27.0, Color(0.8,0.9,1.0,0.85))

func _add_mansion() -> void:
    var mansion_scene := load("res://scenes/mansion.tscn")
    if mansion_scene:
        add_child(mansion_scene.instantiate())
