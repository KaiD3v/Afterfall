# Capacete, colete: proteção de cabeça ou corpo.
# ponytail: v1 só visual; protection ainda não reduz dano (ligar no Health quando entrar).
class_name ArmorItem
extends EquipmentItem

@export var protection := 0.0  # fração do dano evitada, 0 a 1


func stats() -> Array[Dictionary]:
	var text := "%d%% (ainda sem efeito)" % roundi(protection * 100)  # a proteção ainda não reduz dano
	return [stat("Proteção", protection, text)]
