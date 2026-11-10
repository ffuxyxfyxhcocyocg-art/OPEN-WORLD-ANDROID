extends Node

# ENet local-network play, no hosted internet backend or matchmaking.
const PORT := 28015
var actor: CharacterBody3D
var battle: Node3D
var remote_players: Dictionary = {}
var last_positions: Dictionary = {}
var update_clock := 0.0
var status: Label
var address: LineEdit
var panel: PanelContainer

func setup(character: CharacterBody3D, manager: Node3D) -> void:
	actor = character
	battle = manager

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): status.text = "Conectado à sala LAN")
	multiplayer.connection_failed.connect(func(): status.text = "Falha na conexão LAN")
	multiplayer.server_disconnected.connect(func(): _disconnect())
	multiplayer.peer_disconnected.connect(_remove_remote)
	_build_ui()

func _process(delta: float) -> void:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	update_clock += delta
	if update_clock < 0.12:
		return
	update_clock = 0.0
	if multiplayer.is_server():
		last_positions[1] = actor.global_position
		receive_pose.rpc(1, actor.global_position, actor.rotation.y)
	else:
		send_pose.rpc_id(1, actor.global_position, actor.rotation.y)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "LANControls"
	add_child(ui)
	var show := Button.new()
	show.text = "SALA LAN"
	show.position = Vector2(16, 127)
	show.custom_minimum_size = Vector2(125, 45)
	ui.add_child(show)
	panel = PanelContainer.new()
	panel.position = Vector2(15, 185)
	panel.custom_minimum_size = Vector2(320, 0)
	ui.add_child(panel)
	panel.visible = false
	var column := VBoxContainer.new()
	panel.add_child(column)
	address = LineEdit.new()
	address.placeholder_text = "IP local do anfitrião"
	column.add_child(address)
	var host := Button.new()
	host.text = "CRIAR SALA"
	column.add_child(host)
	var join := Button.new()
	join.text = "ENTRAR POR IP"
	column.add_child(join)
	var leave := Button.new()
	leave.text = "SAIR DA SALA"
	column.add_child(leave)
	status = Label.new()
	status.text = "LAN · mesma rede Wi-Fi"
	column.add_child(status)
	show.pressed.connect(func(): panel.visible = not panel.visible)
	host.pressed.connect(_host)
	join.pressed.connect(_join)
	leave.pressed.connect(_disconnect)

func _host() -> void:
	_disconnect()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(PORT, 8)
	if result != OK:
		status.text = "Erro ao criar sala: " + str(result)
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Sala aberta · porta 28015"

func _join() -> void:
	var ip := address.text.strip_edges()
	if ip.is_empty():
		status.text = "Digite o IP do anfitrião"
		return
	_disconnect()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, PORT)
	if result != OK:
		status.text = "Não conectou: " + str(result)
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Conectando..."

func _disconnect() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for value in remote_players.values():
		if is_instance_valid(value):
			value.queue_free()
	remote_players.clear()
	last_positions.clear()
	if status != null:
		status.text = "LAN · desconectado"

func _remove_remote(id: int) -> void:
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)
	last_positions.erase(id)

@rpc("any_peer", "call_remote", "unreliable")
func send_pose(pos: Vector3, facing: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	last_positions[sender] = pos
	_render_remote(sender, pos, facing)
	receive_pose.rpc(sender, pos, facing)

@rpc("authority", "call_remote", "unreliable")
func receive_pose(id: int, pos: Vector3, facing: float) -> void:
	if multiplayer.get_unique_id() == id:
		return
	last_positions[id] = pos
	_render_remote(id, pos, facing)

func _render_remote(id: int, pos: Vector3, facing: float) -> void:
	if not remote_players.has(id):
		var body := StaticBody3D.new()
		body.name = "Remote_%d" % id
		body.set_meta("remote_peer", id)
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.43
		shape.height = 1.8
		collision.shape = shape
		collision.position.y = 0.9
		body.add_child(collision)
		var avatar := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.43
		mesh.height = 1.8
		avatar.mesh = mesh
		avatar.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.96, 0.62, 0.29)
		avatar.material_override = mat
		body.add_child(avatar)
		battle.add_child(body)
		remote_players[id] = body
	var remote: StaticBody3D = remote_players[id]
	remote.global_position = remote.global_position.lerp(pos, 0.7)
	remote.rotation.y = facing

func report_hit(victim: int, damage: float) -> void:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	if multiplayer.is_server():
		_validate_hit(1, victim, damage)
	else:
		propose_hit.rpc_id(1, victim, damage)

@rpc("any_peer", "call_remote", "reliable")
func propose_hit(victim: int, damage: float) -> void:
	if multiplayer.is_server():
		_validate_hit(multiplayer.get_remote_sender_id(), victim, damage)

func _validate_hit(attacker: int, victim: int, damage: float) -> void:
	if attacker == victim or damage <= 0 or damage > 25:
		return
	var from: Vector3 = actor.global_position if attacker == 1 else last_positions.get(attacker, Vector3(9999, 0, 9999))
	var to: Vector3 = actor.global_position if victim == 1 else last_positions.get(victim, Vector3(-9999, 0, -9999))
	if from.distance_to(to) > 95:
		return
	if victim == 1:
		battle.take_damage(damage)
	else:
		damaged.rpc_id(victim, damage)

@rpc("authority", "call_remote", "reliable")
func damaged(damage: float) -> void:
	battle.take_damage(clampf(damage, 0, 25))
