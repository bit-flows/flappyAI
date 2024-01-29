extends Node


# ---------- Ai setting ----------
# DO NOT change unless you know
# what your doing. Tings can break!
#
# Name of directory where ais are stored
var dir_name := "ai_models"
var file_location := "user://"
# File extention the saved ai should use
var file_extention := ".ai"
# Bias values cannot go higher than this value,
# and not lower than the negative (-clamp biases).
var clamp_biases := 4.0
var low_point := -1
# RandomNumberGenerator object used to get random numbers
var rng := RandomNumberGenerator.new()
# --------------------------------



# ---------- Editing ai objects ----------
# Call this function with a name for the ai,
# and an array with the layer structure.
# For example [2, 4, 1], has 2 input nodes,
# one hidden layer with 4 nodes, and 1 output node.
func init(ai_name : String, layer_structure : Array) -> Ai:
	# Create a new ai object and set the name and layer structure
	var new_ai := Ai.new()
	new_ai.ai_name = ai_name
	new_ai.layer_structure = layer_structure.duplicate(true)
	
	# Setup weights and biases
	create_weights(new_ai)
	create_biases(new_ai)
	
	return new_ai

func clone(ai : Ai) -> Ai:
	return ai.clone()



# ---------- Network operations ----------
func calculate(input : Array, ai : Ai) -> Array:
	var temp_network = [input.duplicate(true)]
	
	for layer in range(len(ai.layer_structure)):
		if layer > 0:
			temp_network.append([])
			for neuron in range(ai.layer_structure[layer]):
				var activation = 0
				for weight in range(ai.layer_structure[layer - 1]):
					activation += temp_network[layer - 1][weight] * ai.weights[layer - 1][neuron][weight]
				activation += ai.biases[layer - 1][neuron]
				
				if layer == len(ai.layer_structure) - 1:
					activation = tanh(activation)
				else:
					activation = tanh(activation)
				temp_network[layer].append(activation)
	
	return temp_network[-1]



# ---------- Functions to change weights and biases ----------
func create_weights(ai : Ai, randomize_values := true) -> Ai:
	rng.randomize()
	for layer in range(len(ai.layer_structure) - 1):
		ai.weights.append([])
		for neuron in range(ai.layer_structure[layer + 1]):
			ai.weights[layer].append([])
			for weight in range(ai.layer_structure[layer]):
				if randomize_values:
					ai.weights[layer][neuron].append(rng.randf_range(low_point, 1))
				else:
					ai.weights[layer][neuron].append(0)
	return ai

func create_biases(ai : Ai, randomize_values := false) -> Ai:
	rng.randomize()
	for layer in range(len(ai.layer_structure) - 1):
		ai.biases.append([])
		for neuron in range(ai.layer_structure[layer + 1]):
			if randomize_values:
				ai.biases[layer].append(rng.randf_range(-clamp_biases, clamp_biases))
			else:
				ai.biases[layer].append(0)
	return ai

func randomize_weights(ai : Ai, strength : float = 0.1, amount : int = 1) -> Ai:
	for a in range(amount):
		rng.randomize()
		var random_layer := rng.randi_range(0, len(ai.weights) - 1)
		var random_neuron := rng.randi_range(0, len(ai.weights[random_layer]) - 1)
		var random_weight := rng.randi_range(0, len(ai.weights[random_layer][random_neuron]) - 1)
		
		ai.weights[random_layer][random_neuron][random_weight] += rng.randf_range(-strength, strength)
		if ai.weights[random_layer][random_neuron][random_weight] > 1:
			ai.weights[random_layer][random_neuron][random_weight] = 1
		elif ai.weights[random_layer][random_neuron][random_weight] < low_point:
			ai.weights[random_layer][random_neuron][random_weight] = low_point
	return ai

func randomize_biases(ai : Ai, strength : float = 0.4, amount : int = 1) -> Ai:
	for a in range(amount):
		rng.randomize()
		var random_layer := rng.randi_range(0, len(ai.biases) - 1)
		var random_neuron := rng.randi_range(0, len(ai.biases[random_layer]) - 1)
		
		ai.biases[random_layer][random_neuron] += rng.randf_range(-strength, strength)
		if ai.biases[random_layer][random_neuron] > clamp_biases:
			ai.biases[random_layer][random_neuron] = clamp_biases
		elif ai.biases[random_layer][random_neuron] < -clamp_biases:
			ai.biases[random_layer][random_neuron] = -clamp_biases
	return ai

func mutate(ai : Ai, w_strength : float = 0.1, b_strength : float = 0.4, w_amount : int = 1, b_amount : int = 1) -> Ai:
	ai = randomize_weights(ai, w_strength, w_amount)
	ai = randomize_biases(ai, b_strength, b_amount)
	return ai

func get_num_params(ai : Ai) -> Vector2i:
	var num_params := Vector2i.ZERO
	
	for layer in range(len(ai.layer_structure)):
		if not layer == 0:
			num_params.x += ai.layer_structure[layer] * ai.layer_structure[layer - 1]
			num_params.y += ai.layer_structure[layer]
	
	return num_params



# ----- Activation functions -----
func sigmoid(x : float) -> float:
	return 1 / (1 + exp(-x))

func relu(x : float) -> float:
	return max(x, 0.0)

func silu(x : float) -> float:
	return x / (1 + exp(-x))



# ---------- Save and Load AI ----------
func save(ai : Ai, overwrite : bool):
	setup_folders()
	var file_path := file_location + "/" + dir_name + "/" + ai.ai_name + file_extention
	
	if not overwrite:
		var version := 0
		while FileAccess.file_exists(file_path):
			version += 1
			file_path = file_location + "/" + dir_name + "/" + ai.ai_name + str(version) + file_extention
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	var ai_to_store := [
		ai.layer_structure,
		ai.weights,
		ai.biases,
		ai.high_score,
	]
	file.store_var(ai_to_store)
	file.close()

func open(ai_name : String, version := "") -> Ai:
	setup_folders()
	var file_path := file_location + "/" + dir_name + "/" + ai_name + version + file_extention
	var ai := init(ai_name, get_tree().root.get_node("Main").layer_structure)
	
	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		var stored_ai : Array = file.get_var()
		ai.layer_structure = stored_ai[0]
		ai.weights = stored_ai[1]
		ai.biases = stored_ai[2]
		if len(stored_ai) == 4:
			ai.high_score = stored_ai[3]
		file.close()
	
	return ai

func setup_folders():
	var dir := DirAccess.open(file_location)
	if not dir.dir_exists(dir_name):
		dir.make_dir(dir_name)



# ----- The Ai class -----
class Ai:
	# ----- AI info -----
	var ai_name := "default"
	var high_score := 0
	
	# ----- Layer structure -----
	var layer_structure : Array = []
	
	# ----- Weights and Biases -----
	var weights := []
	var biases := []
	
	
	# ----- Ai object functions -----
	func clone() -> Ai:
		# Creating a new ai object,
		# assigning the values from the old ai,
		# and returning the new ai.
		var new_ai := Ai.new()
		new_ai.ai_name = ai_name
		new_ai.high_score = high_score
		new_ai.layer_structure = layer_structure.duplicate(true)
		new_ai.weights = weights.duplicate(true)
		new_ai.biases = biases.duplicate(true)
		return new_ai
