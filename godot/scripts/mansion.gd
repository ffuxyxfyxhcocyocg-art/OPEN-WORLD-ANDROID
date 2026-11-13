extends Node3D

# Mansao exploravel: estrutura modular com colisoes e ambientes internos.
const WALL := Color(0.88, 0.86, 0.80)
const WHITE := Color(0.94, 0.93, 0.89)
const GLASS := Color(0.22, 0.55, 0.68, 0.48)
const DARK := Color(0.10, 0.12, 0.14)
const WOOD := Color(0.38, 0.22, 0.12)
const STONE := Color(0.48, 0.48, 0.45)

func _ready() -> void:
    _build_house()
    _build_garden()

func _material(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    if color.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := true) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    mesh_node.material_override = _material(color, 0.42 if color == GLASS else 0.78)
    parent.add_child(mesh_node)
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        parent.add_child(body)
    return mesh_node

func _build_house() -> void:
    # Terreno da mansao; frente voltada para Z negativo.
    var house := Node3D.new()
    house.name = "Mansao_Exploravel"
    house.position = Vector3(38, 0, -38)
    add_child(house)

    # Piso principal e teto/terraço.
    _box(house, Vector3(22, 0.35, 16), Vector3(0, 0.0, 0), Color(0.72,0.70,0.65))
    _box(house, Vector3(22, 0.28, 16), Vector3(0, 3.25, 0), WHITE, false)
    _box(house, Vector3(15, 0.30, 11), Vector3(1.0, 3.45, 0.5), Color(0.70,0.69,0.66))
    # Fachada frontal segmentada para manter entrada e janelas abertas.
    _box(house, Vector3(5.0, 3.0, 0.35), Vector3(-8.5, 1.65, -7.8), WALL)
    _box(house, Vector3(5.0, 3.0, 0.35), Vector3(8.5, 1.65, -7.8), WALL)
    _box(house, Vector3(5.0, 0.45, 0.35), Vector3(0, 2.95, -7.8), WHITE)
    _box(house, Vector3(22, 3.0, 0.35), Vector3(0, 1.65, 7.8), WALL)
    _box(house, Vector3(0.35, 3.0, 16), Vector3(-10.8, 1.65, 0), WALL)
    _box(house, Vector3(0.35, 3.0, 16), Vector3(10.8, 1.65, 0), WALL)

    # Divisorias internas deixando passagem central.
    _box(house, Vector3(0.22, 3.0, 4.4), Vector3(-3.0, 1.65, 5.5), WHITE)
    _box(house, Vector3(0.22, 3.0, 4.4), Vector3(-3.0, 1.65, -5.5), WHITE)
    _box(house, Vector3(5.6, 3.0, 0.22), Vector3(7.9, 1.65, 1.7), WHITE)
    _box(house, Vector3(5.6, 3.0, 0.22), Vector3(7.9, 1.65, -4.8), WHITE)

    # Janelas panoramicas de vidro e caixilhos escuros.
    for x in [-6.0, -1.0, 4.0, 9.0]:
        _box(house, Vector3(3.3, 2.0, 0.10), Vector3(x, 1.75, -7.55), GLASS, false)
        _box(house, Vector3(3.45, 0.12, 0.18), Vector3(x, 2.78, -7.48), DARK, false)
        _box(house, Vector3(0.10, 2.1, 0.18), Vector3(x-1.65, 1.75, -7.48), DARK, false)
        _box(house, Vector3(0.10, 2.1, 0.18), Vector3(x+1.65, 1.75, -7.48), DARK, false)

    # Segundo pavimento recuado, varanda e guarda-corpo.
    _box(house, Vector3(14, 0.30, 10), Vector3(1.0, 3.65, 0.5), Color(0.80,0.78,0.73))
    _box(house, Vector3(14, 2.8, 0.30), Vector3(1.0, 5.1, 5.35), WALL)
    _box(house, Vector3(0.30, 2.8, 10), Vector3(-5.9, 5.1, 0.5), WALL)
    _box(house, Vector3(0.30, 2.8, 10), Vector3(7.9, 5.1, 0.5), WALL)
    _box(house, Vector3(13.4, 0.18, 0.18), Vector3(1.0, 4.55, -4.5), DARK, false)
    _box(house, Vector3(0.18, 1.1, 0.18), Vector3(-5.6, 4.05, -4.5), DARK, false)
    _box(house, Vector3(0.18, 1.1, 0.18), Vector3(7.6, 4.05, -4.5), DARK, false)
    _box(house, Vector3(14.5, 0.25, 10.5), Vector3(1.0, 6.55, 0.5), Color(0.24,0.25,0.27), false)

    # Escada exterior/interior simples para subir ao segundo piso.
    for i in range(9):
        _box(house, Vector3(2.2, 0.22, 0.72), Vector3(-7.0, 0.18 + i*0.34, 4.5 - i*0.72), STONE)

    # Sala: sofa, mesa e painel de TV.
    _box(house, Vector3(4.4, 0.75, 1.35), Vector3(3.0, 0.62, 2.0), Color(0.58,0.53,0.47), false)
    _box(house, Vector3(1.25, 0.32, 1.0), Vector3(3.0, 1.15, 2.0), Color(0.68,0.63,0.57), false)
    _box(house, Vector3(2.4, 0.18, 1.3), Vector3(3.0, 0.48, -0.1), WOOD, false)
    _box(house, Vector3(0.18, 1.5, 2.8), Vector3(10.2, 1.0, 0.0), DARK, false)
    _box(house, Vector3(0.12, 1.05, 1.9), Vector3(10.05, 1.25, 0.0), Color(0.025,0.04,0.06), false)

    # Cozinha com bancada e ilha.
    _box(house, Vector3(5.0, 0.95, 0.85), Vector3(-7.0, 0.62, 1.0), Color(0.76,0.75,0.71), false)
    _box(house, Vector3(5.0, 0.12, 0.95), Vector3(-7.0, 1.16, 1.0), STONE, false)
    _box(house, Vector3(2.7, 0.95, 1.0), Vector3(-6.2, 0.62, -2.0), WHITE, false)
    _box(house, Vector3(2.9, 0.12, 1.1), Vector3(-6.2, 1.16, -2.0), Color(0.20,0.20,0.19), false)

    # Quarto e banheiro no lado direito.
    _box(house, Vector3(3.5, 0.45, 2.5), Vector3(7.2, 0.55, 5.4), WHITE, false)
    _box(house, Vector3(3.6, 0.25, 2.6), Vector3(7.2, 0.88, 5.4), Color(0.52,0.57,0.64), false)
    _box(house, Vector3(1.3, 0.55, 0.7), Vector3(9.2, 0.32, 5.2), WHITE, false)
    _box(house, Vector3(2.0, 0.95, 0.15), Vector3(5.0, 0.75, 6.9), Color(0.72,0.73,0.74), false)

    # Garagem anexa aberta, com pilares e cobertura.
    _box(house, Vector3(8.0, 0.25, 7.5), Vector3(15.2, 3.0, -1.0), Color(0.26,0.27,0.29), false)
    for x in [11.5, 18.8]:
        for z in [-4.2, 2.2]:
            _box(house, Vector3(0.35, 3.0, 0.35), Vector3(x, 1.5, z), WHITE)
    _box(house, Vector3(7.5, 0.12, 0.8), Vector3(15.2, 0.18, -5.2), Color(0.45,0.44,0.42), false)

