extends StaticBody

# required in HedgeMaze.gd
func size():
	var box_shape: BoxShape = $CollisionShape.shape
	return box_shape.extents * 2
