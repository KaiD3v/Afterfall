# Container de loot (armário, geladeira...): interagir (E) pega o que couber no inventário.
extends StaticBody2D

@export var id: StringName
@export var label := "Armário"
@export var table: LootTable
@export var color := Color8(133, 102, 74)  # greybox, enquanto não há móvel
@export var sprite: Texture2D  # o móvel (quadro de 64×64, base na linha 62); substitui o greybox


func _ready() -> void:
	add_to_group(Groups.INTERACTABLES)
	$Body.color = color
	if sprite:
		$Body.hide()
		$Sprite.texture = sprite
		# contorno de foco e nome em volta do móvel inteiro, não só da pegada
		var used := Rect2(sprite.get_image().get_used_rect())
		used.position = (used.position + $Sprite.offset) * $Sprite.scale
		used.size *= $Sprite.scale
		$Focus.position = used.position - Vector2.ONE
		$Focus.size = used.size + Vector2(2, 2)
		$Name.position.y = used.position.y - 12
	$Name.text = label
	_refresh()


func interact(player: Node) -> void:
	var loot: Array = RunState.loot_of(id, table)
	if loot.is_empty():
		RunState.notify("%s: vazio" % label)
		_refresh()
		return
	var got: Array[String] = []
	for item: ItemData in loot.duplicate():
		# ocupa slot e não coube: fica no container; efeito na hora (munição) sempre sai
		if item.on_pickup(player) and not RunState.inventory.add(item):
			continue
		loot.erase(item)
		got.append(item.display_name)
		RunState.looted += 1
	RunState.notify("%s: %s" % [label, ", ".join(got)] if got else "%s: inventário cheio" % label)
	_refresh()


func set_focus(on: bool) -> void:
	$Focus.visible = on


func prompt() -> String:
	return ("%s (vazio)" % label) if is_looted() else ("E · Abrir %s" % label)


# Já aberto nesta run e sem nada dentro.
func is_looted() -> bool:
	return RunState.is_looted(id)


func _refresh() -> void:
	modulate = Color(0.55, 0.55, 0.55) if is_looted() else Color.WHITE
