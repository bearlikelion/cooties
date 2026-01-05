class_name Player
extends CharacterBody2D

enum {
	NULL,
	DEFAULT_LAYER,
	ONE_WAY_LAYER,
	BOUNCY_LAYER
}


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
var is_infected: bool = false

@onready var infected_particles: GPUParticles2D = $Infected
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var infection_area: Area2D = $InfectionArea
@onready var one_way_check: Area2D = $OneWayCheck
@onready var fart_sound: AudioStreamPlayer = $FartSound


func _ready() -> void:
	# Set player name from Global
	var peer_id: int = int(name)
	if player_name:
		player_name.text = Global.get_player_name(peer_id)

	if not is_multiplayer_authority():
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	# Server-only infection collision detection
	if multiplayer.is_server() and infection_area:
		infection_area.body_entered.connect(_on_infection_area_body_entered)


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

	#Handle one-way platforms
	_handle_one_way()
	
	# Handle wall sliding
	_handle_wall_slide()
	
	# Handle jumping
	_handle_jump()
	
	# Handle horizontal movement
	_handle_movement(delta)
	
	# Apply movement
	_apply_physics()

	# Update animations
	_update_animation()


func _apply_physics() -> void:
	# store velocity and position and then call move_and_slide()
	var vel: Vector2 = velocity
	var pos1: Vector2 = global_position
	move_and_slide()
	
	var pos2: Vector2 = global_position
	
	var col: KinematicCollision2D = get_last_slide_collision()
	if !col: return
	
	# If it detects a bouncy thing, bounce.
	if !(PhysicsServer2D.body_get_collision_layer(col.get_collider_rid()) & BOUNCY_LAYER):
		var new_vel: Vector2 = _bouncy_col_math(vel, col.get_normal())
		velocity = new_vel
		move_and_slide()
		_bouncy_position_correction(pos1, pos2, col.get_normal())

		_on_landed()

# when you call move_and_slide(), it steps the position forward in physics space. doing it a second time for the second move_and_slide() causes kinetic energy increases over time.
# youve gotta correct the second move_and_slide() call so you dont gain energy by just bouncing. this puts you at the same distance you had to the surface before colliding.
func _bouncy_position_correction(pos1: Vector2, pos2: Vector2, normal: Vector2) -> void:
	global_position = pos2 - normal * (pos2 - pos1).dot(normal)

# Does the math for a bouncy collision against a static object.
func _bouncy_col_math(vel: Vector2, normal: Vector2) -> Vector2:
	# First, project the vel vector onto the normal
	# This shortened version  of projection math only works cuz we know normal is a unit vector
	var proj: Vector2 = normal * vel.dot(normal)
	
	#Then, we take that component and minus it twice off the current velocity. boom. elastic collision against static wall.
	return vel - 2 * proj


# Handles the one-way platform functionality.
func _handle_one_way() -> void:
	# The only time that a one way platform should have collision is when: its detected by the check, the player is moving downwards or resting, and the down direction is not pressed.
	if one_way_check.has_overlapping_bodies() && velocity.y >= 0 && !Input.is_action_pressed("fall_through"):
		# We set the collision by modifying our own collision layers.
		set_collision_mask_value(ONE_WAY_LAYER,true)
	else:
		set_collision_mask_value(ONE_WAY_LAYER,false)


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


# Server-only: Detect infection collision
func _on_infection_area_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or not is_infected:
		return
	
	if body is Player and not body.is_infected:
		var game: Game = get_tree().get_first_node_in_group("game")
		if game:
			game.infect_player(int(body.name))


# Set infection state and update particle effect
func set_infected(infected_state: bool) -> void:
	is_infected = infected_state

	if infected_particles:
		infected_particles.emitting = infected_state

	if is_infected:
		fart_sound.play()
