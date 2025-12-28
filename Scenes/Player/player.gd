class_name Player
extends CharacterBody2D

@export var animated_sprite_2d: AnimatedSprite2D
@export var player_name: Label

# Movement configuration
@export var move_speed: float = 200.0
@export var acceleration: float = 1000.0
@export var friction: float = 1200.0

# Jump configuration
@export var jump_velocity: float = -400.0
@export var double_jump_velocity: float = -350.0
@export var wall_jump_velocity: Vector2 = Vector2(300.0, -400.0)

# Wall slide configuration
@export var wall_slide_speed: float = 60.0

# Physics
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 500.0

# State tracking
var has_double_jump: bool = true
var is_wall_sliding: bool = false
var was_on_floor: bool = false

@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight


func _ready() -> void:
	# Set player name from Global
	var peer_id: int = int(name)
	if player_name:
		player_name.text = Global.get_player_name(peer_id)

	if not is_multiplayer_authority():
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func _physics_process(delta: float) -> void:
	# Only process input for the player we control
	if not is_multiplayer_authority():
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + get_gravity().y * gravity_scale * delta, max_fall_speed)

	# Track floor state for jump resets
	if is_on_floor() and not was_on_floor:
		_on_landed()
	was_on_floor = is_on_floor()

	# Handle wall sliding
	_handle_wall_slide()

	# Handle jumping
	_handle_jump()

	# Handle horizontal movement
	_handle_movement(delta)

	# Apply movement
	move_and_slide()

	# Update animations
	_update_animation()


# Handles horizontal movement with acceleration and friction
func _handle_movement(delta: float) -> void:
	var input_direction: float = Input.get_axis("move_left", "move_right")

	# Fallback to UI actions if custom actions don't exist
	if input_direction == 0.0:
		input_direction = Input.get_axis("ui_left", "ui_right")

	if input_direction != 0.0:
		# Accelerate towards target speed
		velocity.x = move_toward(velocity.x, input_direction * move_speed, acceleration * delta)

		# Flip sprite based on direction
		animated_sprite_2d.flip_h = input_direction < 0
	else:
		# Apply friction when no input
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


# Handles jump, double jump, and wall jump
func _handle_jump() -> void:
	var jump_pressed: bool = Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")

	if not jump_pressed:
		return

	# Wall jump
	if is_wall_sliding:
		_perform_wall_jump()
		return

	# Normal jump
	if is_on_floor():
		velocity.y = jump_velocity
		has_double_jump = true
		return

	# Double jump
	if has_double_jump:
		velocity.y = double_jump_velocity
		has_double_jump = false


# Performs a wall jump
func _perform_wall_jump() -> void:
	var wall_normal: float = 1.0 if wall_check_left.is_colliding() else -1.0

	velocity.x = wall_normal * wall_jump_velocity.x
	velocity.y = wall_jump_velocity.y

	has_double_jump = true
	is_wall_sliding = false

	# Flip sprite away from wall
	animated_sprite_2d.flip_h = wall_normal < 0


# Handles wall sliding detection and speed
func _handle_wall_slide() -> void:
	if is_on_floor():
		is_wall_sliding = false
		return

	var is_near_wall: bool = wall_check_left.is_colliding() or wall_check_right.is_colliding()

	if is_near_wall and velocity.y > 0:
		is_wall_sliding = true
		velocity.y = min(velocity.y, wall_slide_speed)
		has_double_jump = true
	else:
		is_wall_sliding = false


# Called when player lands on the floor
func _on_landed() -> void:
	has_double_jump = true


# Updates the animation based on current state
func _update_animation() -> void:
	# Wall slide
	if is_wall_sliding:
		animated_sprite_2d.play("wall_jump")
		return

	# Airborne
	if not is_on_floor():
		if not has_double_jump:
			animated_sprite_2d.play("double_jump")
		elif velocity.y < 0:
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("fall")
		return

	# Grounded
	if abs(velocity.x) > 10.0:
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")
