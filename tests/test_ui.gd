# Checagem da Fase A: animações por estado e direção, golpe no frame de contato,
# foco e aviso dos interagíveis, mira e barramentos de áudio.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_ui.gd
extends SceneTree

const HZ := 60.0
var main: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	main = load("res://scenes/main.tscn").instantiate()
	for z in main.get_node("Zombies").get_children():  # cada caso monta os próprios zumbis
		z.free()
	root.add_child(main)
	player = main.get_node("Player")
	hud = main.get_node("HUD")
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	rs.new_run()
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	# 1. Animações: estado_direção com fallback para idle_direção.
	check("direções", Facing.dir_name(Vector2.LEFT) == "left" and Facing.dir_name(Vector2(0.3, -1)) == "up" and Facing.dir_name(Vector2(1, 1)) == "right")
	player.position = Vector2(760, 592)
	await hold("move_left", 0.2)
	check("andando sem walk_* na sheet: idle_left (%s)" % sprite.animation, sprite.animation == &"idle_left")

	# 2. Golpe no frame de contato quando existe melee_*.
	var frames: SpriteFrames = sprite.sprite_frames.duplicate()
	frames.add_animation(&"melee_right")
	frames.set_animation_loop(&"melee_right", false)
	frames.set_animation_speed(&"melee_right", 10.0)
	for i in 4:
		frames.add_frame(&"melee_right", frames.get_frame_texture(&"idle_right", 0))
	sprite.sprite_frames = frames
	var z: Node = load("res://scenes/zombie/zombie.tscn").instantiate()
	z.position = player.position + Vector2(24, 0)
	z.facing = Vector2.LEFT
	main.add_child(z)
	await physics_frame
	player.facing = Vector2.RIGHT
	check("golpe aceito", player.melee())
	check("sem dano antes do contato", z.health == 60.0)
	await frames_for(0.25)  # 10 fps: frame 2 (contato) em 0,2 s
	check("dano no frame de contato (vida %.0f)" % z.health, z.health == 35.0)
	await frames_for(0.3)
	check("ação termina e volta ao idle (%s)" % sprite.animation, player._action == "" and String(sprite.animation).begins_with("idle"))
	z.queue_free()

	# 3. Foco e aviso: porta do bairro.
	player.position = main.get_node("Neighborhood/HouseExit").position
	await physics_frame
	await process_frame
	check("porta em foco com aviso", player.focus != null and hud.get_node("Prompt").visible and hud.get_node("Prompt").text == "E · Entrar")
	player.position = Vector2(760, 592)
	await settle()
	check("longe de tudo: sem foco e sem aviso", player.focus == null and not hud.get_node("Prompt").visible)

	# 4. Foco em container: contorno, aviso, e apagado depois de vazio.
	player.position = main.get_node("Neighborhood/HouseExit").position
	player.interact()
	await frames_for(0.7)
	var box: Node = main.interior.get_node("Armario")
	box.table = LootTable.new()
	box.table.items = [&"bandage"] as Array[StringName]
	box.table.weights = [1.0] as Array[float]
	player.position = box.position + Vector2(0, 22)
	await physics_frame
	await process_frame
	check("container em foco: contorno e aviso", box.get_node("Focus").visible and hud.get_node("Prompt").text == "E · Abrir Armário")
	player.interact()
	await process_frame
	check("vazio: apagado e aviso muda", box.is_looted() and box.modulate.r < 1.0 and hud.get_node("Prompt").text == "Armário (vazio)")
	player.position = main.interior.get_node("PlayerSpawn").position
	await settle()
	check("saiu do alcance: contorno some", not box.get_node("Focus").visible)
	player.interact()
	await frames_for(0.7)
	await process_frame
	check("sem erro com o foco liberado na troca de cena", main.interior == null)

	# 5. Mira: dispersão cresce com a distância; cor avisa pente vazio; cursor escondido.
	var cross: Node2D = hud.get_node("Crosshair")
	check("abertura a 100 px = 7 px (±4°)", cross.gap_at(100.0) == 7.0)
	check("abertura a 300 px = 21 px", cross.gap_at(300.0) == 21.0)
	check("abertura mínima de perto", cross.gap_at(10.0) == cross.MIN_GAP)
	player.ammo = 0
	check("pente vazio muda a cor", cross.color_now() == cross.EMPTY)
	player.ammo = player.mag_size
	# headless não tem mouse e ignora o modo do cursor; só dá para checar com janela
	if DisplayServer.get_name() != "headless":
		check("cursor do sistema escondido", Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)

	# 6. Áudio: canais próprios; efeitos no SFX.
	check("canais SFX, Ambience e Steps", AudioServer.get_bus_index(&"SFX") > 0 and AudioServer.get_bus_index(&"Ambience") > 0 and AudioServer.get_bus_index(&"Steps") > 0)
	check("efeitos no canal SFX", player.get_node("SfxShot").bus == &"SFX" and main.get_node("SfxDoor").bus == &"SFX")

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


# physics_frame dispara antes do _physics_process dos nós: espera dois para o foco atualizar.
func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await frames_for(seconds)
	Input.action_release(action)


func frames_for(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
