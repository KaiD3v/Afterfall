# Números de uma run, para a tela de resultado. Uma run nova começa com um RunStats novo.
# O relógio de jogo sai de time: 24 h de jogo = DAY_SECONDS reais (1 h = 1 min 15 s). Como time só
# anda com o jogo rodando, o relógio para quando a árvore pausa e na morte.
class_name RunStats
extends RefCounted

signal minute_changed  # minuto de jogo virou (a cada 1,25 s reais): a HUD redesenha o relógio

const DAY_SECONDS := 1800.0  # segundos reais por dia de jogo
const START_HOUR := 8  # hora em que a run começa (confirmada pelo autor em 2026-10-30)

var time := 0.0:  # segundos vivo
	set(value):
		var before := minute()
		time = value
		if minute() != before:
			minute_changed.emit()
var kills := 0
var looted := 0  # itens tirados de containers, munição incluída
var cause := ""  # causa da morte (zumbi, fome, sede, fome e sede)


# Segundos de jogo desde 00:00 do primeiro dia.
func clock() -> float:
	return START_HOUR * 3600.0 + time * 86400.0 / DAY_SECONDS


# Dias sobrevividos: quantas vezes o relógio passou de 00:00. O dia corrente é days() + 1.
func days() -> int:
	return int(clock() / 86400.0)


# Minuto do dia corrente (0 a 1439).
func minute() -> int:
	return int(fmod(clock(), 86400.0) / 60.0)
