extends Node3D

const PORT := 24567
const MAX_PLAYERS := 2
const ARENA_X := 8.0
const ARENA_Z := 10.0

var is_server := false
var local_move := Vector2.ZERO
var shoot_pressed := false
var player_nodes: Dictionary = {}
var player_positions: Dictionary = {}
var input_states: Dictionary = {}
var shoot_cooldowns: Dictionary = {}
var ball_position := Vector3(0, 0.65, 0)
var ball_velocity := Vector3.ZERO
var score := [0, 0]
var send_timer := 0.0
var match_over := false

var status_label: Label
var score_label: Label
var ip_field: LineEdit
var shoot_button: Button
var move_flags := {"left": false, "right": false, "up": false, "down": false}

func _ready() -> void:
	_build_arena()
	_build_camera()
	_build_lighting()
	_build_ball()
	_build_hud()
	_ensure_player(1)
	player_positions[1] = Vector3(0, 0, 6)
	status_label.text = "Host a match or join using the host's local IP"

func _physics_process(delta: float) -> void:
	_refresh_local_move()
	if is_server:
		input_states[1] = {"move": local_move, "shoot": shoot_pressed}
		_server_step(delta)
		send_timer += delta
		if send_timer >= 0.05:
			send_timer = 0.0
			_broadcast_snapshot()
	elif multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "submit_input", local_move, shoot_pressed)

func _build_arena() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(18, 0.4, 22)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.25
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.055, 0.12, 0.24)
	floor_mat.metallic = 0.25
	floor_mat.roughness = 0.55
	floor.material_override = floor_mat
	add_child(floor)

	_add_box(Vector3(18, 1.2, 0.35), Vector3(0, 0.4, -10.8), Color(0.12, 0.55, 0.95))
	_add_box(Vector3(18, 1.2, 0.35), Vector3(0, 0.4, 10.8), Color(0.95, 0.35, 0.18))
	_add_box(Vector3(0.18, 0.03, 20), Vector3(0, 0.0, 0), Color(0.25, 0.75, 1.0))
	_add_box(Vector3(16, 0.04, 0.12), Vector3(0, 0.02, 0), Color(0.4, 0.8, 1.0))
	_add_box(Vector3(0.12, 0.04, 20), Vector3(-8.7, 0.02, 0), Color(0.2, 0.6, 0.95))
	_add_box(Vector3(0.12, 0.04, 20), Vector3(8.7, 0.02, 0), Color(0.2, 0.6, 0.95))
	for z in [-5.0, 5.0]:
		_add_box(Vector3(16, 0.04, 0.12), Vector3(0, 0.03, z), Color(0.18, 0.45, 0.75))

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.18
	node.material_override = mat
	add_child(node)

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 17, 20)
	camera.rotation_degrees = Vector3(-38, 0, 0)
	camera.current = true
	camera.fov = 52
	add_child(camera)

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.8)
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.35
	add_child(light)

func _build_ball() -> void:
	var orb := MeshInstance3D.new()
	orb.name = "EnergyBall"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.55, 1.0)
	mat.emission_energy_multiplier = 2.0
	orb.material_override = mat
	orb.position = ball_position
	add_child(orb)

