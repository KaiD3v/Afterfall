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


func interact(player: Node) -> void:
	var loot: Array = RunState.loot_of(id, table)
	if loot.is_empty():
		RunState.notify("%s: vazio" % label)
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
