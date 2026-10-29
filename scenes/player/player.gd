# Andador do greybox: só move nas 4 direções a velocidade fixa. Vida e stamina entram no M3.
extends CharacterBody2D

@export var speed := 80.0  # px/s = 2,5 tiles/s; valor inicial, ajustar no playtest

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	if dir != Vector2.ZERO:
		# frames do character.png: 0 baixo, 1 esquerda, 2 direita, 3 cima
		if absf(dir.x) >= absf(dir.y):
			sprite.frame = 1 if dir.x < 0 else 2
		else:
			sprite.frame = 3 if dir.y < 0 else 0