func _build_garden() -> void:
    var garden := Node3D.new()
    garden.name = "Jardim_Piscina_Garagem"
    garden.position = Vector3(38, 0, -38)
    add_child(garden)
    # Deck e piscina na frente da mansao.
    _box(garden, Vector3(28, 0.18, 10), Vector3(2, 0.04, -14), Color(0.68,0.57,0.43), false)
    _box(garden, Vector3(11, 0.30, 5.5), Vector3(-1, -0.10, -14), Color(0.10,0.48,0.68), false)
    _box(garden, Vector3(11.4, 0.20, 0.22), Vector3(-1, 0.02, -16.8), WHITE, false)
    _box(garden, Vector3(11.4, 0.20, 0.22), Vector3(-1, 0.02, -11.2), WHITE, false)
    # Caminho, gramado, arbustos e palmeiras.
    _box(garden, Vector3(5.0, 0.12, 11), Vector3(0, 0.06, -9.0), Color(0.55,0.54,0.50), false)
    for x in [-12.0, 12.0, -16.0, 16.0]:
        _box(garden, Vector3(1.0, 0.7, 1.0), Vector3(x, 0.4, -12.0), Color(0.12,0.35,0.13), false)
    # Carro decorativo simples na garagem.
    _box(garden, Vector3(4.4, 0.75, 2.0), Vector3(15.0, 0.62, -0.5), Color(0.12,0.18,0.24), false)
    _box(garden, Vector3(2.4, 0.65, 1.65), Vector3(15.0, 1.25, -0.5), Color(0.20,0.42,0.58), false)
    for x in [13.5,16.5]:
        for z in [-1.5,0.5]:
            var wheel := _box(garden, Vector3(0.35,0.55,0.35), Vector3(x,0.45,z), DARK, false)
            wheel.rotation_degrees.z = 90
