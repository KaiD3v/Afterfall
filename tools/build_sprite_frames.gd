# Gera SpriteFrames (.tres) a partir das sheets do Codex: PNG + JSON no formato Aseprite
# (frames com duration em ms e frameTags). Cada frameTag vira uma animação com o mesmo nome,
# no padrão estado_direção (idle_down, walk_left...).
# Rodar: godot --headless --path . --script res://tools/build_sprite_frames.gd
extends SceneTree

const SHEETS := {
	"res://assets/sprites/m1/character.json": "res://assets/sprites/character_frames.tres",
	"res://assets/sprites/m1/zombie.json": "res://assets/sprites/zombie_frames.tres",
}
# Ações tocam uma vez e destravam o movimento ao terminar, mesmo que o JSON diga loop.
const ONE_SHOT := ["melee", "shoot", "attack", "hurt", "death"]


func _initialize() -> void:
	for json_path in SHEETS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		var texture: Texture2D = load(json_path.get_base_dir().path_join(data.meta.image))
		var frames: Array = data.frames
		var sf := SpriteFrames.new()
		sf.remove_animation(&"default")
		for tag in data.meta.frameTags:
			var anim := StringName(tag.name)
			var base_ms: float = frames[tag.from].duration
			sf.add_animation(anim)
			sf.set_animation_loop(anim, tag.get("loop", true) and String(anim).get_slice("_", 0) not in ONE_SHOT)
			sf.set_animation_speed(anim, 1000.0 / base_ms)
			for i in range(tag.from, tag.to + 1):
				var r: Dictionary = frames[i].frame
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(r.x, r.y, r.w, r.h)
				sf.add_frame(anim, atlas, frames[i].duration / base_ms)
		var err := ResourceSaver.save(sf, SHEETS[json_path])
		print("%s: %d animações → %s (%d)" % [json_path.get_file(), sf.get_animation_names().size(), SHEETS[json_path], err])
	quit()
