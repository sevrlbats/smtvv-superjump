#!/usr/bin/env bash
#
# SMTVV Superjump - Linux / Steam Deck uninstaller. Removes the proxy DLL.
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

GAMEDIR="$(find_game || true)"
if [ -z "${GAMEDIR:-}" ]; then
    read -r -p "SMT5V folder: " GAMEDIR
    GAMEDIR="${GAMEDIR/#\~/$HOME}"
    GAMEDIR="${GAMEDIR%/}"
fi

BIN="$GAMEDIR/Project/Binaries/Win64"
if [ -f "$BIN/$DLL" ]; then
    rm -f "$BIN/$DLL"
    echo "Removed $DLL from:"
    echo "  $BIN"
else
    echo "$DLL was not present; nothing to remove."
fi
echo "(You can also remove the WINEDLLOVERRIDES launch option.)"
