# Container de loot (armário, geladeira...): interagir (E) pega o que couber no inventário.
extends StaticBody2D

@export var id: StringName
@export var label := "Armário"
@export var table: LootTable
@export var color := Color8(155, 122, 84)  # greybox; a arte do interior troca isto


func _ready() -> void:
	add_to_group("interactables")
	$Body.color = color
	$Name.text = label
	_refresh()


func interact(player: Node) -> void:
	var loot: Array = RunState.loot_of(id, table)
	if loot.is_empty():
		RunState.notify("%s: vazio" % label)
		_refresh()
		return
	var got: Array[String] = []
	for item in loot.duplicate():
		if item == &"ammo_9mm":
			player.reserve += RunState.AMMO_PER_BOX
		elif not RunState.add_item(item):
			continue  # inventário cheio: o item fica no container
		loot.erase(item)
		got.append(RunState.NAMES[item])
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
