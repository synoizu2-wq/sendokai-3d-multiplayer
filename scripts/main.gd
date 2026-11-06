extends Node3D

const ARENA_X := 8.0
const PLAYER_START := Vector3(0, 0, 6)
const AI_START := Vector3(0, 0, -6)
const TEAM_NAMES := ["Storm", "Ember", "Nova"]
const TARGET_SCORE := 3

var local_move := Vector2.ZERO
var shoot_pressed := false
var player_position := PLAYER_START
var ai_position := AI_START
var ball_position := Vector3(0, 0.65, 0)
var ball_velocity := Vector3.ZERO
var score := [0, 0]
var player_cooldown := 0.0
var ai_cooldown := 0.0
var match_over := false
var tournament_over := false
var round_number := 1
var current_opponent := "Storm"
var final_opponent := "Ember"
var player_won_semifinal := false

var player_node: Node3D
var ai_node: Node3D
var status_label: Label
var score_label: Label
var tournament_label: Label
var next_button: Button
var move_flags := {"left": false, "right": false, "up": false, "down": false}

func _ready() -> void:
	_build_arena()
	_build_camera()
	_build_lighting()
	_build_ball()
	_build_fighters()
	_build_hud()
	_start_match("SEMIFINAL • MATCH 1 OF 2", "Storm")

func _physics_process(delta: float) -> void:
	if match_over or tournament_over:
		return
	_refresh_local_move()
	_step_match(delta)

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

func _make_fighter(display_name: String, body_color: Color) -> Node3D:
	var body := Node3D.new()
	body.name = display_name
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
	return body

func _build_fighters() -> void:
	player_node = _make_fighter("Player", Color(0.12, 0.65, 1.0))
	ai_node = _make_fighter("CPU", Color(1.0, 0.35, 0.18))
	player_node.position = player_position
	ai_node.position = ai_position

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	tournament_label = Label.new()
	tournament_label.position = Vector2(18, 12)
	tournament_label.size = Vector2(560, 36)
	tournament_label.add_theme_font_size_override("font_size", 22)
	tournament_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	root.add_child(tournament_label)

	score_label = Label.new()
	score_label.position = Vector2(520, 48)
	score_label.size = Vector2(240, 55)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	score_label.text = "0  :  0"
	root.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 52)
	status_label.size = Vector2(470, 38)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(status_label)

	_add_control_button(root, "◀", Vector2(34, 560), "left")
	_add_control_button(root, "▶", Vector2(150, 560), "right")
	_add_control_button(root, "▲", Vector2(92, 500), "up")
	_add_control_button(root, "▼", Vector2(92, 620), "down")

	var shoot_button := _make_button("ENERGY!", Vector2(1040, 535), Vector2(190, 110))
	shoot_button.add_theme_font_size_override("font_size", 25)
	shoot_button.button_down.connect(func(): shoot_pressed = true)
	shoot_button.button_up.connect(func(): shoot_pressed = false)
	root.add_child(shoot_button)

	next_button = _make_button("CONTINUE", Vector2(520, 625), Vector2(240, 58))
	next_button.visible = false
	next_button.pressed.connect(_continue_tournament)
	root.add_child(next_button)

	var help := Label.new()
	help.position = Vector2(18, 112)
	help.size = Vector2(500, 30)
	help.text = "OFFLINE CUP • Move with arrows • Hold ENERGY! near the ball"
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

func _step_match(delta: float) -> void:
	player_cooldown = maxf(0.0, player_cooldown - delta)
	ai_cooldown = maxf(0.0, ai_cooldown - delta)

	player_position.x += local_move.x * 6.0 * delta
	player_position.z += local_move.y * 6.0 * delta
	player_position.x = clampf(player_position.x, -7.2, 7.2)
	player_position.z = clampf(player_position.z, 1.2, 9.0)

	var to_ball := Vector2(ball_position.x - ai_position.x, ball_position.z - ai_position.z)
	var ai_move := to_ball.normalized()
	if to_ball.length() > 1.0:
		ai_position.x += ai_move.x * 4.0 * delta
		ai_position.z += ai_move.y * 4.0 * delta
	ai_position.x = clampf(ai_position.x, -7.2, 7.2)
	ai_position.z = clampf(ai_position.z, -9.0, -1.2)

	if shoot_pressed and player_cooldown <= 0.0 and player_position.distance_to(ball_position) < 3.8:
		var aim := Vector3(0, 0, -1)
		aim.x = clampf((ball_position.x - player_position.x) * 0.35, -0.55, 0.55)
		ball_velocity = aim.normalized() * 14.0
		player_cooldown = 0.6

	if ai_cooldown <= 0.0 and ai_position.distance_to(ball_position) < 3.5:
		var aim_ai := Vector3(0, 0, 1)
		aim_ai.x = clampf((ball_position.x - ai_position.x) * 0.35, -0.55, 0.55)
		ball_velocity = aim_ai.normalized() * 11.0
		ai_cooldown = 1.0

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

	player_node.position = player_position
	ai_node.position = ai_position
	var orb := get_node_or_null("EnergyBall") as MeshInstance3D
	if orb:
		orb.position = ball_position
	score_label.text = "%s  :  %s" % [score[0], score[1]]
	if score[0] >= TARGET_SCORE or score[1] >= TARGET_SCORE:
		_finish_match()

func _reset_ball() -> void:
	ball_position = Vector3(0, 0.65, 0)
	ball_velocity = Vector3.ZERO
	player_position = PLAYER_START
	ai_position = AI_START
	player_node.position = player_position
	ai_node.position = ai_position

func _start_match(round_title: String, opponent: String) -> void:
	current_opponent = opponent
	score = [0, 0]
	match_over = false
	shoot_pressed = false
	player_cooldown = 0.0
	ai_cooldown = 0.0
	_reset_ball()
	score_label.text = "0  :  0"
	status_label.text = "YOU vs %s • First to %s points" % [current_opponent, TARGET_SCORE]
	tournament_label.text = "OFFLINE CUP  •  " + round_title
	next_button.visible = false

func _finish_match() -> void:
	match_over = true
	if score[0] > score[1]:
		status_label.text = "YOU DEFEATED %s!" % current_opponent.to_upper()
		if round_number == 1:
			player_won_semifinal = true
			next_button.text = "PLAY THE FINAL"
			next_button.visible = true
		else:
			tournament_over = true
			tournament_label.text = "OFFLINE CUP  •  CHAMPION!"
			status_label.text = "YOU ARE THE CUP CHAMPION! 🏆"
			next_button.text = "PLAY AGAIN"
			next_button.visible = true
	else:
		tournament_over = true
		tournament_label.text = "OFFLINE CUP  •  ELIMINATED"
		status_label.text = "TOURNAMENT OVER • %s WON" % current_opponent.to_upper()
		next_button.text = "TRY AGAIN"
		next_button.visible = true

func _continue_tournament() -> void:
	if tournament_over:
		round_number = 1
		tournament_over = false
		player_won_semifinal = false
		_start_match("SEMIFINAL • MATCH 1 OF 2", "Storm")
		return
	if round_number == 1 and player_won_semifinal:
		round_number = 2
		_start_match("GRAND FINAL • MATCH 2 OF 2", final_opponent)
