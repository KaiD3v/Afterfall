# Golpe de perto (machete, mordida): com a animação na sheet, o dano sai no frame de contato;
# sem ela, na hora. Quem sai do alcance durante o preparo esquiva.
class_name MeleeWeapon
extends Weapon


func attack() -> bool:
	var cost: float = data.stamina_cost
	if is_waiting() or (cost > 0.0 and not (user.stamina and user.stamina.spend(cost))):
		return false
	_used()
	if not user.play_action(data.anim, hit):
		hit()
	return true


# ponytail: acerto por distância e ângulo, sem Area2D; basta para poucos alvos por golpe.
func hit() -> void:
	var melee := data as MeleeData
	for target in get_tree().get_nodes_in_group(melee.target_group):
		var to: Vector2 = target.global_position - user.global_position
		if to.length() <= melee.reach and absf(rad_to_deg(user.facing.angle_to(to))) <= melee.half_angle:
			var health := Health.of(target)
			if health:
				health.damage(melee.damage, user)
