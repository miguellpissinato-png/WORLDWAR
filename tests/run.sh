#!/usr/bin/env bash
# Roda todos os testes e falha também se aparecer qualquer erro de script.
# Uso: tests/run.sh   (variável GODOT aponta para o executável; padrão: godot)
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import > /dev/null 2>&1
out="$("$GODOT" --headless -s tests/run_tests.gd 2>&1)"
code=$?
echo "$out" | grep -v "^ *at: \|GDScript backtrace\|^ *\[[0-9]\]"
if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then
  echo "ERRO: houve erros de script durante os testes (veja acima)."
  exit 1
fi
exit $code
