extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D

var move_speed = 200 # ms per tile
var percent_moved = 0.0
var processing_move = false
var tile_completed = true
var direction = Vector2.ZERO

var tile_pos = Vector2i.ZERO
var tile_pos_pxls = Vector2.ZERO
var tile_pos_inps_cln = {} # Buffer
var tile_pos_inps_srv = {} # Buffer

var last_recon_input = -1
var needs_correction

var socket
var client_symbol
var symbol
var owner_

func _ready():
	if client_symbol == symbol:
		owner_ = 'local'
	else:
		owner_ = 'remote'

func _physics_process(delta):
	if owner_ == 'local':
		if not processing_move:
			reconciliate_pos()
			process_input()
		elif processing_move:
			if tile_completed:
				tile_completed = false
				store_and_send_position()
			else: #? This else seems important to reduce lag
				move(delta)
	elif owner_ == 'remote':
		if not processing_move:
			process_input()
		elif processing_move:
			move(delta)

func process_input():
	if owner_ == 'local':
		if direction.y == 0:
			direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		if direction.x == 0:
			direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	elif owner_ == 'remote':
		if not tile_pos_inps_srv.is_empty():
			var key = tile_pos_inps_srv.keys()[0]
			direction = tile_pos_inps_srv[key] - tile_pos
			tile_pos_inps_srv.erase(key)

	if direction != Vector2.ZERO and (not will_collide(direction) or owner_ == 'remote'):
		tile_pos_pxls = position
		processing_move = true

		anim_tree.set("parameters/Idle/blend_position", direction)
		anim_tree.set("parameters/Walk/blend_position", direction)
		anim_tree.set("parameters/Walk Inv/blend_position", direction)
	else:
		anim_state.travel("Idle")

func move(delta):
	if not will_collide(direction) or owner_ == 'remote':
		percent_moved += (1000 / move_speed) * delta
		if percent_moved >= 1.0:
			percent_moved = 0.0
			position = tile_pos_pxls + (direction * Config.TILE_SIZE)
			tile_pos = position / Config.TILE_SIZE
			processing_move = false
			tile_completed = true
		else:
			position = tile_pos_pxls + (direction * Config.TILE_SIZE * percent_moved)
		anim_state.travel("Walk")
	else:
		percent_moved = 0.0
		position = tile_pos * Config.TILE_SIZE
		processing_move = false
		tile_completed = true

		var last_key = tile_pos_inps_cln.keys()[-1]
		tile_pos_inps_cln[last_key] = tile_pos
		if Config.DEBUG_POS:
			print(client_symbol, ' Corrected (client): ', tile_pos_inps_cln)

func store_and_send_position():
	# n = 0 is spawn position
	var n
	# No more inputs to reconcile
	if tile_pos_inps_cln.is_empty():
		n = last_recon_input + 1
	# There are still inputs to reconcile
	else:
		var last_key = tile_pos_inps_cln.keys()[-1]
		n = last_key + 1

	var new_tile_pos = tile_pos + direction
	
	tile_pos_inps_cln[n] = new_tile_pos
	socket.send_text('p' + str(n) + '-' + str(new_tile_pos.x) + ',' + str(new_tile_pos.y))
	if Config.DEBUG_POS:
		print(client_symbol, ' Sent: ', tile_pos_inps_cln)

func will_collide(target_dir):
	ray.target_position = target_dir * Config.TILE_SIZE / 2
	ray.force_raycast_update()
	if ray.is_colliding():
		return true
	return false

func reconciliate_pos():
	var inputs_to_erase = []
	for input in tile_pos_inps_srv:
		if input > last_recon_input:
			last_recon_input = input
			if tile_pos_inps_cln.has(input) and tile_pos_inps_cln[input] != tile_pos_inps_srv[input]:
				# Tile correction
				position = tile_pos_inps_srv[input] * Config.TILE_SIZE
				tile_pos = tile_pos_inps_srv[input]
				if Config.DEBUG_POS:
					print(client_symbol, ' Corrected (server): ', {input: tile_pos_inps_srv[input]})
			if Config.DEBUG_POS:
				print(client_symbol, ' Reconciled: ', input)
		inputs_to_erase.append(input)

	if not inputs_to_erase.is_empty():
		#? Why is this necessary?
		tile_pos_inps_cln = tile_pos_inps_cln.duplicate()

		for input in inputs_to_erase:
			tile_pos_inps_cln.erase(input)
			tile_pos_inps_srv.erase(input)
