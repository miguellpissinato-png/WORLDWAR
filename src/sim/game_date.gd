class_name GameDate
extends RefCounted
## Converte o tempo do jogo (horas inteiras desde 1º/01/1936 00:00) em datas e vice-versa.

const EPOCH_YEAR := 1936
const MONTH_NAMES := ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]


static func is_leap(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


static func days_in_month(year: int, month: int) -> int:
	match month:
		2:
			return 29 if is_leap(year) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


static func days_in_year(year: int) -> int:
	return 366 if is_leap(year) else 365


## Horas desde a época para a data informada (mês e dia começam em 1).
static func to_hours(year: int, month: int, day: int, hour: int = 0) -> int:
	assert(year >= EPOCH_YEAR, "Datas antes de 1936 não são suportadas")
	var days := 0
	for y in range(EPOCH_YEAR, year):
		days += days_in_year(y)
	for m in range(1, month):
		days += days_in_month(year, m)
	days += day - 1
	return days * 24 + hour


## Data correspondente a um total de horas: {year, month, day, hour}.
static func from_hours(total_hours: int) -> Dictionary:
	var days := total_hours / 24
	var hour := total_hours % 24
	var year := EPOCH_YEAR
	while days >= days_in_year(year):
		days -= days_in_year(year)
		year += 1
	var month := 1
	while days >= days_in_month(year, month):
		days -= days_in_month(year, month)
		month += 1
	return {"year": year, "month": month, "day": days + 1, "hour": hour}


## Ex.: "1 jan 1936, 00:00"
static func format(total_hours: int) -> String:
	var d := from_hours(total_hours)
	return "%d %s %d, %02d:00" % [d.day, MONTH_NAMES[d.month - 1], d.year, d.hour]
