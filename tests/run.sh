#!/usr/bin/env bash
# Ejecuta los tests headless. Uso: tests/run.sh [patrón]   (ej. tests/run.sh clock)
# Descarga Godot 4.3 a la caché del usuario si no hay binario (o define GODOT=/ruta).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="4.3-stable"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/godot-$VERSION"
GODOT="${GODOT:-$CACHE/Godot_v${VERSION}_linux.x86_64}"

if [ ! -x "$GODOT" ]; then
	echo "Descargando Godot $VERSION en $CACHE..."
	mkdir -p "$CACHE"
	curl -sSL -o "$CACHE/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/$VERSION/Godot_v${VERSION}_linux.x86_64.zip" \
		&& unzip -o -q "$CACHE/godot.zip" -d "$CACHE" && rm "$CACHE/godot.zip" || { echo "Fallo al descargar Godot"; exit 2; }
fi

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

# Ruido conocido del renderer dummy de --headless con PrimitiveMesh; no afecta al juego.
NOISE='Parameter "m" is null|mesh_get_surface_count'

failed=0
for test in "$ROOT"/tests/test_*${1:-}*.gd; do
	name="$(basename "$test")"
	[ "$name" = "test_base.gd" ] && continue
	output="$(timeout 120 "$GODOT" --headless --path "$ROOT" -s "res://tests/$name" 2>&1)"
	code=$?
	errors="$(echo "$output" | grep -E "SCRIPT ERROR|ERROR:|FAIL" | grep -vE "$NOISE")"
	if [ $code -ne 0 ] || [ -n "$errors" ]; then
		echo "✗ $name (exit $code)"
		echo "$output" | grep -vE "$NOISE" | sed 's/^/    /'
		failed=1
	else
		echo "✓ $name"
	fi
done
exit $failed
