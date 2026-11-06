extends Node3D

# Offline anime football prototype: 11 vs 11, CPU opponents, tournament mode.
const FIELD_X := 42.0
const FIELD_Z := 68.0
const MATCH_SECONDS := 150.0
const TEAM_SIZE := 11
const TEAM_NAMES := ["Rising Stars", "Red Falcons", "Blue Wolves", "Thunder FC"]

var players: Array[Node3D] = []
var player_data: Array[Dictionary] = []
var selected_id := 9
var ball: MeshInstance3D
var ball_pos := Vector3.ZERO
var ball_vel := Vector3.ZERO
var owner_id := -1
var score_home := 0
var score_away := 0
var match_clock := MATCH_SECONDS
var match_finished := false
var tournament_finished := false
var round_index := 0
var opponent_name := ""
var joystick := Vector2.ZERO
var move_flags := {"up": false, "down": false, "left": false, "right": false}
var action_cooldown := 0.0
var ai_shot_cooldown := 0.0
var special_charge := 100.0

var hud_score: Label
var hud_clock: Label
var hud_round: Label
var hud_message: Label
var minimap: Control
var action_buttons: Dictionary = {}
var continue_button: Button

func _ready() -> void:
	randomize()
	_build_world()
	_build_field()
	_build_teams()
	_build_ball()
	_build_camera()
	_build_hud()
	_start_round()

func _process(delta: float) -> void:
	if match_finished:
		return
	match_clock = maxf(0.0, match_clock - delta)
	action_cooldown = maxf(0.0, action_cooldown - delta)
	ai_shot_cooldown = maxf(0.0, ai_shot_cooldown - delta)
	special_charge = minf(100.0, special_charge + delta * 3.0)
	_update_players(delta)
	_update_ball(delta)
	_update_camera(delta)
	_update_hud()
	if match_clock <= 0.0:
		_end_match()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.62, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.86, 1.0)
	env.ambient_light_energy = 0.9
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -25, 0)
	sun.light_energy = 1.25
	add_child(sun)

func _build_field() -> void:
	_add_box(Vector3(FIELD_X, 0.3, FIELD_Z), Vector3(0, -0.2, 0), Color(0.08, 0.48, 0.16))
	for i in range(10):
		var stripe_color := Color(0.12, 0.56, 0.19) if i % 2 == 0 else Color(0.09, 0.49, 0.16)
		_add_box(Vector3(FIELD_X, 0.012, FIELD_Z / 10.0), Vector3(0, -0.035, -FIELD_Z / 2.0 + (i + 0.5) * FIELD_Z / 10.0), stripe_color)
	var line_color := Color(0.9, 0.96, 0.9)
	_add_box(Vector3(FIELD_X, 0.025, 0.16), Vector3(0, 0.0, -FIELD_Z / 2.0), line_color)
	_add_box(Vector3(FIELD_X, 0.025, 0.16), Vector3(0, 0.0, FIELD_Z / 2.0), line_color)
	_add_box(Vector3(0.16, 0.025, FIELD_Z), Vector3(-FIELD_X / 2.0, 0.0, 0), line_color)
	_add_box(Vector3(0.16, 0.025, FIELD_Z), Vector3(FIELD_X / 2.0, 0.0, 0), line_color)
	_add_box(Vector3(FIELD_X, 0.025, 0.16), Vector3(0, 0.0, 0), line_color)
	_add_ring(Vector3(0, 0.035, 0), 6.0, line_color)
	_add_box(Vector3(16, 0.025, 0.16), Vector3(0, 0.02, -FIELD_Z / 2.0 + 8), line_color)
	_add_box(Vector3(16, 0.025, 0.16), Vector3(0, 0.02, FIELD_Z / 2.0 - 8), line_color)
	_add_box(Vector3(0.16, 0.025, 16), Vector3(-8, 0.02, -FIELD_Z / 2.0 + 8), line_color)
	_add_box(Vector3(0.16, 0.025, 16), Vector3(8, 0.02, -FIELD_Z / 2.0 + 8), line_color)
	_add_box(Vector3(0.16, 0.025, 16), Vector3(-8, 0.02, FIELD_Z / 2.0 - 8), line_color)
	_add_box(Vector3(0.16, 0.025, 16), Vector3(8, 0.02, FIELD_Z / 2.0 - 8), line_color)
	_add_box(Vector3(8, 2.8, 0.35), Vector3(0, 1.4, -FIELD_Z / 2.0 - 0.2), Color(0.88, 0.9, 0.94))
	_add_box(Vector3(8, 2.8, 0.35), Vector3(0, 1.4, FIELD_Z / 2.0 + 0.2), Color(0.88, 0.9, 0.94))
	# Simple stands frame the pitch.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(5, 3, FIELD_Z + 12), Vector3(side * (FIELD_X / 2.0 + 3.5), 1.0, 0), Color(0.12, 0.2, 0.38))
		_add_box(Vector3(FIELD_X + 14, 2.5, 5), Vector3(0, 0.8, side * (FIELD_Z / 2.0 + 4)), Color(0.16, 0.23, 0.42))

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	node.material_override = mat
	add_child(node)

