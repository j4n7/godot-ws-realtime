class_name Utils

static func trim_dictionary(dict, n):
	var keys = dict.keys()
	while dict.size() > n:
		var key_to_remove = keys[0]
		dict.erase(key_to_remove)
		keys.remove_at(0)
	return dict