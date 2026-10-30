# Arma como item: equipada, o jogador passa a usar o weapon (MeleeData ou FirearmData).
class_name WeaponItem
extends EquipmentItem

@export var weapon: WeaponData

const METERS := 1.0 / World.TILE  # na ficha, 1 tile = 1 m


func stats() -> Array[Dictionary]:
	var out: Array[Dictionary] = [stat("Dano", weapon.damage, num(weapon.damage))]
	var melee := weapon as MeleeData
	var gun := weapon as FirearmData
	if melee:
		out.append(stat("Alcance", melee.reach * METERS, num(melee.reach * METERS) + " m"))
		out.append(stat("Fôlego", weapon.stamina_cost, num(weapon.stamina_cost) + "/golpe", false))
		out.append(stat("Espera", weapon.cooldown, num(weapon.cooldown) + " s", false))
	elif gun:
		out.append(stat("Pente", gun.mag_size, str(gun.mag_size)))
		out.append(stat("Alcance", gun.max_range * METERS, num(gun.max_range * METERS) + " m"))
		out.append(stat("Recarga", gun.reload_time, num(gun.reload_time) + " s", false))
	if weapon.noise > 0.0:
		out.append(stat("Ruído", weapon.noise * METERS, num(weapon.noise * METERS) + " m", false))
	return out
