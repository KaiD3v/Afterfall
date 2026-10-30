# Ruído no mundo: todo zumbi dentro do raio ouve e vai investigar a origem.
# Chama-se Noises porque Noise já é uma classe nativa do Godot.
class_name Noises


static func emit(source: Node2D, radius: float) -> void:
	source.get_tree().call_group(Groups.ZOMBIES, "hear", source.global_position, radius)
