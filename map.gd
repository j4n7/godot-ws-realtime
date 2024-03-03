extends Node2D

const TILE_SIZE = 16

var socket = WebSocketPeer.new()
var url = 'ws://localhost:8080'

var client_connected = false
var client_symbol = ''
var server_positions = {}
var players = {}

var scene = preload("res://player.tscn")


func _ready():
	socket.connect_to_url(url)


func _process(delta):
	socket.poll()  # Upadates connection state
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if !client_connected:
			client_connected = true
			socket.send_text('cc')
			
		# Listen
		if socket.get_available_packet_count():  # Gets number of packets in buffer
			var message = socket.get_packet().get_string_from_utf8()
			if message: # Message is empty if there are no players
				if message[0] == 'a':
					client_symbol = message[1]
				else:
					import_positions(message)
					players_from_positions()
			
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		client_connected = false
		client_symbol = ''
		server_positions = {}
		players = {}
		
		socket.connect_to_url(url)

func import_positions(positions_string):
	# Split the string into an array of position strings
	var position_strings = positions_string.split(":")
	
	# Clear the positions dictionary
	server_positions.clear()
	
	# Iterate over each position string
	for position_string in position_strings:
		# Split the position string into symbol and position parts
		var parts = position_string.split(";")
		
		# Extract the symbol
		var symbol = parts[0].substr(1)
		
		# Extract the x and y coordinates
		var coordinates = parts[1].substr(1).split(",")
		var x = int(coordinates[0])
		var y = int(coordinates[1])
		
		# Update the positions dictionary
		server_positions[symbol] = Vector2(x, y)

func players_from_positions():
	for symbol in server_positions.keys():
		var tile_pos = server_positions[symbol]
		var pos = tile_pos * TILE_SIZE

		if players.has(symbol):  # If player exists
			var player = players[symbol]
			if player.tile_position != tile_pos:
				player.direction = tile_pos - player.tile_position
		else:  # If player doesn't exist
			var player = scene.instantiate()
			player.position = pos
			player.tile_position = tile_pos
			player.client_symbol = client_symbol
			player.symbol = symbol
			if player.client_symbol == player.symbol:
				player.socket = socket
			add_child(player)
			players[symbol] = player  # Store the player using its symbol as the key