func _add_ring(pos: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.07
	torus.outer_radius = radius + 0.07
	ring.mesh = torus
	ring.position = pos
	ring.rotation_degrees.x = 90
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	ring.material_override = mat
	add_child(ring)

func _build_teams() -> void:
	var home_formation := [
		Vector3(0, 0, 30), Vector3(-15, 0, 20), Vector3(-5, 0, 22), Vector3(5, 0, 22), Vector3(15, 0, 20),
		Vector3(-13, 0, 7), Vector3(-4, 0, 10), Vector3(4, 0, 10), Vector3(13, 0, 7),
		Vector3(-7, 0, -8), Vector3(7, 0, -8)
	]
	var away_formation := [
		Vector3(0, 0, -30), Vector3(-15, 0, -20), Vector3(-5, 0, -22), Vector3(5, 0, -22), Vector3(15, 0, -20),
		Vector3(-13, 0, -7), Vector3(-4, 0, -10), Vector3(4, 0, -10), Vector3(13, 0, -7),
		Vector3(-7, 0, 8), Vector3(7, 0, 8)
	]
	for team in range(2):
		for i in range(TEAM_SIZE):
			var is_home := team == 0
			var p := _make_player(is_home, i)
			players.append(p)
			var start_pos: Vector3 = home_formation[i] if is_home else away_formation[i]
			player_data.append({"team": team, "slot": i, "home": start_pos, "speed": 7.0 if i != 0 else 5.5, "stun": 0.0})
			p.position = start_pos
	selected_id = 9

func _make_player(is_home: bool, shirt_number: int) -> Node3D:
	var root := Node3D.new()
	var shirt := Color(0.18, 0.62, 1.0) if is_home else Color(0.92, 0.16, 0.19)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = shirt
	mat.metallic = 0.12
	body.material_override = mat
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	head.mesh = sphere
	head.position.y = 2.05
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.68, 0.53)
	head.material_override = skin
	root.add_child(head)
	var number_label := Label3D.new()
	number_label.text = str(shirt_number + 1)
	number_label.position.y = 2.65
	number_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number_label.font_size = 28
	root.add_child(number_label)
	add_child(root)
	return root

