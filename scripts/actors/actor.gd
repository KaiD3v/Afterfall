# Base das criaturas (jogador, zumbis): direção, sprite com ações estado_direção, vida e o
# frame de contato dos golpes. As subclasses respondem em _on_contact, _on_damaged e _on_died.
class_name Actor
extends CharacterBody2D

signal died

const CONTACT_FRAME := 2  # ações de golpe: 0 preparo, 1 golpe, 2 contato, 3 recuperação
const HIT_FLASH := Color(1.6, 0.6, 0.6)

@export var facing := Vector2.DOWN

var action := ""  # ação tocando (melee, shoot, attack, hurt...); trava a animação de movimento
var _contact_pending := false  # golpe esperando o frame de contato

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func is_dead() -> bool:
	return health.is_dead()


# Toca a ação estado_direção do início; contact = chama _on_contact no frame de contato.
# false se a sheet não tem a ação: quem chamou resolve na hora. Ação nova cancela golpe pendente.
func play_action(anim: String, contact := false) -> bool:
	if not Facing.play_action(sprite, anim, facing):
		return false
	action = anim
	_contact_pending = contact
	return true


func _on_frame_changed() -> void:
	if _contact_pending and sprite.frame == CONTACT_FRAME:
		_contact_pending = false
		_on_contact()


func _on_animation_finished() -> void:
	action = ""


func _on_contact() -> void:
	pass


# Piscar de dano num tween do próprio nó: some junto com ele, sem callback solto na árvore.
func _on_damaged(_amount: float, _source: Node) -> void:
	sprite.modulate = HIT_FLASH
	create_tween().tween_callback(func(): sprite.modulate = Color.WHITE).set_delay(0.1)


func _on_died() -> void:
	died.emit()
