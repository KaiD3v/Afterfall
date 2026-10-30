# Raiz de cada local (bairro, interior): piso dos passos, som ambiente e limites da câmera.
# Os zumbis e props do local são filhos dele e saem junto quando o jogador entra em outro.
class_name Location
extends Node2D

@export var surface := &"street"  # passos: street, wood
@export var ambience: AudioStream


# Retângulo do mapa em px, pela camada de chão (GroundHD: tiles HD reduzidos para 1 tile do mundo).
func bounds() -> Rect2i:
	var used: Rect2i = $GroundHD.get_used_rect()
	return Rect2i(Vector2i.ZERO, used.end * World.TILE)
