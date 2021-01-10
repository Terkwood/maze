extends KinematicBody

enum Movement { WALK, FLY }
enum InputHandling { MASTER_MOVE, MASTER_CHAT, PUPPET }

#constants
const GRAVITY = 9.8
const FLOAT = 0.93
const CHAT_PATH = NodePath("/root/Chat")

#mouse sensitivity
export(float,0.1,1.0) var sensitivity_x = 0.5
export(float,0.1,1.0) var sensitivity_y = 0.4

#physics
export(float,10.0, 30.0) var speed = 30.0
export(float,10.0, 50.0) var jump_height = 45
export(float,10.0, 300.0) var fly_height = 175
export(float,1.0, 10.0) var mass = 8.0
export(float,0.1, 3.0, 0.1) var gravity_scl = 1.0

export(Movement) var movement = Movement.WALK

#instances ref
onready var player_hand = $Arm
onready var ground_ray = $GroundRay
onready var chat = get_node(CHAT_PATH)

var mouse_motion = Vector2()
var gravity_speed = 0

puppet var puppet_transform

# Disallow input when focused in chat
var _allow_input = true

func _ready():
	if chat:
		chat.connect("chat_focus_grabbed", self,  "_on_chat_focus_grabbed")
		chat.connect("chat_focus_released", self, "_on_chat_focus_released")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ground_ray.enabled = true
	_update_movement_label()
	puppet_transform = transform

func _physics_process(delta):
	var mode = _input_handling_mode()
	match mode:
		InputHandling.PUPPET:
			transform = puppet_transform
		_:
			#camera and body rotation
			if mode == InputHandling.MASTER_MOVE:
				rotate_y(deg2rad(20)* - mouse_motion.x * sensitivity_x * delta)
				var player_cam = get_node_or_null("Camera")
				if player_cam:
					player_cam.rotate_x(-1 * deg2rad(20) * - mouse_motion.y * sensitivity_y * delta)
					player_cam.rotation.x = clamp(player_cam.rotation.x, deg2rad(-47), deg2rad(47))
					player_hand.rotation.x = lerp(player_hand.rotation.x, player_cam.rotation.x, 0.2)
				mouse_motion = Vector2()
			
			#gravity
			gravity_speed -= GRAVITY * gravity_scl * mass * delta
			
			#character movement
			var velocity = Vector3()
			velocity = _axis() * speed
			velocity.y = gravity_speed
		
			#jump
			var is_move_ok = mode == InputHandling.MASTER_MOVE
			if movement == Movement.WALK:
				if is_move_ok && Input.is_action_just_pressed("space") and ground_ray.is_colliding():
					velocity.y = jump_height
				gravity_speed = move_and_slide(velocity).y
			if movement == Movement.FLY:
				if is_move_ok && Input.is_action_just_pressed("space"):
					velocity.y = fly_height
					gravity_speed = move_and_slide(velocity).y
				else:
					gravity_speed = move_and_slide(velocity * FLOAT).y
			rset_unreliable("puppet_transform", transform)



	if not is_network_master():
		# It may happen that many frames pass before the controlling player sends
		# their transform again. If we don't update puppet_transform to transform after moving,
		# we will keep jumping back until controlling player sends next position update.
		# Therefore, we update puppet_transform to minimize jitter problems
		puppet_transform = transform


func _input(event):
	if event is InputEventMouseMotion:
		mouse_motion = event.relative
	if Input.is_action_just_pressed("ui_home"):
		_switch_movement()

func _axis():
	var direction = Vector3()
	
	if _is_chat_blocking_input():
		pass
	else:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			direction -= get_global_transform().basis.z.normalized()
			
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			direction += get_global_transform().basis.z.normalized()
			
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction -= get_global_transform().basis.x.normalized()
			
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction += get_global_transform().basis.x.normalized()
			
	return direction.normalized()

func _switch_movement():
	if movement == Movement.WALK:
		movement = Movement.FLY
	elif movement == Movement.FLY:
		movement = Movement.WALK
	_update_movement_label()

func _update_movement_label():
	$HUD/VBoxContainer/MovementLabel.text = Movement.keys()[movement]

func _on_chat_focus_grabbed():
	_allow_input = false
	rset_unreliable("puppet_transform", transform)

func _on_chat_focus_released():
	_allow_input = true

func _is_chat_blocking_input():
	return !_allow_input && is_network_master()

# logic that helps us determine whether (as the master node)
# we should use keys to move the character around,
# or ignore keys due to the fact that the user
# is chatting, or (as th puppet node) accept transform
# updates from the master
func _input_handling_mode():
	var nw = is_network_master()
	if _allow_input && nw:
		return InputHandling.MASTER_MOVE
	elif !_allow_input && nw:
		return InputHandling.MASTER_CHAT
	else:
		return InputHandling.PUPPET 
