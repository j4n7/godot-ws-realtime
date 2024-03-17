extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get('parameters/playback')
@onready var ray = $RayCast2D

var move_speed = 250 # ms per tile
var percent_moved = 0.0
var processing_move = false
var tile_completed = true
var direction = Vector2.ZERO

var just_stop = true
var walk_inv = false

var tile_pos = Vector2i.ZERO
var tile_pos_pxls = Vector2.ZERO
var cln_inpt_pos = {} # Buffer
var srv_inpt_pos = {} # Buffer
var srv_inpt_pos_ftr = {}

var last_recon_input = -1
var needs_correction

var socket
var client_id
var id
var owner_

func _ready():
	if client_id == id:
		owner_ = 'local'
	else:
		owner_ = 'remote'

func _physics_process(delta):
	if owner_ == 'local':
		if not processing_move:
			reconciliate_pos()
			process_cln_inpt()
		elif processing_move:
			if tile_completed:
				tile_completed = false
				store_and_send_pos()
			else: # ? This else seems important to reduce lag
				move(delta)
	elif owner_ == 'remote':
		if not processing_move:
			process_srv_inpt()
		elif processing_move:
			move(delta)

func set_anim_dir(dir):
	anim_tree.set('parameters/Idle/blend_position', dir)
	anim_tree.set('parameters/Walk/blend_position', dir)
	anim_tree.set('parameters/Walk Inv/blend_position', dir)

func set_starting_foot():
	if not just_stop:
		just_stop = true
		walk_inv = not walk_inv

func process_cln_inpt():
	if direction.y == 0:
		direction.x = int(Input.is_action_pressed('ui_right')) - int(Input.is_action_pressed('ui_left'))
	if direction.x == 0:
		direction.y = int(Input.is_action_pressed('ui_down')) - int(Input.is_action_pressed('ui_up'))

	# While pressing key, this is true
	if direction != Vector2.ZERO and not will_collide(direction):
		tile_pos_pxls = position
		processing_move = true
		set_anim_dir(direction)
	else:
		anim_state.travel('Idle')
		set_starting_foot()

func process_srv_inpt():
	# If a new input arrives while player is still moving, it will not be processed
	# In that case, input buffer will contain at least 2 inputs: current one and next one
	# It can contain: 0, 1 or 2 inputs (maybe more if lag is too high)

	var keep_moving
	if not srv_inpt_pos.is_empty():
		var inpts = Utils.get_sorted_keys(srv_inpt_pos)

		var inpt_2nd = inpts[-1]
		var srv_pos_2nd = srv_inpt_pos[inpt_2nd]
		direction = srv_pos_2nd - tile_pos

		var inpt_1st = inpts[0]
		var srv_pos_1st = srv_inpt_pos[inpt_1st]

		var inpts_ftr = Utils.get_sorted_keys(srv_inpt_pos_ftr)

		var inpt_ftr = inpts_ftr[-1]
		var srv_pos_ftr = srv_inpt_pos_ftr[inpt_ftr]
		keep_moving = true if srv_pos_ftr - srv_pos_1st != Vector2.ZERO else false

		srv_inpt_pos = {}
		srv_inpt_pos_ftr = {}

	if direction != Vector2.ZERO:
		tile_pos_pxls = position
		processing_move = true
		set_anim_dir(direction)
	elif keep_moving:
		pass
	else:
		anim_state.travel('Idle')
		set_starting_foot()

func move(delta):
	just_stop = false

	if not will_collide(direction) or owner_ == 'remote' or not Config.COLLISION_PREDICTION:
		percent_moved += (1000 / move_speed) * delta
		if percent_moved >= 1.0:
			percent_moved = 0.0
			position = tile_pos_pxls + (direction * Config.TILE_SIZE)
			tile_pos = position / Config.TILE_SIZE
			processing_move = false
			tile_completed = true
		else:
			position = tile_pos_pxls + (direction * Config.TILE_SIZE * percent_moved)
		if walk_inv:
			anim_state.travel('Walk Inv')
		else:
			anim_state.travel('Walk')
	else:
		percent_moved = 0.0
		position = tile_pos * Config.TILE_SIZE
		processing_move = false
		tile_completed = true

		var inpts = Utils.get_sorted_keys(cln_inpt_pos)
		var last_intp = inpts[-1]
		cln_inpt_pos[last_intp] = tile_pos
		if Config.DEBUG_POS:
			print(client_id, ' Corrected (client): ', cln_inpt_pos)

func store_and_send_pos():
	# n = 0 is spawn position
	var n
	# No more inputs to reconcile
	if cln_inpt_pos.is_empty():
		n = last_recon_input + 1
	# There are still inputs to reconcile
	else:
		var inpts = Utils.get_sorted_keys(cln_inpt_pos)
		var last_intp = inpts[-1]		
		n = last_intp + 1

	var new_tile_pos = tile_pos + direction
	
	cln_inpt_pos[n] = new_tile_pos
	socket.send_text('p' + str(n) + '-' + str(new_tile_pos.x) + '·' + str(new_tile_pos.y))
	if Config.DEBUG_POS:
		print(client_id, ' Sent: ', cln_inpt_pos)

func will_collide(target_dir):
	ray.target_position = target_dir * Config.TILE_SIZE / 2
	ray.force_raycast_update()
	if ray.is_colliding():
		return true
	return false

func reconciliate_pos():
	var inputs_to_erase = []
	for input in srv_inpt_pos:
		if input > last_recon_input:
			last_recon_input = input
			if cln_inpt_pos.has(input) and cln_inpt_pos[input] != srv_inpt_pos[input]:
				# Tile correction
				position = srv_inpt_pos[input] * Config.TILE_SIZE
				tile_pos = srv_inpt_pos[input]
				if Config.DEBUG_POS:
					print(client_id, ' Corrected (server): ', {input: srv_inpt_pos[input]})
			if Config.DEBUG_POS:
				print(client_id, ' Reconciled: ', input)
		inputs_to_erase.append(input)

	#? This can probably be optimized using a while loop
	if not inputs_to_erase.is_empty():
		#? Why is this necessary?
		cln_inpt_pos = cln_inpt_pos.duplicate()

		for input in inputs_to_erase:
			cln_inpt_pos.erase(input)
			srv_inpt_pos.erase(input)
