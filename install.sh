#!/usr/bin/env bash
#
# SMTVV Superjump - Linux / Steam Deck installer.
#
# Steam Deck runs the same Steam Windows build through Proton, so the mod works
# there - only the installer differs. Run this in Desktop Mode from a terminal:
#
#     chmod +x install.sh
#     ./install.sh
#
# IMPORTANT: the mod ships as a proxy DLL, which Proton only loads if you add a
# DLL override to the game's Steam Launch Options (the installer reminds you):
#
#     WINEDLLOVERRIDES="xinput1_3=n,b" %command%
#
set -euo pipefail

DLL="xinput1_3.dll"
EXE="SMT5V-Win64-Shipping.exe"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_game() {
    local c
    for c in \
        "$HOME/.local/share/Steam/steamapps/common/SMT5V" \
        "$HOME/.steam/steam/steamapps/common/SMT5V" \
        "$HOME/.steam/root/steamapps/common/SMT5V" \
        /run/media/*/steamapps/common/SMT5V \
        "$HERE/.." "$HERE/../.." ; do
        if [ -f "$c/Project/Binaries/Win64/$EXE" ]; then
            ( cd "$c" && pwd ); return 0
        fi
    done
    return 1
}

if [ ! -f "$HERE/$DLL" ]; then
    echo "ERROR: $DLL is missing from this folder."
    exit 1
fi

GAMEDIR="$(find_game || true)"
if [ -z "${GAMEDIR:-}" ]; then
    echo "Could not find SMT5V automatically."
    echo "In Steam: right-click SMT5V -> Properties -> Installed Files -> Browse,"
    echo "then paste that folder's path here."
    read -r -p "SMT5V folder: " GAMEDIR
    GAMEDIR="${GAMEDIR/#\~/$HOME}"
    GAMEDIR="${GAMEDIR%/}"
fi

BIN="$GAMEDIR/Project/Binaries/Win64"
if [ ! -f "$BIN/$EXE" ]; then
    echo "ERROR: $EXE not found under:"
    echo "  $BIN"
    exit 1
fi

cp -f "$HERE/$DLL" "$BIN/$DLL"
echo "Installed Superjump ($DLL) to:"
echo "  $BIN"
echo
echo "  ----------------------------------------------------------------"
echo "  Steam Deck / Proton: add this to the game's Steam Launch Options"
echo "  (SMT5V -> Properties -> General -> Launch Options) or it won't load:"
echo
echo '      WINEDLLOVERRIDES="xinput1_3=n,b" %command%'
echo
echo "  ----------------------------------------------------------------"
echo "Done. Launch the game, jump, and hold B / SPACE to fly."
