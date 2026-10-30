# Inventário em blocos fixos (a mochila): um item por bloco, sem peso; bloco vazio = null.
# Mesmo contrato de recipiente do Equipment (get_at, can_put, put), para o menu e o ItemTransfer.
# Serve ao jogador e, depois, a baús e carros.
class_name Inventory
extends RefCounted

signal changed

var capacity := 9:
	set(value):
		capacity = value
		_cells.resize(value)
var items: Array[ItemData]:  # os itens, sem os blocos vazios, na ordem dos blocos
	get:
		return _cells.filter(func(it): return it != null)

var _cells: Array[ItemData] = []


func _init() -> void:
	_cells.resize(capacity)


func get_at(i: int) -> ItemData:
	return _cells[i]


func can_put(_i: int, _item: ItemData) -> bool:
	return true  # mochila aceita qualquer item


func put(i: int, item: ItemData) -> void:
	_cells[i] = item
	changed.emit()


# Índice do primeiro bloco vazio; -1 com a mochila cheia.
func first_free() -> int:
	return _cells.find(null)


# Põe no primeiro bloco vazio; false se a mochila estiver cheia.
func add(item: ItemData) -> bool:
	var i := first_free()
	if i < 0:
		return false
	put(i, item)
	return true


# Tira um item com esse id; false se não houver.
func take(id: StringName) -> bool:
	for i in _cells.size():
		if _cells[i] and _cells[i].id == id:
			put(i, null)
			return true
	return false


# Usa um item que esteja no inventário; gasta só se o efeito aconteceu.
func use(item: ItemData, user: Node) -> bool:
	return count(item.id) > 0 and item.use(user) and take(item.id)


func count(id: StringName) -> int:
	return items.filter(func(it: ItemData): return it.id == id).size()


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func is_full() -> bool:
	return not _cells.has(null)


func free_slots() -> int:
	return _cells.count(null)


func clear() -> void:
	_cells.fill(null)
	changed.emit()
