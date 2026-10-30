# Lanterna tática do jogador (tecla T): no trilho da pistola ao mirar, no colete ao caminhar.
class_name Flashlight
extends PointLight2D

var on := true

@onready var user: Player = get_parent()


func toggle() -> void:
	on = not on
	enabled = on
	visible = on


func _physics_process(delta: float) -> void:
	if user.is_dead() or not on:
		return
	var facing := user.facing
	var aiming: bool = user.aiming
	var action := user.action
	var dir_name := Facing.dir_name(facing)
	var target_pos: Vector2
	var target_ang := facing.angle()
	var target_energy := 1.08
	if user.firearm.reloading or action == "reload":
		target_pos = Vector2(-7.0 if dir_name == "left" else 7.0, -21.0)
		target_ang += 0.22 if dir_name != "left" else -0.22
		target_energy = 0.80
	elif aiming or action == "shoot":
		var m := user.muzzle_position()
		target_pos = m - user.global_position + Vector2(0.0, 0.5)
		if m.distance_squared_to(get_global_mouse_position()) > 4.0:
			target_ang = m.direction_to(get_global_mouse_position()).angle()
		target_energy = 1.15
	else:
		match dir_name:
			"left":
				target_pos = Vector2(-5.5, -20.0)
			"right":
				target_pos = Vector2(5.5, -20.0)
			"up":
				target_pos = Vector2(3.5, -22.0)
			_:
				target_pos = Vector2(3.5, -19.0)
	var pos_rate := minf(1.0, (28.0 if aiming else 18.0) * delta)
	var ang_rate := minf(1.0, (28.0 if aiming else 14.0) * delta)
	position = position.lerp(target_pos, pos_rate)
	rotation = lerp_angle(rotation, target_ang, ang_rate)
	energy = lerpf(energy, target_energy, minf(1.0, 12.0 * delta))
	$Lens.visible = not (dir_name == "up" and not aiming)
