class_name NewsText
extends RefCounted
## Artigos e contrações em português para as manchetes ("declara guerra à França / ao Brasil").

const MASC := ["Brasil", "Japão", "Reino Unido", "Canadá", "México", "Peru", "Chile", "Egito", "Irã", "Iraque",
	"Afeganistão", "Tibete", "Sião", "Iêmen", "Nepal", "Butão", "Paraguai", "Uruguai", "Equador", "Panamá",
	"Haiti", "Luxemburgo", "Manchukuo", "Líbano", "Sudão", "Marrocos"]
const PLURAL := ["Estados Unidos", "Países Baixos", "Aliados"]   # inclui nomes de alianças
const NONE := ["Portugal", "Cuba", "Mascate e Omã", "Mônaco", "Israel", "Andorra", "Malta", "Honduras",
	"El Salvador", "Costa Rica", "Tuva"]


## "a", "o", "os", "as" ou "" (sem artigo).
static func art(name: String) -> String:
	if name in NONE:
		return ""
	if name in PLURAL:
		return "os"
	if name in MASC or name.begins_with("Reino") or name.begins_with("Império"):
		return "o"
	# o gênero vem da primeira palavra: "a África do Sul", "a Nova Zelândia"
	var first := name.split(" ")[0]
	if first.ends_with("as"):
		return "as"
	if first.ends_with("a") or first.begins_with("República") or first.begins_with("União"):
		return "a"
	return "o"


## "a Alemanha", "o Brasil", "Portugal" (maiúscula com cap = true).
static func the(name: String, cap: bool = false) -> String:
	var a := art(name)
	if a == "":
		return name
	return ("%s %s" % [a.capitalize() if cap else a, name])


## "à França", "ao Brasil", "aos Estados Unidos", "a Portugal".
static func to(name: String) -> String:
	match art(name):
		"a": return "à " + name
		"o": return "ao " + name
		"os": return "aos " + name
		"as": return "às " + name
	return "a " + name


## "pela França", "pelo Brasil", "pelos Estados Unidos", "por Portugal".
static func by(name: String) -> String:
	match art(name):
		"a": return "pela " + name
		"o": return "pelo " + name
		"os": return "pelos " + name
		"as": return "pelas " + name
	return "por " + name


## "da França", "do Brasil", "dos Estados Unidos", "de Portugal".
static func of(name: String) -> String:
	match art(name):
		"a": return "da " + name
		"o": return "do " + name
		"os": return "dos " + name
		"as": return "das " + name
	return "de " + name
