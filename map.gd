extends Node2D

const TILE_SIZE = 16

var socket = WebSocketPeer.new()
var url = 'ws://localhost:8080'

var client_connected = false
var client_symbol = ''
var tiles = []
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
			if message[0] == 's':
				client_symbol = message[1]
			else:
				import_tiles(message)
				players_from_tiles()
			
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		client_connected = false
		client_symbol = ''
		tiles = []
		players = {}
		
		socket.connect_to_url(url)

func import_tiles(tiles_string):
	var rows = tiles_string.split("\n")
	tiles = []
	for row in rows:
		tiles.append(row.split(""))

func players_from_tiles():
	for i in range(len(tiles)):
		for j in range(len(tiles[i])):
			if tiles[i][j] == '@' or tiles[i][j] == '&':
				var tile_pos = Vector2(j, i)
				var pos = tile_pos * TILE_SIZE
				var symbol = tiles[i][j]
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
