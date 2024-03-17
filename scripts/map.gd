extends Node2D

@onready var url = 'ws://' + Utils.get_server_adress()

var socket = WebSocketPeer.new()

var ping_t0_time = 0
var waiting_for_pong = false

var client_connected = false
var client_id = ''
var srv_snapshots = {} # Only stores one position per snapshot

var players = {}
var enemies = {}

var scene_player = preload("res://scenes/player.tscn")
var scene_enemy = preload("res://scenes/enemy.tscn")

func _ready():
	Engine.max_fps = 30

	socket.connect_to_url(url)

func _process(delta):
	$FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	
	socket.poll() # Upadates connection state
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:

		if !waiting_for_pong:
			ping_t0_time = Time.get_ticks_msec()
			socket.send_text('i' + str(ping_t0_time))
			waiting_for_pong = true

		if !client_connected:
			client_connected = true
			socket.send_text('cc') # Connect client
			
		# Listen
		while socket.get_available_packet_count(): # Gets number of packets in buffer
			var message = socket.get_packet().get_string_from_utf8()
			if message: # Message is empty if there are no players
				if message[0] == 'i': # Pong
					var ping_t1_time = Time.get_ticks_msec()
					var ping = ping_t1_time - ping_t0_time
					$Lag.text = "Lag: " + str(ping) + " ms"
					waiting_for_pong = false
				elif message[0] == 'a': # Added client
					client_id = message.substr(1)
				else:
					parse_message(message)
					enemies_from_snaps()
					players_from_snaps()
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		client_connected = false
		client_id = ''
		srv_snapshots = {}
		players = {}
		enemies = {}
		
		socket.connect_to_url(url)

func parse_message(message):
	var parts = message.split("=")
	var time = int(parts[0])
	var player_info = parts[1].split("|").slice(1)
	var enemy_info = parts[2].split("|").slice(1)
	var snapshot = {'players': {}, 'enemies': {}}

	for player in player_info:
		if player:
			var info = player.split("-")
			var id = int(info[0])
			var n_input = int(info[1])
			var coordinates = info[2].split("·")
			var x = int(coordinates[0])
			var y = int(coordinates[1])
			var tile_pos = Vector2(x, y)
			snapshot['players'][id] = {n_input: tile_pos}
	
	for enemy in enemy_info:
		if enemy:
			var info = enemy.split("-")
			var id = int(info[0])
			var type = int(info[1])
			var coordinates = info[2].split("·")
			var x = int(coordinates[0])
			var y = int(coordinates[1])
			var tile_pos = Vector2(x, y)
			snapshot['enemies'][id] = {type: tile_pos}

	srv_snapshots[time] = snapshot
	Utils.trim_buffer(srv_snapshots, Config.SNAPSHOT_BUFFER)


func players_from_snaps():
	var time = srv_snapshots.keys()[0]
	var snapshot = srv_snapshots[time]
	var enem_snap = snapshot['players']

	var time_ftr = srv_snapshots.keys()[-1]
	var snapshot_ftr = srv_snapshots[time_ftr]
	var enem_snap_ftr = snapshot_ftr['players']

	var ids_to_remove = []
	for id in enem_snap.keys():
		if enem_snap[id].is_empty(): # If player has disconnected
			ids_to_remove.append(id)
			continue

		var inpt = enem_snap[id].keys()[0]
		var srv_pos = enem_snap[id][inpt]
		var inpt_ftr = enem_snap_ftr[id].keys()[0]
		var srv_pos_ftr = enem_snap_ftr[id][inpt_ftr]

		if players.has(id): # If player exists
			var player = players[id]
			player.srv_inpt_pos[inpt] = srv_pos
			player.srv_inpt_pos_ftr[inpt_ftr] = srv_pos_ftr
		else: # If player doesn't exist
			var player = scene_player.instantiate()
			player.socket = socket if player.client_id == player.id else null
			player.client_id = int(client_id)
			player.id = int(id)

			player.position = srv_pos * Config.TILE_SIZE
			player.tile_pos = srv_pos

			player.cln_inpt_pos = enem_snap[id]
			player.srv_inpt_pos = enem_snap[id]
			player.srv_inpt_pos_ftr = enem_snap_ftr[id]

			add_child(player)
			players[id] = player # Store the player using its id as the key
	for id in ids_to_remove: # Delete disconnected players
		enem_snap.erase(id)
		players[id].queue_free()
		players.erase(id)

func enemies_from_snaps():
	var time = srv_snapshots.keys()[0]
	var snapshot = srv_snapshots[time]
	var enem_snap = snapshot['enemies']

	var time_ftr = srv_snapshots.keys()[-1]
	var snapshot_ftr = srv_snapshots[time_ftr]
	var enem_snap_ftr = snapshot_ftr['enemies']

	var ids_to_remove = []
	for id in enem_snap.keys():
		if enem_snap[id].is_empty():
			ids_to_remove.append(id)
			continue

		var n = enem_snap[id].keys()[0]
		var srv_pos = enem_snap[id][n]
		var n_ftr = enem_snap_ftr[id].keys()[0]
		var srv_pos_ftr = enem_snap_ftr[id][n_ftr]

		if enemies.has(id): # If enemy exists
			var enemy = enemies[id]
			enemy.srv_n_pos[n] = srv_pos
			enemy.srv_n_pos_ftr[n_ftr] = srv_pos_ftr
		else: # If enemy doesn't exist
			var enemy = scene_enemy.instantiate()

			enemy.client_id = int(client_id)
			enemy.id = int(id)

			enemy.position = srv_pos * Config.TILE_SIZE
			enemy.tile_pos = srv_pos

			enemy.srv_n_pos = enem_snap[id]
			enemy.srv_n_pos_ftr = enem_snap_ftr[id]

			add_child(enemy)
			enemies[id] = enemy # Store the enemy using its id as the key
	for id in ids_to_remove: # Delete disconnected enemies
		enem_snap.erase(id)
		enemies[id].queue_free()
		enemies.erase(id)
