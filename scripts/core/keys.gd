# Nome da tecla de uma ação do mapa de entrada (project.godot), para os avisos na tela: trocar a
# tecla no mapa troca todos os textos.
class_name Keys


static func label(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: Key = e.physical_keycode if e.physical_keycode else e.keycode
			return OS.get_keycode_string(code)
	return "?"
