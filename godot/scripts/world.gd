extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var move_pad
var trees := []
var remote_settings: Dictionary = {}

func _ready() -> void:
    # Primeiro use a última configuração salva: o mundo abre mesmo sem internet.
    var updater = preload("res://scripts/remote_updater.gd").new()
    add_child(updater)
    remote_settings = updater.get_cached_config()
    _build_world()

    # Verifique o GitHub em segundo plano, sem bloquear a exibição do jogo.
    var previous_settings := remote_settings.duplicate(true)
    var latest_settings: Dictionary = await updater.fetch_config()
    var config_updated := latest_settings != previous_settings
    remote_settings = latest_settings

    # O pacote é validado por SHA-256 antes de ser aplicado.
    var pack_updated: bool = await updater.fetch_game_pack()
    if config_updated or pack_updated:
        get_tree().call_deferred("reload_current_scene")

func _build_world() -> void:
    # Ative uma camera antes de criar os objetos; se algum conteudo falhar,
    # o jogador ainda vera o cenario parcial em vez de apenas a cor do ceu.
    _make_environment()
    _make_camera()
    _make_world()
    _make_road_details()
    _add_mansion()
    _make_player()
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

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, with_collision: bool = true) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = _mat(color)
    parent.add_child(n)
    if with_collision:
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
    var width := randf_range(8.0, 12.0)
    var depth := randf_range(8.0, 12.0)
    var facades: Array[Color] = [
        Color("#e7b88c"),
        Color("#d98f83"),
        Color("#9bb9c9"),
        Color("#a9c5a0"),
        Color("#d5b6d9"),
        Color("#e6d69e"),
        Color("#d7d0c4"),
        Color("#91aaa8")
    ]
    var facade: Color = facades[randi_range(0, facades.size() - 1)]
    var window_color := Color("#263f52")
    var trim_color := facade.lightened(0.22)
    var b := _box(self, Vector3(width, h, depth), p + Vector3(0, h / 2.0, 0), facade)
    b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

    # Moldura clara no topo para dar acabamento às fachadas.
    _box(self, Vector3(width + 0.25, 0.28, depth + 0.25), p + Vector3(0, h - 0.12, 0), trim_color, false)

    # Janelas alinhadas na fachada da rua.
    var columns := max(2, int(width / 2.8))
    var rows := max(2, int(h / 2.8))
    for y in range(rows):
        for x in range(columns):
            var wx := -width / 2.0 + (float(x) + 0.5) * width / float(columns)
            var wy := 1.5 + float(y) * 2.35
            if wy < h - 0.8:
                _box(self, Vector3(1.05, 1.15, 0.10), p + Vector3(wx, wy, depth / 2.0 + 0.06), window_color, false)
                _box(self, Vector3(1.05, 1.15, 0.10), p + Vector3(wx, wy, -depth / 2.0 - 0.06), window_color, false)

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
    _box(self, Vector3(3.0, 0.18, 180), Vector3(-8.5, 0.02, 0), sidewalk, false)
    _box(self, Vector3(3.0, 0.18, 180), Vector3(8.5, 0.02, 0), sidewalk, false)
    _box(self, Vector3(180, 0.18, 3.0), Vector3(0, 0.03, -8.5), sidewalk, false)
    _box(self, Vector3(180, 0.18, 3.0), Vector3(0, 0.03, 8.5), sidewalk, false)
    for i in range(-8, 9):
        var offset := float(i) * 10.0
        _box(self, Vector3(0.18, 0.025, 5.0), Vector3(offset, 0.075, 0), paint, false)
        _box(self, Vector3(5.0, 0.025, 0.18), Vector3(0, 0.075, offset), paint, false)
    for side in [-1.0, 1.0]:
        for z in [-24.0, 24.0]:
            _box(self, Vector3(0.16, 5.2, 0.16), Vector3(side * 11.0, 2.6, z), Color(0.12, 0.14, 0.16), false)
            _box(self, Vector3(1.0, 0.18, 0.42), Vector3(side * 11.0, 5.25, z), Color(0.95, 0.82, 0.58), false)

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
    # Use o Midas GLB original do projeto, mantendo o boneco procedural como fallback.
    var midas_scene = load("res://models/midas.glb")
    if midas_scene is PackedScene:
        var midas_model := midas_scene.instantiate()
        midas_model.name = "MidasModel"
        if midas_model is Node3D:
            midas_model.scale = Vector3.ONE
            for old_part in visual.get_children():
                old_part.queue_free()
            visual.add_child(midas_model)
            var animator := _find_animation_player(midas_model)
            if animator:
                var clips := animator.get_animation_list()
                var chosen := ""
                for clip in clips:
                    if "idle" in clip.to_lower():
                        chosen = clip
                        break
                if chosen == "" and not clips.is_empty():
                    chosen = clips[0]
                if chosen != "" and animator.has_animation(chosen):
                    animator.play(chosen)

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
    add_child(camera)
    camera.make_current()

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


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found:
            return found
    return null
