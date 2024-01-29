extends Control

@onready var player := preload("res://scenes/prefabs/flappy.tscn")
@onready var object := preload("res://scenes/prefabs/pipe.tscn")

var ai_name := "flappy"
var layer_structure : Array = []
var best_ai := GenAi.init(ai_name, layer_structure)
var best_ais := []

var ais_to_save := 4
var mutations_per_ai := 500
var first_round_multiplyer := 1
var play_time := 3

var w_strength := 0.2
var b_strength := 0.4
var w_amount := 1
var b_amount := 1

var epoch := 0

var ui_timer := 0.0
var timer := 0.0
var game_running := false
var game_paused := false
var auto_play_next := true
var play_on_time := false
var fullscreen := false



func _ready():
	update_ui(true)

func _physics_process(delta):
	if Input.is_action_just_pressed("F"):
		fullscreen = !fullscreen
		if fullscreen:
			scale = Vector2i(2, 2)
		else:
			scale = Vector2i(1, 1)
	
	if Input.is_action_just_pressed("H"):
		$World_2d.visible = !$World_2d.visible
	
	ui_timer += delta
	if ui_timer >= 0.5:
		ui_timer = 0
		update_ui()
	
	if game_running and not game_paused:
		timer += delta
		game_loop(delta)

func update_ui(fill := false):
	# ---------- Stats ----------
	$Grid/World_Spacer/VBox/Epochs/Value.text = str(epoch)
	$Grid/World_Spacer/VBox/Ais_alive/Value.text = str($World_2d/Players.get_child_count())
	#$Grid/World_Spacer/VBox/High_score/Value.text = str(best_ai.high_score)
	
	if $World_2d/Players.get_child_count() > 0:
		$Grid/World_Spacer/VBox/Current_score/Value.text = str($World_2d/Players.get_child(0).score)
	# ---------- ----- ----------
	
	# ---------- Settings ----------
	if fill:
		$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/AI_name/Value.text = ai_name
		$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/Layer_structure/Value.text = str(layer_structure)
		
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_strength/HBox/Value.max_value = 1 - GenAi.low_point
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_strength/HBox/Value.max_value = GenAi.clamp_biases * 2
		
		var num_params := GenAi.get_num_params(best_ai.clone())
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_amount/HBox/Value.max_value = num_params.x
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_amount/HBox/Value.max_value = num_params.y
		
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/AIs_to_save/HBox/Value.value = ais_to_save
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/AIs_to_save/HBox/Value_display.text = str(
			ais_to_save
		)
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Mutations_per_ai/HBox/Value.value = mutations_per_ai
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Mutations_per_ai/HBox/Value_display.text = str(
			mutations_per_ai
		)
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_strength/HBox/Value.value = w_strength
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_strength/HBox/Value_display.text = str(
			w_strength
		)
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_strength/HBox/Value.value = b_strength
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_strength/HBox/Value_display.text = str(
			b_strength
		)
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_amount/HBox/Value.value = w_amount
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_amount/HBox/Value_display.text = str(
			w_amount
		)
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_amount/HBox/Value.value = b_amount
		$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_amount/HBox/Value_display.text = str(
			b_amount
		)
	
	$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/Simulation_control/Pause_next/Check_box.button_pressed = game_paused
	$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/Simulation_control/Autoplay_simulation/Check_box.button_pressed = auto_play_next
	# ---------- -------- ----------


func start_game():
	timer = 0
	epoch += 1
	
	# OPEN BEST AI FOR EVERY GENERATION
	_on_loadai_pressed()
	
	for new_ai in range(min(len(best_ais), ais_to_save)):
		spawn_players(mutations_per_ai, best_ais[new_ai])
	if $World_2d/Players.get_child_count() < ais_to_save * mutations_per_ai:
		var ais_to_spawn := ais_to_save * mutations_per_ai - $World_2d/Players.get_child_count()
		spawn_players(ais_to_spawn, best_ai.clone())
	
	best_ais.clear()
	
	if len($World_2d/Players.get_children()) > 0:
		game_running = true
		spawn_object(120)
		spawn_object()

func game_loop(delta : float):
	# ----- FLAPPY -----
	if timer >= 1:
		timer = 0
		spawn_object()
		update_ui()
	
	var players := $World_2d/Players.get_children()
	var objects := $World_2d/Objects.get_children()
	
	if len(players) <= 0:
		round_over()
		return
	
	for p in players:
		p.update()
	
	for o in objects:
		o.position.x -= 380 * delta # Used to be only 6
		if o.position.x < -500:
			o.queue_free()
	
	update_players()

