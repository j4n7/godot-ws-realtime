extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D

const TILE_SIZE = 16

var walk_speed = 5.0 # Number of tiles per second

var direction_keys = []
var initial_position = Vector2(0, 0)
var tile_position = Vector2i(0, 0)
var input_direction = Vector2(0, 0)

var can_move = true
var is_moving = false
var percent_moved_to_next_tile = 0.0
var walk_inv = false # ! Not working properly

var socket
var client_symbol
var symbol
var direction = Vector2.ZERO
var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
var collide_directions = []
var player_positions = {} # Local

func _physics_process(delta):
	if client_symbol == symbol:
		if !is_moving:
			#? Check for collisions in all directions
			#? Movement is handled differently than in a popular GB game
			collide_directions = []
			for dir in directions:
				var desired_step : Vector2 = dir * TILE_SIZE / 2
				ray.target_position = desired_step
				ray.force_raycast_update()
				if ray.is_colliding():
					collide_directions.append(dir)
			process_player_input('local')
		elif input_direction != Vector2.ZERO and input_direction not in collide_directions:
			# Before server confirmation
			if can_move:
				can_move = false
				var new_position = tile_position + input_direction
				var n = str(player_positions.size() + 1) # Get the next key for the dictionary
				player_positions[n] = new_position
				socket.send_text('p' + n + ';' + str(new_position.x) + ',' + str(new_position.y))
			# After server confirmation
			if direction != Vector2.ZERO:
				move(delta)
				if walk_inv:
					anim_state.travel("Walk Inv")
				else:
					anim_state.travel("Walk")
		else:
			anim_state.travel("Idle")
			is_moving = false
	else:
		if !is_moving:
			process_player_input('remote')
		elif input_direction != Vector2.ZERO:
			move(delta)
			if walk_inv:
				anim_state.travel("Walk Inv")
			else:
				anim_state.travel("Walk")
		else:
			anim_state.travel("Idle")
			is_moving = false

func process_player_input(mode='local'):
	if mode == 'local':
		if input_direction.y == 0:
			input_direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		if input_direction.x == 0:
			input_direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	else:
		input_direction = direction

	if input_direction != Vector2.ZERO:
		anim_tree.set("parameters/Idle/blend_position", input_direction)
		anim_tree.set("parameters/Walk/blend_position", input_direction)
		anim_tree.set("parameters/Walk Inv/blend_position", input_direction)
		initial_position = position
		is_moving = true
	else:
		anim_state.travel("Idle")
		walk_inv = !walk_inv

func move(delta):
	percent_moved_to_next_tile += walk_speed * delta
	if percent_moved_to_next_tile >= 1.0:
		percent_moved_to_next_tile = 0.0
		position = initial_position + (input_direction * TILE_SIZE)
		tile_position = (position / TILE_SIZE).floor()
		direction = Vector2.ZERO
		collide_directions = []
		is_moving = false
		can_move = true
	else:
		position = initial_position + (input_direction * TILE_SIZE * percent_moved_to_next_tile)
