extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var move_pad: VirtualJoystick
var trees := []

func _ready() -> void:
    _make_environment()
    _make_world()
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
    return n

func _make_world() -> void:
    _box(self, Vector3(180, 0.3, 180), Vector3(0, -0.2, 0), Color(0.28, 0.48, 0.22))
    _box(self, Vector3(14, 0.12, 180), Vector3(0, 0, 0), Color(0.16, 0.17, 0.19))
    _box(self, Vector3(180, 0.12, 14), Vector3(0, 0.01, 0), Color(0.16, 0.17, 0.19))
    for i in range(-4, 5):
        if i == 0:
            continue
        _building(Vector3(float(i) * 19.0, 0, -22.0))
        _building(Vector3(float(i) * 19.0, 0, 25.0))
    for x in range(-8, 9):
        for z in [-7, 7]:
            _tree(Vector3(float(x) * 9.0 + 4.0, 0, float(z) * 2.2))
    for z in range(-8, 9):
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

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1, 0)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.48
    capsule.height = 1.8
    body.mesh = capsule
    body.material_override = _mat(Color(0.08, 0.16, 0.22))
    player.add_child(body)
    var shape := CollisionShape3D.new()
    var cs := CapsuleShape3D.new()
    cs.radius = 0.48
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
        var target := player.global_position + Vector3(0, 6.5, 10.5)
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
