extends CharacterBody2D

# @onready var anim_tree = $AnimationTree
# @onready var anim_state = anim_tree.get('parameters/playback')
@onready var ray = $RayCast2D

var move_speed = 100 # ms per tile
var percent_moved = 0

var tile_pos = Vector2i.ZERO

var srv_n_pos = {} # Buffer
var srv_n_pos_ftr = {}

var client_id
var id

func _physics_process(delta):
	if not srv_n_pos.is_empty():
		percent_moved += (1000 / move_speed) * delta

		var n_moves = Utils.get_sorted_keys(srv_n_pos)
		var n_1st = n_moves[0]
		var srv_pos_1st = srv_n_pos[n_1st]

		position = position.lerp(srv_pos_1st * Config.TILE_SIZE, percent_moved)

		if percent_moved >= 1:
			srv_n_pos.erase(n_1st)
			percent_moved = 0
