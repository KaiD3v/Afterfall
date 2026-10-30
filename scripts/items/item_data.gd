# Um tipo de item. Item novo = um .tres; efeito de uso novo = subclasse com use().
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""  # aparece no menu do inventário
@export var icon: Texture2D  # quadro de 128×128 (escala 0,25 = um slot de 32×32)
@export var use_sound: AudioStream  # toca no menu quando o item é usado


# Ao pegar do container: true = ocupa um slot do inventário; false = efeito na hora (munição).
func on_pickup(_user: Node) -> bool:
	return true


# Uso pelo inventário (tecla Q ou botão direito no menu). true = gastou o item.
func use(_user: Node) -> bool:
	return false


# Tipo mostrado na ficha do menu ("Consumível", "Arma branca"...).
func type_name() -> String:
	return "Item"


# Números da ficha do menu, lidos dos dados: cada linha é stat(rótulo, valor, texto, maior_melhor),
# com o valor já na unidade do texto (a diferença na comparação sai na mesma unidade).
# A comparação com o item equipado casa as linhas pelo rótulo.
func stats() -> Array[Dictionary]:
	return []


static func stat(label: String, value: float, text: String, higher_is_better := true) -> Dictionary:
	return {"label": label, "value": value, "text": text, "higher_is_better": higher_is_better}


# Número com vírgula decimal e sem casas inúteis: 0,5 · 10 · 1,5.
static func num(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0").replace(".", ",")
