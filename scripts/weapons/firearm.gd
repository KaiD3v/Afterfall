# Arma de fogo: pente, reserva, recarga, raycast do cano e dispersão. Os efeitos ficam em ShotFx.
class_name Firearm
extends Weapon

signal changed  # pente, reserva ou recarga mudaram

@export var reserve := 24:  # munição fora do pente; o loot soma a ela
	set(value):
		reserve = value
		changed.emit()
@export var muzzle_light: Texture2D  # textura da luz do clarão (opcional)

var ammo := 0:
	set(value):
		ammo = value
		changed.emit()
var reloading := false:
	set(value):
		reloading = value
		changed.emit()
var moving := false  # o dono avisa: andando, a dispersão abre

var _reload_sound: AudioStreamPlayer2D
var _loaded := false  # o pente vem cheio na primeira vez que uma arma é equipada

@onready var tracer: Line2D = $Tracer


func _ready() -> void:
	super()
	ShotFx.style_tracer(tracer)


# ponytail: o pente fica no nó (uma pistola só); com várias armas de fogo, o pente vai para o item.
func _equip() -> void:
	super()
	if _reload_sound:
		_reload_sound.queue_free()
	_reload_sound = _audio(gun().reload_sound) if gun() else null
	if gun():
		ammo = mini(ammo, gun().mag_size) if _loaded else gun().mag_size
		_loaded = true
	changed.emit()


func gun() -> FirearmData:
	return data as FirearmData


# Dispersão atual em graus: aumenta ao andar mirando.
func spread_now() -> float:
	var g := gun()
	if g == null:
		return 0.0
	if not moving or g.spread == 0.0:
		return g.spread
	return maxf(g.spread, g.move_spread)


func fire(dir: Vector2) -> bool:
	if not is_equipped() or is_waiting() or reloading or ammo == 0:
		return false
	ammo -= 1
	var muzzle := user.muzzle_position()
	var spread := spread_now()
	var aim := dir.normalized().rotated(deg_to_rad(randf_range(-spread, spread)))
	var travel_dist := gun().max_range
	var hit_collider: Object = null
	# testa no plano dos pés e na projeção do cano (paredes e zumbis); vale o acerto mais perto
	for ray_origin: Vector2 in [user.global_position, muzzle + Vector2(0.0, 24.0), muzzle]:
		var ray := PhysicsRayQueryParameters2D.create(ray_origin, ray_origin + aim * gun().max_range, Layers.WORLD | Layers.ZOMBIES)
		ray.exclude = [user.get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if hit:
			var d: float = ray_origin.distance_to(hit.position)
			if d < travel_dist:
				travel_dist = d
				hit_collider = hit.collider
	var target := Health.of(hit_collider)
	if target:
		target.damage(gun().damage, user)
	var end := muzzle + aim * travel_dist
	tracer.points = PackedVector2Array([muzzle, end])
	tracer.show()
	ShotFx.fire(self, user.get_parent(), tracer, muzzle, end, aim, hit_collider, muzzle_light)
	_used()
	user.play_action(gun().anim)
	return true


# Recarga num tween do próprio nó: se a cena sair (nova run), nada volta num nó liberado.
func reload() -> bool:
	if not is_equipped() or reloading or ammo == gun().mag_size or reserve == 0:
		return false
	reloading = true
	if _reload_sound:
		_reload_sound.play()
	if user.play_action("reload") and gun().reload_time > 0.0:
		user.sprite.speed_scale = 1.5 / gun().reload_time
	create_tween().tween_callback(_reloaded).set_delay(gun().reload_time)
	return true


func _reloaded() -> void:
	reloading = false
	if user.action == "reload":
		user.action = ""
	if user.is_dead() or not is_equipped():  # desequipada no meio da recarga: nada entra
		return
	var n := mini(gun().mag_size - ammo, reserve)
	ammo += n
	reserve -= n