func _build_ball() -> void:
	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	ball.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.96, 0.92)
	mat.roughness = 0.45
	ball.material_override = mat
	ball.position = Vector3(0, 0.48, 0)
	add_child(ball)
	ball_pos = ball.position

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MatchCamera"
	camera.position = Vector3(0, 43, 39)
	camera.rotation_degrees = Vector3(-48, 0, 0)
	camera.fov = 58
	camera.current = true
	add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud_round = _label(root, Vector2(18, 8), Vector2(500, 30), 20, Color(1, 0.86, 0.35))
	hud_score = _label(root, Vector2(450, 8), Vector2(380, 42), 32, Color.WHITE)
	hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_clock = _label(root, Vector2(570, 48), Vector2(140, 30), 22, Color.WHITE)
	hud_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_message = _label(root, Vector2(390, 86), Vector2(500, 36), 20, Color(1, 0.92, 0.55))
	hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Four-way touch pad; buttons stay held while pressed.
	_add_move_button(root, "▲", Vector2(115, 480), "up")
	_add_move_button(root, "▼", Vector2(115, 610), "down")
	_add_move_button(root, "◀", Vector2(48, 545), "left")
	_add_move_button(root, "▶", Vector2(182, 545), "right")

	_add_action(root, "PASS", Vector2(1000, 500), Vector2(112, 64), _pass_ball)
	_add_action(root, "SHOOT", Vector2(1120, 565), Vector2(128, 78), _shoot_ball)
	_add_action(root, "LONG PASS", Vector2(970, 590), Vector2(130, 64), _long_pass)
	_add_action(root, "TACKLE", Vector2(1100, 660), Vector2(120, 54), _tackle)
	_add_action(root, "SWITCH", Vector2(840, 650), Vector2(112, 54), _switch_player)
	_add_action(root, "SPECIAL", Vector2(850, 545), Vector2(112, 64), _special_shot)

	minimap = Control.new()
	minimap.position = Vector2(540, 565)
	minimap.size = Vector2(200, 112)
	root.add_child(minimap)
	minimap.draw.connect(_draw_minimap)

	continue_button = Button.new()
	continue_button.text = "NEXT MATCH"
	continue_button.position = Vector2(520, 620)
	continue_button.size = Vector2(240, 58)
	continue_button.visible = false
	continue_button.pressed.connect(_continue_tournament)
	root.add_child(continue_button)

