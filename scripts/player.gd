extends CharacterBody2D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D

var walk_speed = 5.0 # Number of tiles per second
var percent_moved_to_next_tile = 0.0

var tile_pos = Vector2i.ZERO
var tile_pos_pxls = Vector2.ZERO
var tile_pos_inps_cln = {}
var tile_pos_inps_srv = {}

var direction = Vector2.ZERO
var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

var last_recon_input = -1
var needs_correction

var processing_move = false
var tile_completed = true

var socket
var client_symbol
var symbol

func _physics_process(delta):
	if client_symbol == symbol:
		if not processing_move:
			needs_correction = reconciliate_pos()
			if not needs_correction:
				process_input('local')
			else:
				move_correct()
			if tile_pos_inps_cln.has(last_recon_input):
				tile_pos_inps_cln.erase(last_recon_input)
			tile_pos_inps_srv.erase(last_recon_input)
		elif processing_move:
			if tile_completed:
				tile_completed = false
				store_and_send_position()
			else: #? This else seems important to reduce lag
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
		if not tile_pos_inps_srv.is_empty():
			var key = tile_pos_inps_srv.keys()[0]
			direction = tile_pos_inps_srv[key] - tile_pos
			tile_pos_inps_srv.erase(key)

	if direction != Vector2.ZERO and not will_collide(direction):
		tile_pos_pxls = position
		processing_move = true

		anim_tree.set("parameters/Idle/blend_position", direction)
		anim_tree.set("parameters/Walk/blend_position", direction)
		anim_tree.set("parameters/Walk Inv/blend_position", direction)
	else:
		anim_state.travel("Idle")

func move(delta):
	if not will_collide(direction):
		percent_moved_to_next_tile += walk_speed * delta
		if percent_moved_to_next_tile >= 1.0:
			percent_moved_to_next_tile = 0.0
			position = tile_pos_pxls + (direction * Config.TILE_SIZE)
			tile_pos = position / Config.TILE_SIZE
			processing_move = false
			tile_completed = true
		else:
			position = tile_pos_pxls + (direction * Config.TILE_SIZE * percent_moved_to_next_tile)
		anim_state.travel("Walk")
	else:
		percent_moved_to_next_tile = 0.0
		position = tile_pos * Config.TILE_SIZE
		processing_move = false
		tile_completed = true

func move_instant():
	position = tile_pos_pxls + (direction * Config.TILE_SIZE)
	tile_pos = position / Config.TILE_SIZE
	processing_move = false
	tile_completed = true

func move_correct():
	var key = tile_pos_inps_srv.keys()[0]
	var tile_pos_srv = tile_pos_inps_srv[key]
	tile_pos_inps_cln[key] = tile_pos_srv
	position = tile_pos_srv * Config.TILE_SIZE
	tile_pos = tile_pos_srv

func store_and_send_position():
	var new_tile_pos = tile_pos + direction
	var n = last_recon_input + 1
	tile_pos_inps_cln[n] = new_tile_pos
	socket.send_text('p' + str(n) + '-' + str(new_tile_pos.x) + ',' + str(new_tile_pos.y))
	if Config.DEBUG_POS:
		print(client_symbol, ' Pending: ', tile_pos_inps_cln)

func will_collide(dir):
	# Check for collisions in all directions
	for dir_ in directions:
		var desired_step: Vector2 = dir_ * Config.TILE_SIZE / 2
		ray.target_position = desired_step
		ray.force_raycast_update()
		if ray.is_colliding() and dir_ == dir:
			return true
	return false

func reconciliate_pos():
	var result = false
	if tile_pos_inps_srv.size() == 1:
		var key = tile_pos_inps_srv.keys()[0]
		if key > last_recon_input:
			last_recon_input = key
			if tile_pos_inps_cln.has(key) and tile_pos_inps_cln[key] != tile_pos_inps_srv[key]:
				result = true
			if Config.DEBUG_POS:
				print(client_symbol, ' Server: ', tile_pos_inps_srv)
				print(client_symbol, ' Client: ', tile_pos_inps_cln)
				print(client_symbol, ' Reconciliated: ', key)
	return result
