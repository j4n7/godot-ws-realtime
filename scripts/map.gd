extends Node2D

@onready var url = 'ws://' + Utils.get_server_adress()

var socket = WebSocketPeer.new()

var ping_t0_time = 0
var waiting_for_pong = false

var client_connected = false
var client_id = ''
var players = {}
var tile_pos_time_srv = {} # Only stores one position for snapshot and player

var scene = preload ("res://scenes/player.tscn")

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
					parse_positions(message)
					players_from_positions()
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		client_connected = false
		client_id = ''
		tile_pos_time_srv = {}
		players = {}
		
		socket.connect_to_url(url)

func parse_positions(position_strings):
	var positions = position_strings.split("=")
	var time = int(positions[0])
	var player_info = positions[1].split("|").slice(1)
	var enemy_info = positions[2].split("|").slice(1)
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

	tile_pos_time_srv[time] = snapshot['players']
	Utils.trim_buffer(tile_pos_time_srv, Config.SNAPSHOT_BUFFER)


func players_from_positions():
	var time = tile_pos_time_srv.keys()[0]
	var snapshot = tile_pos_time_srv[time]
	var time_ftr = tile_pos_time_srv.keys()[-1]
	var snapshot_ftr = tile_pos_time_srv[time_ftr]

	var ids_to_remove = []
	for id in snapshot.keys():
		if snapshot[id].is_empty(): # If player has disconnected
			ids_to_remove.append(id)
			continue

		var input = snapshot[id].keys()[0]
		var tile_pos_srv = snapshot[id][input]
		var input_ftr = snapshot_ftr[id].keys()[0]
		var tile_pos_srv_ftr = snapshot_ftr[id][input_ftr]

		if players.has(id): # If player exists
			var player = players[id]
			player.tile_pos_inps_srv[input] = tile_pos_srv
			player.tile_pos_inps_srv_ftr[input_ftr] = tile_pos_srv_ftr
		else: # If player doesn't exist
			var player = scene.instantiate()
			player.position = tile_pos_srv * Config.TILE_SIZE
			player.tile_pos = tile_pos_srv
			player.tile_pos_inps_cln = snapshot[id]
			player.tile_pos_inps_srv = snapshot[id]
			player.tile_pos_inps_srv_ftr = snapshot_ftr[id]
			player.client_id = int(client_id)
			player.id = int(id)
			if player.client_id == player.id:
				player.socket = socket
			add_child(player)
			players[id] = player # Store the player using its id as the key
	for id in ids_to_remove: # Delete disconnected players
		snapshot.erase(id)
		players[id].queue_free()
		players.erase(id)
