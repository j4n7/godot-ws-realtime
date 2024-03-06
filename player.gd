extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D

const TILE_SIZE = 16
const PREDICTION = true

var walk_speed = 5.0 # Number of tiles per second
var percent_moved_to_next_tile = 0.0

var tile_pos = Vector2i.ZERO
var tile_pos_pixels = Vector2.ZERO
var tile_pos_server = Vector2.ZERO

var direction = Vector2.ZERO
var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
var collide_directions = []

var process_move = false
var tile_moved = true

var socket
var client_symbol
var symbol

var ball_positions = {} # Local

func _physics_process(delta):
	if client_symbol == symbol:
		if not process_move:
			process_input('local')
		elif process_move:
			if PREDICTION:
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
		if not process_move:
			process_input('remote')
		elif direction != Vector2.ZERO:
			move(delta)
		else:
			process_move = false

func process_input(mode='local'):
	if mode == 'local':
		if direction.y == 0:
			direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		if direction.x == 0:
			direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	elif mode == 'remote':
		direction = tile_pos_server - tile_pos

	#? Check for collisions in all directions
	#? Movement is handled differently than in a popular GB game
	collide_directions = []
	for dir in directions:
		var desired_step : Vector2 = dir * TILE_SIZE / 2
		ray.target_position = desired_step
		ray.force_raycast_update()
		if ray.is_colliding():
			collide_directions.append(dir)

	if direction != Vector2.ZERO and direction not in collide_directions:
		tile_pos_pixels = position
		process_move = true

		anim_tree.set("parameters/Idle/blend_position", direction)
		anim_tree.set("parameters/Walk/blend_position", direction)
		anim_tree.set("parameters/Walk Inv/blend_position", direction)
	else:
		anim_state.travel("Idle")

func move(delta):
	percent_moved_to_next_tile += walk_speed * delta
	if percent_moved_to_next_tile >= 1.0:
		percent_moved_to_next_tile = 0.0
		position = tile_pos_pixels + (direction * TILE_SIZE)
		tile_pos = (position / TILE_SIZE).floor()
		tile_pos_server = tile_pos
		collide_directions = []
		process_move = false
		tile_moved = true
	else:
		position = tile_pos_pixels + (direction * TILE_SIZE * percent_moved_to_next_tile)
	anim_state.travel("Walk")

func store_and_send_position():
	var new_tile_pos = tile_pos + direction
	var n = str(ball_positions.size() + 1) # Get the next key for the dictionary
	ball_positions[n] = new_tile_pos
	socket.send_text('p' + n + ';' + str(new_tile_pos.x) + ',' + str(new_tile_pos.y))
