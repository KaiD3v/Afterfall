#!/usr/bin/env bash
# Roda todos os testes automáticos. Uso: tools/run_tests.sh [caminho do Godot console]
cd "$(dirname "$0")/.."
G="${1:-/c/Users/kaikr/Desktop/Godot_v4.7.2-stable_win64_console.exe}"
fail=0
for t in tests/test_*.gd; do
	out=$(timeout 180 "$G" --headless --path . --fixed-fps 60 --script "res://$t" 2>&1)
	echo "$out" | grep -q "RESULT: PASS" && ! echo "$out" | grep -q "SCRIPT ERROR" && r=PASS || { r=FAIL; fail=1; }
	printf "%-28s %s\n" "$(basename "$t")" "$r"
	[ $r = FAIL ] && echo "$out" | grep -E "^FAIL|SCRIPT ERROR|at: res"
done
python -I tools/test_check_sprites.py || fail=1
exit $fail
