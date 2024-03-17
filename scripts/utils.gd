class_name Utils

static func trim_buffer(dict, n):
	var keys = dict.keys()
	keys.sort()
	if dict.size() == n + 1:
		var key_to_remove = keys[0]
		dict.erase(key_to_remove)
		keys.remove_at(0)
	return dict

static func get_server_adress():
	var file = FileAccess.open('res://server_address.txt', FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	return content

static func random_int(min_=0, max_=100):
	var rng = RandomNumberGenerator.new()
	return rng.randi_range(min_, max_)

static func get_sorted_keys(dict):
	var keys = dict.keys()
	keys.sort()
	return keys