func round_over():
	game_running = false
	var players := $World_2d/Players.get_children()
	var objects := $World_2d/Objects.get_children()
	
	for o in objects:
		o.queue_free()
	
	players = $World_2d/Players.get_children()
	for p in players:
		p.queue_free()
	
	if auto_play_next:
		start_game()

func get_first_player():
	var current_high_score := -1000
	var current_first := player.instantiate()
	for p in $World_2d/Players.get_children():
		if p.position.x > current_high_score:
			current_high_score = p.position.x
			current_first = p
	return current_first


func spawn_object(position_x := 540, height := randi_range(-120, 120)):
	var new_object := object.instantiate()
	new_object.position = Vector2(position_x, height)
	$World_2d/Objects.add_child(new_object)

func spawn_players(amount : int, mutate_from := best_ai.clone()):
	for a in range(amount):
		spawn_player(mutate_from.clone())

func spawn_player(mutate_from := best_ai.clone()):
	var new_player := player.instantiate()
	new_player.ai = GenAi.mutate(mutate_from, w_strength, b_strength, w_amount, b_amount)
	new_player.position = $World_2d/Spawnpoint.position
	$World_2d/Players.add_child(new_player)

func update_players():
	var players := $World_2d/Players.get_children()
	
	for p in players:
		var objects := $World_2d/Objects.get_children()
		
		var input := [
			remap(p.position.y, -270, 270, -1, 1),
			remap(p.velocity.y, -8, 10, -1, 1),
			remap(objects[0].position.x, -500, 540, -1, 1),
			remap(objects[0].position.y, -120, 120, -1, 1),
		]
		if len(objects) >= 2:
			input.append_array([
				remap(objects[1].position.x, -500, 540, -1, 1),
				remap(objects[1].position.y, -120, 120, -1, 1),
			])
		else:
			input.append_array([1, 0])
		
		var output := GenAi.calculate(input, p.ai)
		
		if output[0] > 0:
			p.jump()
		
		
		# --------------- STICKMAN AI ---------------
		#var output := GenAi.calculate(p.input, p.ai)
		#p.get_node("Head").rotation += output[0]
		#p.get_node("Left_leg").rotation += output[0]
		#p.get_node("Right_leg").rotation += output[1]
		#p.get_node("Left_arm").rotation += output[3]
		#p.get_node("Right_arm").rotation += output[4]


# --------------- Events ---------------
func _on_ainame_submitted(new_text):
	ai_name = new_text
	$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/AI_name/Value.release_focus()

func _on_layerstructure_submitted(new_text : String):
	layer_structure = new_text.replace("[", "").replace("]", "").split(", ")
	for i in range(len(layer_structure)):
		layer_structure[i] = int(layer_structure[i])
	$Grid/AI_Controller/VBox/Settings_grups/Generel_settings/Layer_structure/Value.release_focus()

func _on_saveai_pressed():
	GenAi.save(best_ai, true)

func _on_loadai_pressed():
	if not game_running:
		best_ai = GenAi.open(ai_name)
		layer_structure = best_ai.layer_structure
	update_ui(true)

func _on_generateai_pressed():
	if not game_running:
		if best_ai.high_score > 0:
			GenAi.save(best_ai, true)
		best_ai = GenAi.init(ai_name, layer_structure)

func _on_pause_toggled(toggled_on : bool):
	game_paused = toggled_on

func _on_aistosave_changed(value):
	ais_to_save = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/AIs_to_save/HBox/Value_display.text = str(
		ais_to_save
	)

func _on_mutationsperai_changed(value):
	mutations_per_ai = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Mutations_per_ai/HBox/Value_display.text = str(
		mutations_per_ai
	)

func _on_nextgeneration_pressed():
	if not game_running:
		start_game()

func _on_autoplaysimulation_toggled(toggled_on : bool):
	auto_play_next = toggled_on

func _on_weightstrength_changed(value):
	w_strength = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_strength/HBox/Value_display.text = str(
		w_strength
	)

func _on_biasestrength_changed(value):
	b_strength = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_strength/HBox/Value_display.text = str(
		b_strength
	)

func _on_weightamount_changed(value):
	w_amount = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Weight_amount/HBox/Value_display.text = str(
		w_amount
	)

func _on_biaseamount_changed(value):
	b_amount = value
	$Grid/AI_Controller/VBox/Settings_grups/AI_settings/Biase_amount/HBox/Value_display.text = str(
		b_amount
	)

func _on_save_location_dir_selected(dir):
	GenAi.file_location = dir

func _on_selectsavelocation_pressed():
	$Save_location.popup_centered()
