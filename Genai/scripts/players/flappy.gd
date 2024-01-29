extends Node2D

#@onready 
var ai := GenAi.Ai.new()
#GenAi.init(get_tree().root.get_node("Main").ai_name, get_tree().root.get_node("Main").layer_structure)

var gravity := 0.5
var jump_force := -8
var velocity := Vector2.ZERO
var human_controlled := false

var score := 0


func _physics_process(_delta):
	if Input.is_action_just_pressed("Space") and human_controlled:
		jump()

func update():
	velocity.y += gravity
	position += velocity
	
	if position.x < -500 or position.y < -270 or position.y > 270:
		die()

func jump():
	velocity.y = jump_force

func die():
	var player_count := get_parent().get_child_count()
	var main := get_parent().get_parent().get_parent()
	
	if player_count <= main.ais_to_save:
		main.best_ais.append(ai)
	
	if score > main.best_ai.high_score:
		ai.high_score = score
		if score > GenAi.open(main.ai_name).high_score:
			main.best_ai = ai.clone()
			main.best_ai.ai_name = main.ai_name
			GenAi.save(main.best_ai, true)
	
	queue_free()


func _on_area_body_entered(body):
	if body.name.begins_with("Pipe"):
		die()

func _on_area_body_exited(body):
	if body.name.begins_with("Point"):
		score += 1
