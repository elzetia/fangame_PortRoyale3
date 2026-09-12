#!/bin/sh
# Lance Port Royale : Under the wind sur macOS / Linux, l'equivalent de `jouer.bat`.
#
# Godot est cherche dans $GODOT, puis aux endroits habituels, puis dans le PATH.
#   ./jouer.sh                  la scene principale
#   ./jouer.sh --compat         renderer Compatibility (voir plus bas)
#   ./jouer.sh -- --sans-mer    argument passe au jeu, pas au moteur
#
# SUR MAC INTEL, IL FAUT --compat. MoltenVK n'y compile pas les pipelines de
# calcul du renderer Forward+ : Godot echoue sur
#   « AIR builtin function was called but no definition was found »
# puis reste vivant sans jamais ouvrir de fenetre. Compatibility demarre, au
# prix de l'anti-aliasing ecran et de la fidelite des shaders de mer.
set -e
RACINE=$(cd "$(dirname "$0")" && pwd)

trouver_godot() {
	[ -n "$GODOT" ] && { echo "$GODOT"; return; }
	for c in \
		/Applications/Godot.app/Contents/MacOS/Godot \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		/Applications/Godot_mono.app/Contents/MacOS/Godot
	do
		[ -x "$c" ] && { echo "$c"; return; }
	done
	for n in godot godot4 Godot; do
		command -v "$n" >/dev/null 2>&1 && { command -v "$n"; return; }
	done
}

GODOT_BIN=$(trouver_godot || true)
if [ -z "$GODOT_BIN" ]; then
	echo "Godot introuvable. Installe-le, ou indique-le :" >&2
	echo "  GODOT=/chemin/vers/Godot ./jouer.sh" >&2
	exit 1
fi

MOTEUR=""
JEU=""
for a in "$@"; do
	case "$a" in
		--compat) MOTEUR="--rendering-method gl_compatibility" ;;
		--) shift; JEU="$*"; break ;;
		*) MOTEUR="$MOTEUR $a" ;;
	esac
done

# shellcheck disable=SC2086
if [ -n "$JEU" ]; then
	exec "$GODOT_BIN" --path "$RACINE" $MOTEUR -- $JEU
else
	exec "$GODOT_BIN" --path "$RACINE" $MOTEUR
fi
