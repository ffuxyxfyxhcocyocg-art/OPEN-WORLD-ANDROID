extends Node3D

# Android Godot ENet LAN multiplayer proof of concept.
# Real player position sync and host-mediated arcade damage; NOT an internet service.
const PORT := 28015
const MAX_PLAYERS := 8

var player: CharacterBody3D
var battle: Node3D
var network_panel: PanelContainer
var status_label: Label
var room_address: LineEdit
var open_button: Button
var remote_actors: Dictionary = {}
var remote_positions: Dictionary = {}
var send_timer := 0.0

func setup(local_player: CharacterBody3D, battle_system: Node3D) -> void:
	player = local_player
	battle = battle_system

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	_build_network_ui()

func _process(delta: float) -> void:
	if not _online() or player == null:
		return
	send_timer += delta
	if send_timer < 0.1:
		return
	send_timer = 0.0
	if multiplayer.is_server():
		remote_positions[1] = player.global_position
		sync_pose.rpc(1, player.global_position, player.rotation.y)
	else:
		submit_pose.rpc_id(1, player.global_position, player.rotation.y)

func _online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer

func _build_network_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MultiplayerHUD"
	add_child(layer)
	open_button = Button.new()
	open_button.text = "ONLINE LAN"
	open_button.position = Vector2(16, 255)
	open_button.custom_minimum_size = Vector2(135, 46)
	layer.add_child(open_button)
	network_panel = PanelContainer.new()
	network_panel.position = Vector2(16, 309)
	network_panel.custom_minimum_size = Vector2(310, 0)
	network_panel.visible = false
	layer.add_child(network_panel)
	var content := VBoxContainer.new()
	network_panel.add_child(content)
	var heading := Label.new()
	heading.text = "SALA MULTIPLAYER · REDE LOCAL"
	content.add_child(heading)
	room_address = LineEdit.new()
	room_address.placeholder_text = "IP do anfitrião: 192.168.x.x"
	content.add_child(room_address)
	var host_button := Button.new()
	host_button.text = "CRIAR SALA (até 8)"
	content.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "ENTRAR NA SALA"
	content.add_child(join_button)
	var leave_button := Button.new()
	leave_button.text = "DESCONECTAR"
	content.add_child(leave_button)
	status_label = Label.new()
	status_label.text = "Offline · jogadores na mesma rede Wi-Fi"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	open_button.pressed.connect(func(): network_panel.visible = not network_panel.visible)
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	leave_button.pressed.connect(_leave)

func _host() -> void:
	_leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		status_label.text = "Erro ao criar sala: " + str(error)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Sala aberta na porta %d | IP LAN: %s" % [PORT, _local_ip()]

func _join() -> void:
	var address := room_address.text.strip_edges()
	if address.is_empty():
		status_label.text = "Digite o IP local do aparelho anfitrião."
		return
	_leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		status_label.text = "Erro de conexão: " + str(error)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando a %s..." % address

func _leave() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for actor in remote_actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	remote_actors.clear()
	remote_positions.clear()
	if status_label != null:
		status_label.text = "Offline · multiplayer LAN"

func _on_connected() -> void:
	status_label.text = "Conectado à sala · ID " + str(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_leave()
	status_label.text = "Não foi possível entrar na sala."

func _on_disconnected() -> void:
	_leave()
	status_label.text = "Conexão com o anfitrião encerrada."

func _on_peer_connected(peer_id: int) -> void:
	if status_label:
		status_label.text = "Jogador %d entrou" % peer_id

func _on_peer_disconnected(peer_id: int) -> void:
	if remote_actors.has(peer_id):
		remote_actors[peer_id].queue_free()
		remote_actors.erase(peer_id)
	remote_positions.erase(peer_id)
	if status_label:
		status_label.text = "Jogador %d saiu" % peer_id

func _local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			if ":" not in address:
				return address
	return "consulte o Wi-Fi do Android"

@rpc("any_peer", "call_remote", "unreliable")
func submit_pose(location: Vector3, facing: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 1:
		return
	remote_positions[sender] = location
	_show_remote(sender, location, facing)
	sync_pose.rpc(sender, location, facing)

@rpc("authority", "call_remote", "unreliable")
func sync_pose(peer_id: int, location: Vector3, facing: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	remote_positions[peer_id] = location
	_show_remote(peer_id, location, facing)

func _show_remote(peer_id: int, location: Vector3, facing: float) -> void:
	if not remote_actors.has(peer_id):
		var actor := StaticBody3D.new()
		actor.name = "Peer_%d" % peer_id
		actor.set_meta("peer_id", peer_id)
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.42
		shape.height = 1.8
		collision.shape = shape
		collision.position.y = 0.9
		actor.add_child(collision)
		var mesh := MeshInstance3D.new()
		var visual := CapsuleMesh.new()
		visual.radius = 0.42
		visual.height = 1.8
		mesh.mesh = visual
		mesh.position.y = 0.9
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.62, 0.28)
		mesh.material_override = material
		actor.add_child(mesh)
		get_tree().current_scene.add_child(actor)
		remote_actors[peer_id] = actor
	var actor: StaticBody3D = remote_actors[peer_id]
	actor.global_position = actor.global_position.lerp(location, 0.62)
	actor.rotation.y = lerp_angle(actor.rotation.y, facing, 0.55)

func request_hit(victim_id: int, damage: float) -> void:
	if not _online() or victim_id == multiplayer.get_unique_id():
		return
	if multiplayer.is_server():
		_validate_hit(1, victim_id, damage)
	else:
		propose_hit.rpc_id(1, victim_id, damage)

@rpc("any_peer", "call_remote", "reliable")
func propose_hit(victim_id: int, damage: float) -> void:
	if multiplayer.is_server():
		_validate_hit(multiplayer.get_remote_sender_id(), victim_id, damage)

func _validate_hit(attacker_id: int, victim_id: int, damage: float) -> void:
	if attacker_id == victim_id or damage <= 0.0 or damage > 35.0:
		return
	var from: Vector3 = player.global_position if attacker_id == 1 else remote_positions.get(attacker_id, Vector3(9999, 0, 9999))
	var target: Vector3 = player.global_position if victim_id == 1 else remote_positions.get(victim_id, Vector3(-9999, 0, -9999))
	if from.distance_to(target) > 85.0:
		return
	if victim_id == 1:
		battle.take_damage(damage)
	else:
		receive_damage.rpc_id(victim_id, damage)

@rpc("authority", "call_remote", "reliable")
func receive_damage(damage: float) -> void:
	if battle != null:
		battle.take_damage(clampf(damage, 0.0, 35.0))
