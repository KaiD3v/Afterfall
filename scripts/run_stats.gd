# Números de uma run, para a tela de resultado. Uma run nova começa com um RunStats novo.
class_name RunStats
extends RefCounted

var time := 0.0  # segundos vivo
var kills := 0
var looted := 0  # itens tirados de containers, munição incluída
