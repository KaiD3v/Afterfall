# Base das criaturas (jogador, zumbis): direção, sprite com ações estado_direção, vida, fôlego
# opcional e o frame de contato dos golpes. As subclasses respondem em _on_damaged e _on_died.
class_name Actor
extends CharacterBody2D

signal died

const CONTACT_FRAME := 2  # ações de golpe: 0 preparo, 1 golpe, 2 contato, 3 recuperação
const HIT_FLASH := Color(1.6, 0.6, 0.6)

@export var facing := Vector2.DOWN

var action := ""  # ação tocando (melee, shoot, attack, hurt...); trava a animação de movimento
var _contact := Callable()  # golpe esperando o frame de contato

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var stamina: Stamina = get_node_or_null(^"Stamina")  # quem não tem não gasta fôlego


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func is_dead() -> bool:
	return health.is_dead()


# Toca a ação estado_direção do início; on_contact é chamado no frame de contato.
# false se a sheet não tem a ação: quem chamou resolve na hora. Ação nova cancela golpe pendente.
func play_action(anim: String, on_contact := Callable()) -> bool:
	if not Facing.play_action(sprite, anim, facing):
		return false
	action = anim
	_contact = on_contact
	return true


func cancel_contact() -> void:
	_contact = Callable()


# Boca do cano no mundo, pelo ponto marcado no frame de mira de cada direção (meta da sheet).
func muzzle_position() -> Vector2:
	var frames := sprite.sprite_frames
	if not frames.has_meta("muzzle"):
		return global_position + Vector2(0, -10)
	var dir := Facing.dir_name(facing)
	var mirrored := dir == "left"
	var p: Array = frames.get_meta("muzzle")["right" if mirrored else dir]
	var local: Vector2 = Vector2(p[0], p[1]) - frames.get_meta("muzzle_frame") / 2.0 + sprite.offset
	if mirrored:
		local.x = -local.x
	return global_position + local


func _on_frame_changed() -> void:
	if _contact.is_valid() and sprite.frame == CONTACT_FRAME:
		var hit := _contact
		_contact = Callable()
		hit.call()


func _on_animation_finished() -> void:
	action = ""


# Piscar de dano num tween do próprio nó: some junto com ele, sem callback solto na árvore.
func _on_damaged(_amount: float, _source: Node) -> void:
	sprite.modulate = HIT_FLASH
	create_tween().tween_callback(func(): sprite.modulate = Color.WHITE).set_delay(0.1)


func _on_died() -> void:
	died.emit()
