extends CharacterBody2D


@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

const TILE_SIZE = 16

var walk_speed = 5.0 # Number of tiles per second

var direction_keys = []
var initial_position = Vector2(0, 0)
var tile_position = Vector2i(0, 0)
var input_direction = Vector2(0, 0)

var tile_moved = true # If player has just moved to a new tile
var is_moving = false
var percent_moved_to_next_tile = 0.0
var walk_inv = false  #! Not working properly

var socket
var client_symbol
var symbol
var direction = Vector2.ZERO


func _physics_process(delta):
	if client_symbol == symbol:
		if !is_moving:
			process_player_input('local')
		elif input_direction != Vector2.ZERO:
			# Before server confirmation
			if tile_moved:
				tile_moved = false
				if input_direction == Vector2(1, 0):
					socket.send_text('r')
				elif input_direction == Vector2(-1, 0):
					socket.send_text('l')
				elif input_direction == Vector2(0, 1):
					socket.send_text('d')
				elif input_direction == Vector2(0, -1):
					socket.send_text('u')

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
		is_moving = false
		tile_moved = true
	else:
		position = initial_position + (input_direction * TILE_SIZE * percent_moved_to_next_tile)
