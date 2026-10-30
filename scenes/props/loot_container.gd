# Container de loot (armário, geladeira...): interagir abre o menu do inventário com o conteúdo
# do móvel ao lado da mochila, para o jogador escolher o que levar (e deixar coisas lá).
# A interação chega pelo nó Interactable; o aviso diz "Abrir" ou "(vazio)".
extends StaticBody2D

@export var id: StringName
@export var label := "Armário"
@export var table: LootTable
@export var color := Color8(133, 102, 74)  # greybox, enquanto não há móvel
@export var sprite: Texture2D  # o móvel (quadro de 64×64, base na linha 62); substitui o greybox


@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(interact)
	$Body.color = color
	if sprite:
		$Body.hide()
		$Sprite.texture = sprite
		# contorno de foco em volta do móvel inteiro, não só da pegada
		var used := Rect2(sprite.get_image().get_used_rect())
		used.position = (used.position + $Sprite.offset) * $Sprite.scale
		used.size *= $Sprite.scale
		$Focus.position = used.position - Vector2.ONE
		$Focus.size = used.size + Vector2(2, 2)
	_refresh()


func interact(_player: Node) -> void:
	contents()
	get_tree().call_group(Groups.INVENTORY_MENU, "open_loot", self)


# O que está no móvel (sorteado na primeira vez da run). O móvel se atualiza quando muda.
func contents() -> Inventory:
	var inv := RunState.loot.of(id, table)
	if not inv.changed.is_connected(_refresh):
		inv.changed.connect(_refresh)
	return inv


# Pega tudo o que couber: munição vai direto para a reserva, o resto para a mochila.
# Devolve os nomes pegos e se sobrou algo por falta de espaço.
func take_all(player: Node) -> Dictionary:
	var inv := contents()
	var got: Array[String] = []
	var full := false
	for i in inv.capacity:
		var item := inv.get_at(i)
		if item == null:
			continue
		if item.on_pickup(player) and not RunState.inventory.add(item):
			full = true  # ocupa bloco e não coube: fica no móvel
			continue
		inv.put(i, null)
		got.append(item.display_name)
		RunState.stats.looted += 1
	return {"got": got, "full": full}


# Já aberto nesta run e sem nada dentro.
func is_looted() -> bool:
	return RunState.loot.is_looted(id)


func _refresh() -> void:
	modulate = Color(0.55, 0.55, 0.55) if is_looted() else Color.WHITE
	interactable.prompt_text = ("%s (vazio)" % label) if is_looted() else ("%s · Abrir %s" % [Keys.label(&"interact"), label])