func _ensure_player(peer_id: int) -> void:
	if player_nodes.has(peer_id):
		return
	var body := Node3D.new()
	body.name = "Player_%s" % peer_id
	var is_blue := peer_id % 2 == 1
	var body_color := Color(0.12, 0.65, 1.0) if is_blue else Color(1.0, 0.35, 0.18)

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.48
	capsule.height = 1.65
	torso.mesh = capsule
	torso.position.y = 0.95
	var torso_mat := StandardMaterial3D.new()
	torso_mat.albedo_color = body_color
	torso_mat.metallic = 0.22
	torso.material_override = torso_mat
	body.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.38
	head_mesh.height = 0.76
	head.mesh = head_mesh
	head.position = Vector3(0, 1.95, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.88, 0.72, 0.57)
	head.material_override = head_mat
	body.add_child(head)

	var aura := MeshInstance3D.new()
	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = 0.62
	aura_mesh.height = 1.24
	aura.mesh = aura_mesh
	aura.position.y = 0.95
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(body_color.r, body_color.g, body_color.b, 0.16)
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = body_color
	aura_mat.emission_energy_multiplier = 0.55
	aura.material_override = aura_mat
	body.add_child(aura)

	add_child(body)
	player_nodes[peer_id] = body
	player_positions[peer_id] = Vector3(0, 0, 6 if peer_id % 2 == 1 else -6)
	body.position = player_positions[peer_id]
	shoot_cooldowns[peer_id] = 0.0

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	score_label = Label.new()
	score_label.position = Vector2(520, 14)
	score_label.size = Vector2(240, 55)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 34)
	score_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	score_label.text = "0  :  0"
	root.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 16)
	status_label.size = Vector2(470, 34)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(status_label)

	ip_field = LineEdit.new()
	ip_field.position = Vector2(18, 58)
	ip_field.size = Vector2(190, 42)
	ip_field.placeholder_text = "Host IP (e.g. 192.168.1.5)"
	ip_field.text = "127.0.0.1"
	root.add_child(ip_field)

	var host_btn := _make_button("HOST", Vector2(218, 58), Vector2(100, 42))
	host_btn.pressed.connect(_host_game)
	root.add_child(host_btn)
	var join_btn := _make_button("JOIN", Vector2(326, 58), Vector2(100, 42))
	join_btn.pressed.connect(_join_game)
	root.add_child(join_btn)

	_add_control_button(root, "◀", Vector2(34, 560), "left")
	_add_control_button(root, "▶", Vector2(150, 560), "right")
	_add_control_button(root, "▲", Vector2(92, 500), "up")
	_add_control_button(root, "▼", Vector2(92, 620), "down")

	shoot_button = _make_button("ENERGY!", Vector2(1040, 535), Vector2(190, 110))
	shoot_button.add_theme_font_size_override("font_size", 25)
	shoot_button.button_down.connect(func(): shoot_pressed = true)
	shoot_button.button_up.connect(func(): shoot_pressed = false)
	root.add_child(shoot_button)

	var help := Label.new()
	help.position = Vector2(18, 112)
	help.size = Vector2(440, 30)
	help.text = "Move with arrows • Hold ENERGY! near the ball to strike"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.75, 0.83, 1.0))
	root.add_child(help)

func _make_button(caption: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	return button

func _add_control_button(parent: Control, caption: String, pos: Vector2, key: String) -> void:
	var button := _make_button(caption, pos, Vector2(92, 54))
	button.button_down.connect(func(): move_flags[key] = true)
	button.button_up.connect(func(): move_flags[key] = false)
	parent.add_child(button)

func _refresh_local_move() -> void:
	var x := float(move_flags["right"]) - float(move_flags["left"])
	var y := float(move_flags["down"]) - float(move_flags["up"])
	local_move = Vector2(x, y).normalized()

func _host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		status_label.text = "Could not host: error %s" % error
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	_ensure_player(1)
	player_positions[1] = Vector3(0, 0, 6)
	var local_ip := _get_local_ip()
	status_label.text = "HOST: %s:%s • Share this with player 2" % [local_ip, PORT]
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _get_local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127."):
			return address
	return "Check Wi-Fi IP in Android settings"

func _join_game() -> void:
	var address := ip_field.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the host IP first"
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		status_label.text = "Could not join: error %s" % error
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	status_label.text = "Connecting to %s..." % address
	multiplayer.connected_to_server.connect(func():
		_ensure_player(multiplayer.get_unique_id())
		status_label.text = "Connected • Match started"
	)
	multiplayer.connection_failed.connect(func(): status_label.text = "Connection failed")
	multiplayer.server_disconnected.connect(func(): status_label.text = "Host disconnected")

func _on_peer_connected(peer_id: int) -> void:
	_ensure_player(peer_id)
	player_positions[peer_id] = Vector3(0, 0, -6)
	input_states[peer_id] = {"move": Vector2.ZERO, "shoot": false}
	status_label.text = "Opponent connected • First to 3 points wins"

func _on_peer_disconnected(peer_id: int) -> void:
	if player_nodes.has(peer_id):
		player_nodes[peer_id].queue_free()
		player_nodes.erase(peer_id)
	player_positions.erase(peer_id)
	input_states.erase(peer_id)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, shoot: bool) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	input_states[sender] = {"move": move.limit_length(1.0), "shoot": shoot}

