extends TestCase


func test_epoch_is_zero() -> void:
	assert_eq(GameDate.to_hours(1936, 1, 1), 0)


func test_1936_is_leap_year() -> void:
	assert_eq(GameDate.to_hours(1937, 1, 1), 366 * 24)


func test_round_trip_1939() -> void:
	var h := GameDate.to_hours(1939, 9, 1, 5)
	assert_eq(GameDate.from_hours(h), {"year": 1939, "month": 9, "day": 1, "hour": 5})


func test_end_of_february_leap() -> void:
	assert_eq(GameDate.from_hours(GameDate.to_hours(1936, 2, 29)).day, 29)
	assert_eq(GameDate.from_hours(GameDate.to_hours(1936, 3, 1)).month, 3)


func test_format() -> void:
	assert_eq(GameDate.format(0), "1 jan 1936, 00:00")
	assert_eq(GameDate.format(GameDate.to_hours(1945, 12, 31, 23)), "31 dez 1945, 23:00")
