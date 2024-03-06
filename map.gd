extends Node2D

const TILE_SIZE = 16
const PREDICTION = true

var socket = WebSocketPeer.new()
var url = 'ws://localhost:8080'

var ping_start_time = 0
var waiting_for_pong = false

var client_connected = false
var client_symbol = ''
var server_positions = {}
var players = {}

var scene = preload ("res://player.tscn")

func _ready():
	Engine.max_fps = 30
	
	socket.connect_to_url(url)

func _process(delta):
	$FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	
	socket.poll() # Upadates connection state
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:

		if !waiting_for_pong:
			ping_start_time = Time.get_ticks_msec()
			socket.send_text('i' + str(ping_start_time))
			waiting_for_pong = true

		if !client_connected:
			client_connected = true
			socket.send_text('cc') # Connect client
			
		# Listen
		while socket.get_available_packet_count(): # Gets number of packets in buffer
			var message = socket.get_packet().get_string_from_utf8()
			if message: # Message is empty if there are no players
				if message[0] == 'i': # Pong
					var ping_end_time = Time.get_ticks_msec()
					var ping = ping_end_time - ping_start_time
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
		server_positions = {}
		players = {}
		
		socket.connect_to_url(url)

func parse_positions(position_strings):
	var positions = position_strings.split(":")
	for position_string in positions:
		var parts = position_string.split(";")
		var symbol = parts[0].substr(1)
		var coordinates = parts[1].substr(1).split(",")
		var nInput = int(parts[2].substr(1))
		var x = int(coordinates[0])
		var y = int(coordinates[1])
		var pos = Vector2(x, y)
		if symbol in server_positions:
			server_positions[symbol][nInput] = pos
		else:
			server_positions[symbol] = {nInput: pos}

func players_from_positions():
	for symbol in server_positions.keys():
		var keys = server_positions[symbol].keys()
		keys.sort()
		var last_key = keys[-1] # Get the last key
		var tile_pos_server = server_positions[symbol][last_key]
		var pos = tile_pos_server * TILE_SIZE
		if players.has(symbol): # If player exists
			var player = players[symbol]
			if player.tile_pos != tile_pos_server:
				player.tile_pos_server = tile_pos_server
		else: # If player doesn't exist
			var player = scene.instantiate()
			player.position = pos
			player.tile_pos = tile_pos_server
			player.tile_pos_server = tile_pos_server
			player.client_symbol = client_symbol
			player.symbol = symbol
			if player.client_symbol == player.symbol:
				player.socket = socket
			add_child(player)
			players[symbol] = player # Store the player using its symbol as the key
