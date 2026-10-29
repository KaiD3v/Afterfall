# Direção cardinal de um vetor e animação estado_direção com fallback para idle_direção.
class_name Facing


static func dir_name(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "left" if v.x < 0 else "right"
	return "up" if v.y < 0 else "down"


# Toca estado_direção (walk_left...). Sem essa animação na sheet, cai para idle_direção;
# assim a arte nova entra só gerando a sheet, sem mexer no código.
static func play(sprite: AnimatedSprite2D, state: String, v: Vector2) -> void:
	var dir := dir_name(v)
	var anim := StringName("%s_%s" % [state, dir])
	if not sprite.sprite_frames.has_animation(anim):
		anim = StringName("idle_" + dir)
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