func _label(parent: Control, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_move_button(parent: Control, caption: String, pos: Vector2, key: String) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = Vector2(62, 62)
	button.add_theme_font_size_override("font_size", 24)
	button.button_down.connect(func(): move_flags[key] = true)
	button.button_up.connect(func(): move_flags[key] = false)
	parent.add_child(button)

func _add_action(parent: Control, caption: String, pos: Vector2, size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons[caption] = button

func _move_vector() -> Vector2:
	var x := float(move_flags["right"]) - float(move_flags["left"])
	var y := float(move_flags["down"]) - float(move_flags["up"])
	var v := Vector2(x, y)
	return v.normalized() if v.length() > 1.0 else v

func _update_players(delta: float) -> void:
	var move := _move_vector()
	var controlled_team := 0
	var active := players[selected_id]
	var data: Dictionary = player_data[selected_id]
	if owner_id == selected_id:
		active.position.x += move.x * 9.0 * delta
		active.position.z += move.y * 9.0 * delta
	else:
		active.position.x += move.x * 7.5 * delta
		active.position.z += move.y * 7.5 * delta
	active.position.x = clampf(active.position.x, -FIELD_X / 2.0 + 1, FIELD_X / 2.0 - 1)
	active.position.z = clampf(active.position.z, -FIELD_Z / 2.0 + 1, FIELD_Z / 2.0 - 1)

	for i in range(players.size()):
		if i == selected_id:
			continue
		var p := players[i]
		var d: Dictionary = player_data[i]
		var team := int(d["team"])
		var home: Vector3 = d["home"]
		var target := home
		if team == 1:
			if owner_id >= 0 and int(player_data[owner_id]["team"]) == 0:
				target = ball_pos
			elif i % TEAM_SIZE == 9 or i % TEAM_SIZE == 10:
				target = ball_pos + Vector3(0, 0, 5)
		elif owner_id >= 0 and int(player_data[owner_id]["team"]) == 0 and i % TEAM_SIZE in [9, 10]:
			target = ball_pos + Vector3(0, 0, -4)
		elif owner_id < 0 and i % TEAM_SIZE in [5, 6, 7, 8]:
			target = home.lerp(ball_pos, 0.22)
		var speed := float(d["speed"])
		var offset := target - p.position
		if offset.length() > 0.8:
			p.position += offset.normalized() * speed * delta
		p.position.x = clampf(p.position.x, -FIELD_X / 2.0 + 1, FIELD_X / 2.0 - 1)
		p.position.z = clampf(p.position.z, -FIELD_Z / 2.0 + 1, FIELD_Z / 2.0 - 1)

	if owner_id < 0:
		_try_claim_ball()
	else:
		var carrier := players[owner_id]
		ball_pos = carrier.position + Vector3(0, 0.5, -0.8 if int(player_data[owner_id]["team"]) == 0 else 0.8)
		ball_vel = Vector3.ZERO
	if int(player_data[selected_id]["team"]) == 1:
		selected_id = _nearest_home_player()
		_update_selection_visuals()

func _try_claim_ball() -> void:
	var best := 2.0
	var candidate := -1
	for i in range(players.size()):
		var dist := Vector2(players[i].position.x - ball_pos.x, players[i].position.z - ball_pos.z).length()
		if dist < best:
			best = dist
			candidate = i
	if candidate >= 0:
		owner_id = candidate
		if int(player_data[candidate]["team"]) == 0:
			selected_id = candidate
			_update_selection_visuals()
		else:
			hud_message.text = "OPPONENT HAS THE BALL!"

func _update_ball(delta: float) -> void:
	if owner_id < 0:
		ball_pos += ball_vel * delta
		ball_vel *= pow(0.985, delta * 60.0)
		if ball_pos.x < -FIELD_X / 2.0 or ball_pos.x > FIELD_X / 2.0:
			ball_vel.x *= -0.65
			ball_pos.x = clampf(ball_pos.x, -FIELD_X / 2.0, FIELD_X / 2.0)
		if ball_pos.z < -FIELD_Z / 2.0:
			if absf(ball_pos.x) < 4.2:
				score_home += 1
				_goal_scored("GOAL! RISING STARS")
			else:
				ball_vel.z *= -0.7
				ball_pos.z = -FIELD_Z / 2.0 + 1
		elif ball_pos.z > FIELD_Z / 2.0:
			if absf(ball_pos.x) < 4.2:
				score_away += 1
				_goal_scored("GOAL! " + opponent_name)
			else:
				ball_vel.z *= -0.7
				ball_pos.z = FIELD_Z / 2.0 - 1
	ball.position = ball_pos

func _goal_scored(message: String) -> void:
	hud_message.text = message
	owner_id = -1
	ball_pos = Vector3(0, 0.48, 0)
	ball_vel = Vector3.ZERO
	for i in range(players.size()):
		players[i].position = player_data[i]["home"]

func _pass_ball() -> void:
	if owner_id < 0 or int(player_data[owner_id]["team"]) != 0:
		return
	var target_id := _nearest_teammate(owner_id, false)
	if target_id >= 0:
		owner_id = -1
		var direction := players[target_id].position - players[owner_id].position
		direction.y = 0
		ball_pos = players[owner_id].position + Vector3(0, 0.5, -0.8)
		ball_vel = direction.normalized() * 17.0
		hud_message.text = "SHORT PASS!"

func _long_pass() -> void:
	if owner_id < 0 or int(player_data[owner_id]["team"]) != 0:
		return
	var from := players[owner_id].position
	owner_id = -1
	ball_pos = from + Vector3(0, 0.6, -0.8)
	ball_vel = Vector3(0, 0, -24)
	ball_vel.x = randf_range(-2.0, 2.0)
	hud_message.text = "LONG PASS!"

func _shoot_ball() -> void:
	if owner_id < 0 or int(player_data[owner_id]["team"]) != 0:
		return
	var from := players[owner_id].position
	owner_id = -1
	ball_pos = from + Vector3(0, 0.6, -0.9)
	var aim_x := clampf(-from.x * 0.08, -2.5, 2.5)
	ball_vel = Vector3(aim_x, 2.5, -31)
	hud_message.text = "POWER SHOT!"

func _special_shot() -> void:
	if special_charge < 35.0:
		hud_message.text = "SPECIAL SHOT IS RECHARGING"
		return
	if owner_id < 0 or int(player_data[owner_id]["team"]) != 0:
		return
	special_charge -= 35.0
	var from := players[owner_id].position
	owner_id = -1
	ball_pos = from + Vector3(0, 0.7, -0.9)
	ball_vel = Vector3(clampf(-from.x * 0.1, -3.0, 3.0), 7.0, -40.0)
	hud_message.text = "✦ ANIME SPECIAL SHOT! ✦"

func _tackle() -> void:
	if owner_id < 0 or int(player_data[owner_id]["team"]) == 0:
		return
	if players[selected_id].position.distance_to(players[owner_id].position) < 3.4:
		owner_id = selected_id
		hud_message.text = "PERFECT TACKLE!"
	else:
		hud_message.text = "MOVE CLOSER TO TACKLE"

func _switch_player() -> void:
	selected_id = _nearest_home_player()
	_update_selection_visuals()

func _nearest_home_player() -> int:
	var best_id := 1
	var best := INF
	for i in range(TEAM_SIZE):
		var d := players[i].position.distance_to(ball_pos)
		if d < best:
			best = d
			best_id = i
	return best_id

func _nearest_teammate(from_id: int, include_keeper: bool) -> int:
	var best_id := -1
	var best := INF
	for i in range(TEAM_SIZE):
		if i == from_id or (not include_keeper and i == 0):
			continue
		var d := players[i].position.distance_to(players[from_id].position)
		if d < best:
			best = d
			best_id = i
	return best_id

func _update_selection_visuals() -> void:
	for i in range(TEAM_SIZE):
		var p := players[i]
		p.scale = Vector3.ONE * (1.12 if i == selected_id else 1.0)

func _update_camera(delta: float) -> void:
	var cam := get_node_or_null("MatchCamera") as Camera3D
	if cam == null:
		return
	var focus := ball_pos
	cam.position = cam.position.lerp(Vector3(focus.x * 0.35, 43, focus.z + 39), minf(1.0, delta * 2.0))
	cam.look_at(Vector3(focus.x * 0.35, 0, focus.z - 3), Vector3.UP)

func _update_hud() -> void:
	hud_score.text = "RISING STARS   %d  -  %d   %s" % [score_home, score_away, opponent_name]
	var total := int(ceil(match_clock))
	hud_clock.text = "%02d:%02d" % [total / 60, total % 60]
	minimap.queue_redraw()

func _draw_minimap() -> void:
	var rect := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(rect, Color(0.02, 0.08, 0.06, 0.8), true)
	minimap.draw_rect(Rect2(Vector2(2, 2), minimap.size - Vector2(4, 4)), Color(0.8, 0.9, 0.8), false, 2)
	minimap.draw_line(Vector2(minimap.size.x / 2, 2), Vector2(minimap.size.x / 2, minimap.size.y - 2), Color.WHITE, 1)
	for i in range(players.size()):
		var p := players[i].position
		var x := (p.x / FIELD_X + 0.5) * minimap.size.x
		var y := (p.z / FIELD_Z + 0.5) * minimap.size.y
		var c := Color(0.15, 0.55, 1.0) if int(player_data[i]["team"]) == 0 else Color(1.0, 0.2, 0.18)
		minimap.draw_circle(Vector2(x, y), 3.2, c)
	var bx := (ball_pos.x / FIELD_X + 0.5) * minimap.size.x
	var by := (ball_pos.z / FIELD_Z + 0.5) * minimap.size.y
	minimap.draw_circle(Vector2(bx, by), 4.0, Color.YELLOW)

func _start_round() -> void:
	score_home = 0
	score_away = 0
	match_clock = MATCH_SECONDS
	match_finished = false
	owner_id = -1
	ball_pos = Vector3(0, 0.48, 0)
	ball_vel = Vector3.ZERO
	for i in range(players.size()):
		players[i].position = player_data[i]["home"]
	selected_id = 9
	_update_selection_visuals()
	hud_message.text = "KICK-OFF! TAKE CONTROL OF THE MATCH"
	continue_button.visible = false
	_update_hud()

func _end_match() -> void:
	match_finished = true
	if score_home > score_away:
		hud_message.text = "YOU WIN! ADVANCE TO THE NEXT ROUND"
	else:
		hud_message.text = "MATCH OVER • TRY AGAIN TO WIN THE CUP"
	continue_button.text = "NEXT MATCH" if score_home > score_away else "RETRY MATCH"
	continue_button.visible = true

func _continue_tournament() -> void:
	if score_home <= score_away:
		_start_round()
		return
	round_index += 1
	if round_index >= 3:
		tournament_finished = true
		hud_message.text = "🏆 YOU ARE THE OFFLINE CUP CHAMPION!"
		continue_button.text = "PLAY CUP AGAIN"
		round_index = -1
	else:
		_start_round()
		opponent_name = TEAM_NAMES[(round_index + 1) % TEAM_NAMES.size()]
