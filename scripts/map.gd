extends Node2D

@onready var url = 'ws://' + Utils.get_server_adress()

var socket = WebSocketPeer.new()

var ping_t0_time = 0
var waiting_for_pong = false

var client_connected = false
var client_symbol = ''
var players = {}
var tile_pos_time_srv = {}

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
					client_symbol = message[1]
				else:
					parse_positions(message)
					players_from_positions()
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		client_connected = false
		client_symbol = ''
		tile_pos_time_srv = {}
		players = {}
		
		socket.connect_to_url(url)

func parse_positions(position_strings):
	var positions = position_strings.split("|")
	var time = int(positions[0])
	var snapshot = {}
	if positions[1]:
		for i in range(1, len(positions)):
			var position_string = positions[i]
			var parts = position_string.split("-")
			var nInput = int(parts[0])
			var symbol = parts[1]
			var coordinates = parts[2].split(",")
			var x = int(coordinates[0])
			var y = int(coordinates[1])
			var tile_pos = Vector2(x, y)
			snapshot[symbol] = {nInput: tile_pos}
	tile_pos_time_srv[time] = snapshot
	Utils.trim_buffer(tile_pos_time_srv, Config.SNAPSHOT_BUFFER)

func players_from_positions():
	var time = tile_pos_time_srv.keys()[0]
	var snapshot = tile_pos_time_srv[time]
	var symbols_to_remove = []
	for symbol in snapshot.keys():
		if snapshot[symbol].is_empty(): # If player has disconnected
			symbols_to_remove.append(symbol)
			continue
		var input = snapshot[symbol].keys()[0]
		var tile_pos_srv = snapshot[symbol][input]
		if players.has(symbol): # If player exists
			var player = players[symbol]
			player.tile_pos_inps_srv[input] = tile_pos_srv
		else: # If player doesn't exist
			var player = scene.instantiate()
			player.position = tile_pos_srv * Config.TILE_SIZE
			player.tile_pos = tile_pos_srv
			player.tile_pos_inps_cln = snapshot[symbol]
			player.tile_pos_inps_srv = snapshot[symbol]
			player.client_symbol = client_symbol
			player.symbol = symbol
			if player.client_symbol == player.symbol:
				player.socket = socket
			add_child(player)
			players[symbol] = player # Store the player using its symbol as the key
	for symbol in symbols_to_remove: # Delete disconnected players
		snapshot.erase(symbol)
		players[symbol].queue_free()
		players.erase(symbol)
