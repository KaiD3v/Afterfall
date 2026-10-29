# Direção cardinal de um vetor e animação estado_direção, com espelhamento e fallback.
class_name Facing


static func dir_name(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "left" if v.x < 0 else "right"
	return "up" if v.y < 0 else "down"


# Animação para estado e direção: [nome, espelhar]. Sem left na sheet, usa right espelhado
# (decisão do autor: a esquerda é a direita espelhada). [&"", false] se não houver.
static func resolve(sprite: AnimatedSprite2D, state: String, v: Vector2) -> Array:
	var dir := dir_name(v)
	var anim := StringName("%s_%s" % [state, dir])
	if sprite.sprite_frames.has_animation(anim):
		return [anim, false]
	anim = StringName(state + "_right")
	if dir == "left" and sprite.sprite_frames.has_animation(anim):
		return [anim, true]
	return [&"", false]


# Toca a ação estado_direção (melee, attack, hurt...) do início; devolve se a sheet tem.
static func play_action(sprite: AnimatedSprite2D, state: String, v: Vector2) -> bool:
	var pick := resolve(sprite, state, v)
	if pick[0] == &"":
		return false
	sprite.flip_h = pick[1]
	sprite.speed_scale = 1.0
	sprite.stop()
	sprite.play(pick[0])
	return true


# Toca estado_direção; sem essa animação, cai para idle_direção. Assim a arte nova entra
# só gerando a sheet, sem mexer no código.
static func play(sprite: AnimatedSprite2D, state: String, v: Vector2) -> void:
	var pick := resolve(sprite, state, v)
	if pick[0] == &"":
		pick = resolve(sprite, "idle", v)
	sprite.flip_h = pick[1]
	if sprite.animation != pick[0] or not sprite.is_playing():
		sprite.play(pick[0])
