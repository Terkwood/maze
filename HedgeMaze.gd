extends Spatial

# the bits in each cell describe those directions in which 
# passages have been carved
enum Passages {
	N = 1,
	S = 2,
	E = 4,
	W = 8
}

enum DX {
	E = 1,
	W = -1,
	N = 0,
	S = 0
}

enum DY {
	E = 0,
	W = 0,
	N = -1,
	S = 1
}

enum Opposite {
	E = Passages.W,
	W = Passages.E,
	N = Passages.S,
	S = Passages.N
}

export(int) var width = 10
export(int) var height = width

# This should be a Static Body with a BoxShape for collision
#  Its X value should be the long side,
#  Its Z value should be the short side.
#  We focus on the X value for placing the wall.
#
# THIS SCENE MUST ALSO EXPOSE A .size() method which returns
# the dimensions of the body.  The full dimensions of the mesh!
# NOT the halved extents of a collision shape !
onready var WallBody = preload("res://WallBody.tscn")

var _passages_grid = _create_grid(0)


func _carve_passages_from(cx: int, cy: int):
	var directions = [ Passages.N, Passages.S, Passages.E, Passages.W ]
	directions.shuffle()
	
	for direction in directions:
		var nx = cx + _dx(direction)
		var ny = cy + _dy(direction)
	
		var is_ny_in_passages_grid = ny >= 0 && ny < _passages_grid.size()
		var is_nx_in_passages_grid = nx >= 0 && ny < _passages_grid.size() && nx < _passages_grid[ny].size()
		if is_ny_in_passages_grid && is_nx_in_passages_grid && _passages_grid[ny][nx] == 0:
			_passages_grid[cy][cx] = _passages_grid[cy][cx] | direction
			_passages_grid[ny][nx] = _passages_grid[ny][nx] | _opposite(direction)
			_carve_passages_from(nx, ny)

func _ready():
	randomize()
	_carve_passages_from(0, 0)
	_print_ascii()
	_place_walls()

func _create_grid(default) -> Array:
	var outer = []
	outer.resize(height)
	for i in range(height):
		var inner = []
		inner.resize(width)
		for z in range(width):
			inner[z] = default
		outer[i] = inner
	return outer

func _dx(passages: int):
	match passages:
		Passages.N:
			return DX.N
		Passages.S:
			return DX.S
		Passages.E:
			return DX.E
		Passages.W:
			return DX.W

func _dy(passages: int):
	match passages:
		Passages.N:
			return DY.N
		Passages.S:
			return DY.S
		Passages.E:
			return DY.E
		Passages.W:
			return DY.W

func _opposite(passages: int):
	match passages:
		Passages.N:
			return Opposite.N
		Passages.S:
			return Opposite.S
		Passages.E:
			return Opposite.E
		Passages.W:
			return Opposite.W
func _wall_dir(passages: int):
	match passages:
		Passages.N:
			return WallDir.N
		Passages.S:
			return WallDir.S
		Passages.E:
			return WallDir.E
		Passages.W:
			return WallDir.W
	

func _print_ascii():
	print(" %s" % "_".repeat(width * 2 - 1))
	var next = ""
	for y in range(0,height):
		next += "|"
		for x in range(0,width):
			next += " " if (_passages_grid[y][x] & Passages.S != 0) else "_"
			if _passages_grid[y][x] & Passages.E != 0:
				if _passages_grid.size() > y && _passages_grid[y].size() > x + 1:
					next += " " if ((_passages_grid[y][x] | _passages_grid[y][x+1]) & Passages.S != 0) else "_"
				else:
					next += "_"
			else:
				next += "|"
		print(next)
		next = ""


# walls should be placed on those directions in which passages
# _have not_ been carved
func _place_walls():
	for h in range(0,height):
		for w in range(0,width):
			var wds = _walls_from(_passages_grid[h][w])
			_construct_cell(Vector2(w, h), wds)
		
enum WallDir {
	N = 1,
	S = 2,
	E = 3,
	W = 4
}


func _construct_cell(grid_idx: Vector2, wall_dirs: Array):
	for wall_dir in wall_dirs:
		_place_single_wall(grid_idx, wall_dir)
		
		
