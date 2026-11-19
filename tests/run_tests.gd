extends SceneTree
## Executa todos os tests/test_*.gd. Uso: godot --headless -s tests/run_tests.gd


func _init() -> void:
	var total := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file in files:
		if file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("  FALHA %s :: não compilou" % file)
			continue
		for m in script.get_script_method_list():
			if not m.name.begins_with("test_"):
				continue
			var t = script.new()
			t.call(m.name)
			total += 1
			if t.failures.is_empty():
				print("  ok    %s :: %s" % [file, m.name])
			else:
				failed += 1
				print("  FALHA %s :: %s" % [file, m.name])
				for f in t.failures:
					print("        - " + f)
	print("\n%d testes, %d falhas" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
