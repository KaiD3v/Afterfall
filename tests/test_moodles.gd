# Checagem do S4: moodles na HUD. Fome e sede: ícone âmbar abaixo de 25%, crítico (fundo de sangue,
# piscando) zeradas; cansaço: âmbar com 16 h acordado, crítico com 24 h. Sem moodle, a linha fica
# vazia; os ativos se juntam à esquerda; comer, beber e dormir fazem o ícone sumir. A linha cabe
# na tela sem cobrir o painel nem o relógio.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_moodles.gd
extends SceneTree

var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	var main: Node2D = current_scene
	var needs: Node = main.get_node("Player").needs
	var hud: Node = main.get_node("HUD")
	var row: Container = hud.get_node("Moodles")
	var hunger: Control = row.get_node("Hunger")
	var thirst: Control = row.get_node("Thirst")
	var tired: Control = row.get_node("Tired")
	for z in get_nodes_in_group("zombies"):
		z.queue_free()
	needs.set_process(false)  # os valores são postos à mão; o sinal changed redesenha a HUD

	check("começo da run: nenhum moodle", not hunger.visible and not thirst.visible and not tired.visible)

	needs.hunger = 30.0
	check("fome em 30%: sem moodle", not hunger.visible)
	needs.hunger = 20.0
	check("fome em 20%: moodle âmbar", hunger.visible and hunger.color == hud.AMBER and hunger.bg == hud.BADGE_BG and not hud._blink.has(hunger))
	needs.hunger = 0.0
	check("fome zerada: crítico, fundo de sangue e piscando", hunger.visible and hunger.bg == hud.BLOOD and hud._blink.has(hunger))
	await frames(0.5)
	check("o piscar mexe na transparência (%.2f)" % hunger.modulate.a, hunger.modulate.a < 1.0)
	needs.eat(50.0)
	check("comeu: o moodle some e para de piscar", not hunger.visible and not hud._blink.has(hunger) and hunger.modulate.a == 1.0)

	needs.thirst = 10.0
	await process_frame
	check("só a sede ativa: ela fica na primeira posição (x %.0f)" % thirst.position.x, thirst.visible and thirst.position.x == 0.0)
	needs.hunger = 10.0
	await process_frame
	check("fome e sede: lado a lado, fome primeiro", hunger.position.x == 0.0 and thirst.position.x == 11.0)

	needs.awake = 15.9
	needs.thirst = 10.5  # o sinal changed vem da fome e da sede
	check("15,9 h acordado: sem cansaço", not tired.visible)
	needs.awake = 16.0
	needs.thirst = 11.0
	check("16 h acordado: cansaço âmbar", tired.visible and tired.bg == hud.BADGE_BG)
	needs.awake = 24.0
	needs.thirst = 11.5
	check("24 h acordado: cansaço crítico", tired.visible and tired.bg == hud.BLOOD and hud._blink.has(tired))
	needs.awake = 14.0
	needs.hunger = 100.0
	needs.thirst = 100.0
	needs.sleep()
	check("dormiu: o cansaço some; a sede caiu para 20%% e acende (fome %.0f, sede %.0f)" % [needs.hunger, needs.thirst], not tired.visible and not hunger.visible and thirst.visible and not hud._blink.has(tired))

	# Legível: a linha fica abaixo do painel, dentro da tela, longe do relógio.
	var panel: Rect2 = hud.get_node("TopBorder").get_rect()
	needs.hunger = 0.0
	needs.thirst = 0.0
	needs.awake = 30.0
	needs.eat(0.0)
	needs.hunger = 0.0001
	await process_frame
	var used := Rect2(row.position, Vector2(tired.position.x + 9.0, 9.0))
	check("três moodles: linha %s abaixo do painel %s" % [used, panel], used.position.y >= panel.end.y and used.end.x <= panel.end.x)
	check("e longe do relógio", not used.intersects(hud.get_node("Clock").get_rect()))

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func frames(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