func _walls_from(passages: int):
	var result = [ WallDir.N, WallDir.S, WallDir.E, WallDir.W ]
	for p in _passages_list(passages):
		var wd = _wall_dir(p)
		var found = result.find(wd)
		if found > -1:
			result.remove(found)
	return result
	
	
func _passages_list(passages: int):
	var result = []
	var all = [ Passages.N, Passages.S, Passages.E, Passages.W ]
	for p in all:
		if passages & p:
			result.push_front(p)
	return result
	
	
	
	
func _place_single_wall(grid_idx: Vector2, wall_dir: int):
	var wall_body = WallBody.instance()
	var wbs = wall_body.size()
	var to_move = (grid_idx * wbs.x) + (Vector2(wbs.x / 2,wbs.x / 2))
	wall_body.translate(Vector3(to_move.x, 0, to_move.y))
	
	_shift_wall(wall_body, wall_dir)
	_rotate_wall(wall_body, wall_dir)
	wall_body.editor_description = "grid_idx %s, wall_dir %s" % [grid_idx, _describe_wall(wall_dir)]
	add_child(wall_body)
	
func _rotate_wall(wall_body: StaticBody, wall_dir: int):
	match wall_dir:
		WallDir.E:
			wall_body.rotate_y(deg2rad(90))
		WallDir.W:
			wall_body.rotate_y(deg2rad(-90))
		_:
			pass
	
func _shift_wall(wall_body: StaticBody, wall_dir: int):
	var wbe = wall_body.size()
	var length: float = (wbe.x + (wbe.z / 2.0))
	match wall_dir:
		WallDir.N:
			wall_body.translate (Vector3(0,0,length / -2))
		WallDir.S:
			wall_body.translate (Vector3(0,0,length / 2))
		WallDir.E:
			wall_body.translate (Vector3(length / 2,0,0))
		WallDir.W:
			wall_body.translate (Vector3(length / -2,0,0))
	
	

func _describe_wall(wall_dir: int) -> String:
	match wall_dir:
		WallDir.N:
			return "N"
		WallDir.S:
			return "S"
		WallDir.E:
			return "E"
		WallDir.W:
			return "W"
		_:
			return ""
		
# EXAMPLES OF ASCII WALLS AND THEIR PASSAGES VALUES


# ___________________
#| |   |_   _____    |
#|___|_  | |  ___| | |
#|_  |  _|___|  ___| |
#|  _|_____  |   | | |
#|_    |   | |_| |  _|
#|  _| | | |_  | | | |
#| |___| |  _|___| | |
#| |   | | |  _  |_  |
#|  _|___| |_  | |  _|
#|_______|_____|_____|
#
# 2  6 10  4 14 12 12 12 14 10 
# 5  9  5 10  3  6 12  8  3  3 
# 4 10  6  9  5  9  6 12  9  3 
# 6  9  5 12 12 10  7 10  2  3 
# 5 14 10  6 10  3  1  3  7  9 
# 6  9  3  3  3  5 10  3  3  2 
# 3  4  9  3  7  8  5  9  3  3 
# 3  6 10  3  3  6 12 10  5 11 
# 7  9  5  9  3  5 10  3  6  9 
# 5 12 12  8  5 12  9  5 13  8 


# ___________________
#| |    _|  _  |  _  |
#| | |_____| | | |  _|
#| |_  |_    |___|_  |
#|_  |_____| |  ___  |
#| | |  _____| |_   _|
#|  _|_|  _  |_  |_  |
#|_______| |_____| | |
#|    _|  _____  |  _|
#| |_  |_____  |___| |
#|___|_______________|
#
# 2  6 14  8  6 12 10  6 12 10 
# 3  3  5 12  9  2  3  3  6  9 
# 3  5 10  4 14 11  5  9  5 10 
# 5 10  5 12  9  3  6 12 12 11 
# 2  3  6 12 12  9  3  4 14  9 
# 7  9  1  6 12 10  5 10  5 10 
# 5 12 12  9  2  5 12  9  2  3 
# 6 14  8  6 13 12 12 10  7  9 
# 3  5 10  5 12 12 10  5  9  2 
# 5  8  5 12 12 12 13 12 12  9 	
