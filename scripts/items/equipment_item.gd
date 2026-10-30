# Item que vai num slot de equipamento, e não na mão: arma branca, arma de fogo, cabeça ou corpo.
class_name EquipmentItem
extends ItemData

enum Slot { MELEE, FIREARM, HEAD, BODY }

@export var slot := Slot.MELEE
@export var equip_sound: AudioStream  # toca no menu quando o item é equipado

const SLOT_NAMES := {Slot.MELEE: "Arma branca", Slot.FIREARM: "Arma de fogo", Slot.HEAD: "Capacete", Slot.BODY: "Colete"}


func type_name() -> String:
	return SLOT_NAMES[slot]
