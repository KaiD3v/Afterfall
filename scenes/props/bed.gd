# Cama da casa (ponto seguro): F dorme. Se não der para dormir, main.sleep() avisa o motivo.
extends StaticBody2D

@export var sprite: Texture2D  # o móvel (quadro de 64×64, base na linha 62)


func _ready() -> void:
	$Sprite.texture = sprite
	if sprite:  # contorno de foco em volta da cama inteira, como nos containers
		var used := Rect2(sprite.get_image().get_used_rect())
		used.position = (used.position + $Sprite.offset) * $Sprite.scale
		used.size *= $Sprite.scale
		$Focus.position = used.position - Vector2.ONE
		$Focus.size = used.size + Vector2(2, 2)
	$Interactable.prompt_text = "%s · Dormir" % Keys.label(&"interact")
	$Interactable.interacted.connect(func(_by): get_tree().call_group(Groups.MAIN, "sleep"))
