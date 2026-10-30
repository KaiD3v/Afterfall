# Checagem do S5: frio e noite. Pelo laço real: de dia e dentro da casa não há frio; à noite, fora,
# o frio acumula 1 por hora de jogo; com 1 h o selo do retrato aparece, com 3 h pisca e tira vida
# (100 em 2 h); abrigar baixa no mesmo ritmo; dormir passa o frio; morrer assim dá "Causa: frio".
# O bairro escurece à noite e clareia de dia; o interior não muda.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_cold.gd
extends SceneTree

const HZ := 60
const HOUR := 75 * HZ  # quadros por hora de jogo
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
	var player: CharacterBody2D = main.get_node("Player")
	var needs: Node = player.needs
	var seal: Control = main.get_node("HUD/Temperature")
	var tint: CanvasModulate = main.get_node("Neighborhood/AtmosphereModulate")
	var day_tint := tint.color
	for z in get_nodes_in_group("zombies"):
		z.queue_free()

	# De dia, fora: sem frio; o bairro com a cor de dia.
	await hours(2.0, needs)
	check("10:00 fora: sem frio, sem selo", needs.cold == 0.0 and not seal.visible)
	check("de dia, o bairro na cor de dia", tint.color == day_tint)

	# 20:00, fora: o frio acumula; selo em 1 h, crítico em 3 h.
	_set_hour(20.0)
	await process_frame
	check("20:00: o bairro escureceu (%.2f)" % tint.color.v, tint.color.v < day_tint.v * 0.7)
	await hours(0.95, needs)
	check("0,95 h no frio: ainda sem selo (frio %.2f)" % needs.cold, not seal.visible)
	await hours(0.1, needs)
	check("1 h no frio: selo do floco no retrato (frio %.2f)" % needs.cold, seal.visible and not main.get_node("HUD")._blink.has(seal))
	var hp: float = player.health.current
	await hours(1.9, needs)
	check("2,95 h: ainda não fere", player.health.current == hp)
	await hours(1.05, needs)
	check("3 h no frio: o selo pisca", main.get_node("HUD")._blink.has(seal))
	hp = player.health.current
	await hours(1.0, needs)
	check("frio crítico tira 50 de vida por hora (%.2f)" % (hp - player.health.current), absf(hp - player.health.current - 50.0) < 1.0)
	check("o frio não passa de 3 h (%.2f)" % needs.cold, needs.cold == needs.cold_hurts)

	# Abrigado (casa): o frio baixa no mesmo ritmo, mesmo de noite; o bairro escuro não pesa lá dentro.
	player.health.heal(100.0)
	player.position = main.get_node("Neighborhood/HouseExit").position
	player.interact()
	await frames(0.7)
	check("na casa: abrigado", needs.sheltered and main.is_inside())
	await hours(1.0, needs)
	check("1 h abrigado: o frio baixa 1 h (%.2f)" % needs.cold, absf(needs.cold - 2.0) < 0.05 and not main.get_node("HUD")._blink.has(seal))
	needs.sleep()
	check("dormir passa o frio", needs.cold == 0.0)
	player.position = main.location.get_node("PlayerSpawn").position
	player.interact()
	await frames(0.7)
	check("de volta ao bairro: sem abrigo", not needs.sheltered)

	# 07:00 clareia, 09:00 dia pleno; e 23:00 fora com frio crítico mata: "Causa: frio".
	_set_hour(6.5)
	await process_frame
	var dawn := tint.color.v
	_set_hour(9.0)
	await process_frame
	check("o dia volta: 06:30 ainda escuro (%.2f), 09:00 na cor de dia" % dawn, dawn < day_tint.v and tint.color == day_tint)
	_set_hour(23.0)
	await process_frame
	check("23:00: noite fechada", tint.color == main.NIGHT_TINT)
	needs.cold = needs.cold_hurts
	for i in 300 * HZ:
		if main.get_node("HUD/Result").visible:
			break
		needs.eat(100.0)
		needs.drink(100.0)
		await process_frame
	check("morre de frio: \"%s\"" % main.get_node("HUD/Result/Text").text.get_slice("\n", 2), "Causa: frio ·" in main.get_node("HUD/Result/Text").text)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


# Põe o relógio na hora h do dia corrente (o tempo vivo é o que move o relógio).
func _set_hour(h: float) -> void:
	var day_start: float = rs.stats.time - (rs.stats.clock() - rs.stats.days() * 86400.0) / 48.0
	rs.stats.time = day_start + h * 75.0


# Roda h horas de jogo quadro a quadro, sem fome nem sede no caminho.
func hours(h: float, needs: Node) -> void:
	for i in int(h * HOUR):
		needs.eat(100.0)
		needs.drink(100.0)
		await process_frame


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
