# Checagem da Fase A: animações por estado e direção, golpe no frame de contato,
# foco e aviso dos interagíveis, mira e barramentos de áudio.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_ui.gd
extends SceneTree

const BANDAGE := preload("res://data/items/bandage.tres")

const HZ := 60.0
var main: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	main = load("res://scenes/main.tscn").instantiate()
	for z in main.get_node("Neighborhood/Zombies").get_children():  # cada caso monta os próprios zumbis
		z.free()
	root.add_child(main)
	player = main.get_node("Player")
	hud = main.get_node("HUD")
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	rs.new_run()
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	# 1. Animações, com sheets de teste (independem da arte real): só down/right/up,
	# a esquerda vem da direita espelhada.
	check("direções", Facing.dir_name(Vector2.LEFT) == "left" and Facing.dir_name(Vector2(0.3, -1)) == "up" and Facing.dir_name(Vector2(1, 1)) == "right")
	var tex := sprite.sprite_frames.get_frame_texture(&"idle_right", 0)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for d in ["down", "right", "up"]:
		add_anim(frames, "idle_" + d, tex, 1, true)
	sprite.sprite_frames = frames
	player.position = Vector2(760, 592)
	await hold("move_left", 0.2)
	check("sem walk_*: idle_right espelhado para a esquerda (%s, flip %s)" % [sprite.animation, sprite.flip_h], sprite.animation == &"idle_right" and sprite.flip_h)

	add_anim(frames, "walk_right", tex, 4, true)
	var steps0: int = player.steps_taken
	await hold("move_left", 0.45)  # 10 fps: frames 0..3, contato em 0 e 2
	check("andando para a esquerda: walk_right espelhado", sprite.animation == &"walk_right" and sprite.flip_h)
	check("passos nos frames de contato (%d)" % (player.steps_taken - steps0), player.steps_taken - steps0 >= 2)
	check("passo na rua usa o som da rua", player.get_node("SfxSteps").stream == player.STEPS[&"street"])
	await hold("move_right", 0.1)
	check("para a direita: sem espelho", sprite.animation == &"walk_right" and not sprite.flip_h)
	Input.action_press("sprint")
	await hold("move_right", 0.1)
	Input.action_release("sprint")
	check("correndo, o ciclo acelera (%.3f)" % sprite.speed_scale, is_equal_approx(sprite.speed_scale, player.run_speed / player.walk_speed))
	await frames_for(0.1)
	check("parado: idle", sprite.animation == &"idle_right" and sprite.speed_scale == 1.0)

	for d in ["down", "right", "up"]:
		add_anim(frames, "aim_" + d, tex, 4, true)
		add_anim(frames, "aim_walk_" + d, tex, 4, true)
		add_anim(frames, "reload_" + d, tex, 4, false)
	var x_aim0 := player.position.x
	Input.action_press("aim")
	await hold("move_right", 0.5)
	Input.action_release("aim")
	check("andando e mirando: aim_walk e velocidade reduzida (~50 px/s)", String(sprite.animation).begins_with("aim_walk") and is_equal_approx(sprite.speed_scale, player.aim_walk_speed / player.walk_speed) and absf((player.position.x - x_aim0) / 0.5 - player.aim_walk_speed) < 4.0)
	await frames_for(0.1)

	# 2. Golpe no frame de contato quando existe melee_*.
	add_anim(frames, "melee_right", tex, 4, false)
	player.position = Vector2(760, 592)
	var z: Node = load("res://scenes/zombie/zombie.tscn").instantiate()
	z.position = player.position + Vector2(24, 0)
	z.facing = Vector2.LEFT
	main.add_child(z)
	await physics_frame
	player.facing = Vector2.RIGHT
	check("golpe aceito", player.melee())
	check("sem dano antes do contato", z.health.current == 60.0)
	await frames_for(0.25)  # 10 fps: frame 2 (contato) em 0,2 s
	check("dano no frame de contato (vida %.0f)" % z.health.current, z.health.current == 35.0)
	await frames_for(0.3)
	check("ação termina e volta ao idle (%s)" % sprite.animation, player.action == "" and String(sprite.animation).begins_with("idle"))
	z.queue_free()

	# 2b. Cano da pistola: ponto do JSON (frame 48×48) vira posição no mundo; esquerda espelha.
	frames.set_meta("muzzle", {"down": [24, 30], "right": [40, 20], "up": [24, 10]})
	frames.set_meta("muzzle_frame", Vector2(48, 48))
	player.facing = Vector2.RIGHT
	check("cano à direita", player.muzzle_position() == player.global_position + Vector2(16, -18))
	player.facing = Vector2.LEFT
	check("cano à esquerda espelhado", player.muzzle_position() == player.global_position + Vector2(-16, -18))

	# 2c. Zumbi com sheet de teste: mordida no frame de contato (dá para esquivar), tranco, morte.
	await zombie_cases(tex)

	# 3. Foco e aviso: porta do bairro.
	player.position = main.get_node("Neighborhood/HouseExit").position
	await physics_frame
	await process_frame
	check("porta em foco com aviso", player.focus != null and hud.get_node("Prompt").visible and hud.get_node("Prompt").text == "F · Entrar")
	player.position = Vector2(760, 592)
	await settle()
	check("longe de tudo: sem foco e sem aviso", player.focus == null and not hud.get_node("Prompt").visible)

	# 4. Foco em container: contorno, aviso, e apagado depois de vazio.
	player.position = main.get_node("Neighborhood/HouseExit").position
	player.interact()
	await frames_for(0.7)
	var box: Node = main.location.get_node("Armario")
	box.table = LootTable.new()
	box.table.items.assign([BANDAGE])
	box.table.weights = [1.0] as Array[float]
	check("dentro da casa: passos de madeira", player.surface == &"wood")
	player.position = box.position + Vector2(0, 22)
	await physics_frame
	await process_frame
	check("container em foco: contorno e aviso", box.get_node("Focus").visible and hud.get_node("Prompt").text == "F · Abrir Armário")
	player.interact()
	main.get_node("InventoryMenu").take_all()
	main.get_node("InventoryMenu").close()
	await physics_frame
	await process_frame
	check("vazio: apagado e aviso muda", box.is_looted() and box.modulate.r < 1.0 and hud.get_node("Prompt").text == "Armário (vazio)")
	player.position = main.location.get_node("PlayerSpawn").position
	await settle()
	check("saiu do alcance: contorno some", not box.get_node("Focus").visible)
	player.interact()
	await frames_for(0.7)
	await process_frame
	check("sem erro com o foco liberado na troca de cena", not main.is_inside())
	check("de volta à rua: passos da rua", player.surface == &"street")

	# 5. Mira: dispersão cresce com a distância e ao andar mirando; cor avisa pente vazio; cursor escondido.
	var cross: Node2D = hud.get_node("Crosshair")
	check("abertura a 100 px = 7 px (±4°)", cross.gap_at(100.0) == 7.0)
	check("abertura a 300 px = 21 px", cross.gap_at(300.0) == 21.0)
	check("abertura mínima de perto", cross.gap_at(10.0) == cross.MIN_GAP)
	Input.action_press("move_right")
	await physics_frame  # physics_frame sai antes do _physics_process: 2 frames para o jogador ler
	await physics_frame
	check("andando mirando: dispersão aumenta (±9° -> 16 px a 100 px)", player.firearm.spread_now() > player.firearm.gun().spread and cross.gap_at(100.0) == 16.0)
	Input.action_release("move_right")
	await physics_frame
	Input.action_press("flashlight")
	await physics_frame
	await physics_frame
	Input.action_release("flashlight")
	check("tecla T desliga a lanterna", not player.flashlight.on and not player.get_node("Flashlight").visible)
	Input.action_press("flashlight")
	await physics_frame
	await physics_frame
	Input.action_release("flashlight")
	check("tecla T religa a lanterna", player.flashlight.on and player.get_node("Flashlight").visible)
	player.firearm.ammo = 0
	check("pente vazio muda a cor", cross.color_now() == cross.EMPTY)
	player.firearm.ammo = player.firearm.gun().mag_size
	# headless não tem mouse e ignora o modo do cursor; só dá para checar com janela
	if DisplayServer.get_name() != "headless":
		check("cursor do sistema escondido", Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)

	# 6. Áudio: canais próprios; efeitos no SFX.
	check("canais SFX, Ambience e Steps", AudioServer.get_bus_index(&"SFX") > 0 and AudioServer.get_bus_index(&"Ambience") > 0 and AudioServer.get_bus_index(&"Steps") > 0)
	var gun_sounds: Array = player.firearm.get_children().filter(func(c): return c is AudioStreamPlayer2D)
	check("efeitos no canal SFX (tiro, recarga, porta)", gun_sounds.size() == 2 and gun_sounds.all(func(c): return c.bus == &"SFX") and main.get_node("SfxDoor").bus == &"SFX")

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


