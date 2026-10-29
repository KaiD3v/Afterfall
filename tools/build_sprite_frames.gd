# Gera SpriteFrames (.tres) a partir das sheets do Codex: PNG + JSON no formato Aseprite
# (frames com duration em ms e frameTags). Cada frameTag vira uma animação com o mesmo nome,
# no padrão estado_direção (idle_down, walk_left...).
# Rodar: godot --headless --path . --script res://tools/build_sprite_frames.gd
extends SceneTree

# SpriteFrames -> sheets que entram nele (movimento da Fase B, combate da Fase C).
# Sheet que ainda não existe é pulada: a arte entra só gerando o JSON.
const SHEETS := {
	"res://assets/sprites/character_frames.tres": ["res://assets/sprites/b/character-move.json", "res://assets/sprites/c/character-combat.json"],
	"res://assets/sprites/zombie_frames.tres": ["res://assets/sprites/b/zombie-move.json", "res://assets/sprites/c/zombie-combat.json"],
}
# Ações tocam uma vez e destravam o movimento ao terminar, mesmo que o JSON diga loop.
const ONE_SHOT := ["melee", "shoot", "attack", "hurt", "death"]


func _initialize() -> void:
	for out in SHEETS:
		var sf := SpriteFrames.new()
		sf.remove_animation(&"default")
		for json_path in SHEETS[out]:
			if FileAccess.file_exists(json_path):
				_add_sheet(sf, json_path)
		var err := ResourceSaver.save(sf, out)
		print("%s: %d animações (%d)" % [out.get_file(), sf.get_animation_names().size(), err])
	quit()


func _add_sheet(sf: SpriteFrames, json_path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var texture: Texture2D = load(json_path.get_base_dir().path_join(data.meta.image))
	var frames: Array = data.frames
	if data.meta.has("muzzle"):  # boca do cano por direção, em px do frame de mira
		sf.set_meta("muzzle", data.meta.muzzle)
		sf.set_meta("muzzle_frame", Vector2(frames[0].frame.w, frames[0].frame.h))
	for tag in data.meta.frameTags:
		var anim := StringName(tag.name)
		var base_ms: float = frames[tag.from].duration
		sf.add_animation(anim)
		sf.set_animation_loop(anim, tag.get("loop", true) and String(anim).get_slice("_", 0) not in ONE_SHOT)
		sf.set_animation_speed(anim, 1000.0 / base_ms)
		for k in range(tag.from, tag.to + 1):
			var r: Dictionary = frames[k].frame
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(r.x, r.y, r.w, r.h)
			sf.add_frame(anim, atlas, frames[k].duration / base_ms)
