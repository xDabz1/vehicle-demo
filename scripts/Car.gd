extends VehicleBody

############################################################
# Behaviour values

export var MAX_ENGINE_FORCE = 150.0
export var MAX_BRAKE_FORCE = 5.0
export var MAX_STEER_ANGLE = 0.35

export var steer_speed = 1.0

var steer_target = 0.0
var steer_angle = 0.0

############################################################
# Speed and drive direction

var current_speed_mps = 0.0
var last_pos = Vector3(0.0, 0.0, 0.0)

func get_speed_kph():
	return current_speed_mps * 3600.0 / 1000.0

############################################################
# Gear data

export (Array) var gear_ratios = [ 2.69, 2.01, 1.59, 1.32, 1.13, 1.0 ] 
export var reverse_ratio = -2.5
export var final_drive = 3.38
export var max_engine_rpm = 8000.0
export (Curve) var power_curve = null

var selected_gear = 1 # -1 = reverse, 0 = neutral, 1+ = gear

func get_engine_rpm():
	# if we're in neutral, or we've lost traction, we use our previous RPM + input
	if selected_gear == 0:
		return 0
	
	var wheel_size = 2.0 * PI * $right_rear.wheel_radius
	var wheel_rotation_speed = 60.0 * current_speed_mps / wheel_size
	
	var rpm = wheel_rotation_speed * final_drive ## drive shaft speed
	if selected_gear == -1:
		rpm = rpm * -reverse_ratio
	else:
		rpm = rpm * gear_ratios[selected_gear - 1]
	
	return rpm 

############################################################
# Input

export var joy_steering = JOY_ANALOG_LX
export var steering_mult = -1.0
export var joy_throttle = JOY_ANALOG_R2
export var throttle_mult = 1.0
export var joy_brake = JOY_ANALOG_L2
export var brake_mult = 1.0

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

var measure_0_60 = true
var time_0_60 = 0.0
var measure_0_100 = true
var time_0_100 = 0.0

func _process(delta):
	if Input.is_action_just_pressed("shift_down") and selected_gear > -1:
		selected_gear = selected_gear - 1
	elif Input.is_action_just_pressed("shift_up") and selected_gear < gear_ratios.size():
		selected_gear = selected_gear + 1
	
	var speed = get_speed_kph()
	
	if speed < 0.1:
		measure_0_60 = true
		time_0_60 = 0
		measure_0_100 = true
		time_0_100 = 0
	else:
		if measure_0_60:
			if speed > 60.0:
				measure_0_60 = false
			else:
				time_0_60 += delta
		
		if measure_0_100:
			if speed > 100.0:
				measure_0_100 = false
			else:
				time_0_100 += delta
	
	var info = 'Speed: %.0f, gear: %d, rpm: %.0f\n'  % [ speed, selected_gear, get_engine_rpm() ]
	info += '0 -  60: %0.2f\n' % [ time_0_60 ]
	info += '0 - 100: %0.2f\n' % [ time_0_100 ]
	
	$Info.text = info

func _physics_process(delta):
	# how fast are we going in meters per second?
	current_speed_mps = (translation - last_pos).length() / delta
	
	# get our joystick inputs
	var steer_val = steering_mult * Input.get_joy_axis(0, joy_steering)
	var throttle_val = throttle_mult * Input.get_joy_axis(0, joy_throttle)
	var brake_val = brake_mult * Input.get_joy_axis(0, joy_brake)
	
	if (throttle_val < 0.0):
		throttle_val = 0.0
	
	if (brake_val < 0.0):
		brake_val = 0.0
	
	# overrules for keyboard
	if Input.is_action_pressed("ui_up"):
		throttle_val = 1.0
	if Input.is_action_pressed("ui_down"):
		brake_val = 1.0
	if Input.is_action_pressed("ui_left"):
		steer_val = 1.0
	elif Input.is_action_pressed("ui_right"):
		steer_val = -1.0
	
	if (throttle_val == 0.0 and brake_val == 0.0 and current_speed_mps < 3.0):
		# if no throttle input, brake lightly
		brake_val = 0.1
	var rpm = clamp(get_engine_rpm() / max_engine_rpm, 0.1, 1.0)
	var max_power = power_curve.interpolate_baked(rpm)
	if selected_gear == -1:
		max_power = max_power * reverse_ratio
	elif selected_gear == 0:
		max_power = 0.0
	else:
		max_power = max_power * gear_ratios[selected_gear - 1]
	
	throttle_val = throttle_val * max_power * MAX_ENGINE_FORCE
	brake_val = brake_val * MAX_BRAKE_FORCE
	
	if throttle_val < 0.0:
		engine_force = 0.0
		brake = brake_val - throttle_val
	else:
		engine_force = throttle_val
		brake = brake_val
	
	$brake_lights.visible = brake_val > 0.1
	$reverse_lights.visible = selected_gear == -1
	
	steer_target = steer_val * MAX_STEER_ANGLE
	if (steer_target < steer_angle):
		steer_angle -= steer_speed * delta
		if (steer_target > steer_angle):
			steer_angle = steer_target
	elif (steer_target > steer_angle):
		steer_angle += steer_speed * delta
		if (steer_target < steer_angle):
			steer_angle = steer_target
	
	steering = steer_angle
	$interior/steering.rotation.z = -5.0 * steer_angle
	$wings/left_wing.rotation.y = steer_angle
	$wings/right_wing.rotation.y = steer_angle
	
	# remember where we are
	last_pos = translation
