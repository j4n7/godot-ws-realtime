extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D

var walk_speed = 5.0 # Number of tiles per second
var percent_moved_to_next_tile = 0.0

var tile_pos = Vector2i.ZERO
var tile_pos_pixels = Vector2.ZERO
var tile_pos_server = Vector2.ZERO
var tile_pos_inputs = {}

var direction = Vector2.ZERO
var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
var collide_directions = []

var processing_move = false
var tile_moved = true

var socket
var client_symbol
var symbol

func _physics_process(delta):
	if client_symbol == symbol:
		if not processing_move:
			process_input('local')
		elif processing_move:
			if Config.PREDICTION:
				if tile_moved:
					tile_moved = false
					store_and_send_position()
				move(delta)
			else:
				# Before server confirmation
				if tile_moved:
					tile_moved = false
					store_and_send_position()
				# After server confirmation
				if tile_pos_server - tile_pos != Vector2.ZERO:
					move(delta)
	else:
		if not processing_move:
			process_input('remote')
		elif processing_move:
			move(delta)

func process_input(mode='local'):
	if mode == 'local':
		if direction.y == 0:
			direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		if direction.x == 0:
			direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	elif mode == 'remote':
		if not tile_pos_inputs.is_empty():
			var key = tile_pos_inputs.keys()[0]
			direction = tile_pos_inputs[key] - tile_pos
			tile_pos_inputs.erase(key)

	# Check for collisions in all directions
	collide_directions = []
	for dir in directions:
		var desired_step: Vector2 = dir * Config.TILE_SIZE / 2
		ray.target_position = desired_step
		ray.force_raycast_update()
		if ray.is_colliding():
			collide_directions.append(dir)

	if direction != Vector2.ZERO and direction not in collide_directions:
		tile_pos_pixels = position
		processing_move = true

		anim_tree.set("parameters/Idle/blend_position", direction)
		anim_tree.set("parameters/Walk/blend_position", direction)
		anim_tree.set("parameters/Walk Inv/blend_position", direction)
	else:
		anim_state.travel("Idle")

func move(delta):
	percent_moved_to_next_tile += walk_speed * delta
	if percent_moved_to_next_tile >= 1.0:
		percent_moved_to_next_tile = 0.0
		position = tile_pos_pixels + (direction * Config.TILE_SIZE)
		tile_pos = position / Config.TILE_SIZE
		tile_pos_server = tile_pos
		collide_directions = []
		processing_move = false
		tile_moved = true
	else:
		position = tile_pos_pixels + (direction * Config.TILE_SIZE * percent_moved_to_next_tile)
	anim_state.travel("Walk")

func move_instant():
	position = tile_pos_pixels + (direction * Config.TILE_SIZE)
	tile_pos = position / Config.TILE_SIZE
	tile_pos_server = tile_pos
	collide_directions = []
	processing_move = false
	tile_moved = true

func store_and_send_position(max_size=1):
	var new_tile_pos = tile_pos + direction
	var keys = tile_pos_inputs.keys()
	var n = keys[- 1] + 1 if keys else 1
	tile_pos_inputs[n] = new_tile_pos
	socket.send_text('p' + str(n) + '-' + str(new_tile_pos.x) + ',' + str(new_tile_pos.y))
	Utils.trim_dictionary(tile_pos_inputs, max_size)
