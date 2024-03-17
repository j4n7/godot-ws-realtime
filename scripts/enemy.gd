extends CharacterBody2D

# @onready var anim_tree = $AnimationTree
# @onready var anim_state = anim_tree.get('parameters/playback')
@onready var ray = $RayCast2D

var tile_pos = Vector2i.ZERO
var tile_pos_pxls = Vector2.ZERO

var srv_n_pos = {} # Buffer
var srv_n_pos_ftr = {}

var client_id
var id

var t = 0

func _physics_process(delta):
	if not srv_n_pos.is_empty():
		t += delta / 0.1

		var keys = srv_n_pos.keys()
		keys.sort()
		var n_1st = keys[0]
		var srv_pos_1st = srv_n_pos[n_1st]

		position = position.lerp(srv_pos_1st * Config.TILE_SIZE, t)

		if t >= 1:
			srv_n_pos.erase(n_1st)
			t = 0

		print(position)