# physics_frame dispara antes do _physics_process dos nós: espera dois para o foco atualizar.
func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func zombie_cases(tex: Texture2D) -> void:
	var zf := SpriteFrames.new()
	zf.remove_animation(&"default")
	for d in ["down", "right", "up"]:
		add_anim(zf, "idle_" + d, tex, 1, true)
	add_anim(zf, "attack_right", tex, 4, false)  # 10 fps: contato (frame 2) em 0,2 s
	add_anim(zf, "hurt_right", tex, 2, false)
	add_anim(zf, "death_right", tex, 5, false)
	var spawn := func(offset: Vector2) -> Node:
		var zz: Node = load("res://scenes/zombie/zombie.tscn").instantiate()
		zz.position = player.position + offset
		zz.facing = Vector2.LEFT
		main.add_child(zz)
		zz.get_node("Sprite").sprite_frames = zf
		return zz

	player.position = Vector2(760, 592)
	player.health.current = player.health.maximum
	var z: Node = spawn.call(Vector2(18, 0))
	await frames_for(0.1)
	check("zumbi começa a morder (%s)" % z.action, z.action == "attack")
	check("sem dano no preparo", player.health.current == 100.0)
	await frames_for(0.25)
	check("dano no contato da mordida (vida %.0f)" % player.health.current, player.health.current == 85.0)
	for i in 120:  # espera a próxima mordida começar (frame 0, o preparo)
		if z.action == "attack" and z.get_node("Sprite").frame == 0:
			break
		await physics_frame
	var hp: float = player.health.current
	player.position.x -= 60.0  # recua no preparo, antes do contato
	await frames_for(0.35)
	check("recuar no preparo esquiva (vida %.0f → %.0f)" % [hp, player.health.current], player.health.current == hp)
	player.position = z.position + Vector2(-18, 0)
	z.health.damage(10.0)
	check("tranco ao apanhar", z.action == "hurt")
	await physics_frame
	await physics_frame
	check("parado durante o tranco", z.velocity == Vector2.ZERO)
	await frames_for(0.3)
	check("tranco termina", z.action != "hurt")
	z.health.damage(100.0)
	check("morte toca a animação", z.action == "death" and z.get_node("Sprite").animation == &"death_right")
	await frames_for(1.2)  # 5 frames a 10 fps + fade de 0,4 s
	check("corpo some depois de cair", not is_instance_valid(z))
	player.health.current = player.health.maximum


func add_anim(frames: SpriteFrames, anim: String, tex: Texture2D, count: int, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, 10.0)
	for i in count:
		frames.add_frame(anim, tex)


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