func _server_step(delta: float) -> void:
	if match_over:
		return
	for peer_id in player_positions.keys():
		_ensure_player(int(peer_id))
		var state: Dictionary = input_states.get(peer_id, {"move": Vector2.ZERO, "shoot": false})
		var movement: Vector2 = state.get("move", Vector2.ZERO)
		var pos: Vector3 = player_positions[peer_id]
		pos.x += movement.x * 6.0 * delta
		pos.z += movement.y * 6.0 * delta
		pos.x = clampf(pos.x, -7.2, 7.2)
		pos.z = clampf(pos.z, -9.0, 9.0)
		player_positions[peer_id] = pos
		shoot_cooldowns[peer_id] = maxf(0.0, float(shoot_cooldowns.get(peer_id, 0.0)) - delta)
		if bool(state.get("shoot", false)) and shoot_cooldowns[peer_id] <= 0.0:
			if pos.distance_to(ball_position) < 4.2:
				var direction := Vector3(0, 0, -1 if pos.z > 0 else 1)
				ball_velocity = direction * 13.0 + Vector3(signf(pos.x - ball_position.x) * 1.5, 0, 0)
				shoot_cooldowns[peer_id] = 0.65

	ball_position += ball_velocity * delta
	ball_velocity *= pow(0.985, delta * 60.0)
	ball_position.x = clampf(ball_position.x, -8.0, 8.0)
	ball_position.y = 0.65

	if ball_position.z < -10.0:
		score[0] += 1
		_reset_ball()
	elif ball_position.z > 10.0:
		score[1] += 1
		_reset_ball()

	for peer_id in player_nodes.keys():
		player_nodes[peer_id].position = player_positions.get(peer_id, Vector3.ZERO)
	var orb := get_node_or_null("EnergyBall") as MeshInstance3D
	if orb:
		orb.position = ball_position
	score_label.text = "%s  :  %s" % [score[0], score[1]]
	if score[0] >= 3 or score[1] >= 3:
		match_over = true
		status_label.text = "BLUE TEAM WINS!" if score[0] >= 3 else "RED TEAM WINS!"

func _reset_ball() -> void:
	ball_position = Vector3(0, 0.65, 0)
	ball_velocity = Vector3.ZERO

func _broadcast_snapshot() -> void:
	var positions: Dictionary = {}
	for peer_id in player_positions.keys():
		positions[int(peer_id)] = player_positions[peer_id]
	rpc("receive_snapshot", positions, ball_position, score[0], score[1])

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(positions: Dictionary, orb_pos: Vector3, blue_score: int, red_score: int) -> void:
	for key in positions.keys():
		var peer_id := int(key)
		_ensure_player(peer_id)
		player_positions[peer_id] = positions[key]
		player_nodes[peer_id].position = positions[key]
	ball_position = orb_pos
	var orb := get_node_or_null("EnergyBall") as MeshInstance3D
	if orb:
		orb.position = orb_pos
	score_label.text = "%s  :  %s" % [blue_score, red_score]
	if blue_score >= 3:
		status_label.text = "BLUE TEAM WINS!"
	elif red_score >= 3:
		status_label.text = "RED TEAM WINS!"
