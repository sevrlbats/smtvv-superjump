# SMTVV Superjump

A flight mod for **Shin Megami Tensei V: Vengeance** (Steam / Windows).
Open source under the MIT License.

Hold **B** (controller) or **SPACE** (keyboard) while airborne to ascend, with
steering and turning (including 180s) in the air. Release to fall.

## Controls

| Input | Action |
|-------|--------|
| Hold **B** / **SPACE** | Fly upward and steer while airborne |
| **F8** | Toggle the mod off / on in-game |

## Install

1. Close the game.
2. Run `install.bat` and choose **[1] Install**. It auto-detects SMT5V in the
   usual Steam locations; if it can't, it asks you to paste your SMT5V folder
   path (Steam → right-click SMT5V → Manage → Browse local files, then copy the
   path from the address bar).
3. Launch the game, jump, and hold B / SPACE.

The prebuilt `xinput1_3.dll` is ready to use — no build step required.

## Uninstall

Run `uninstall.bat`, or choose **[2] Uninstall** in `install.bat`. (Or delete
`xinput1_3.dll` from `SMT5V\Project\Binaries\Win64\`.) Steam → Verify Integrity
of Game Files also removes it.

## Steam Deck / Linux

Steam Deck runs the game through Proton, so the mod works there — only the
installer differs. In **Desktop Mode**, open a terminal (Konsole) in this folder:

```bash
chmod +x install.sh
./install.sh
```

Then add this to the game's Steam **Launch Options** (Properties → General), or
Proton won't load the proxy DLL:

```text
WINEDLLOVERRIDES="xinput1_3=n,b" %command%
```

Uninstall with `./uninstall.sh`.

## How it works

The mod ships as `xinput1_3.dll`, a proxy DLL the game already imports. It
forwards every real XInput call untouched and runs its logic inside the game
process: it polls B / SPACE and, while either is held in the air, reverses the
player movement component's jump-gravity to ascend and drives the horizontal
velocity axis for steering. It modifies no executable bytes and no save data, so
it is safe to add or remove at any time.

## Building from source

Requires **Visual Studio Build Tools** with the "Desktop development with C++"
workload. Then:

```bat
build.bat
```

This compiles `src/` into `xinput1_3.dll` next to the script. Source layout:

- `src/xinput_proxy.cpp` — XInput proxy and DLL entry points
- `src/flight_backend.cpp` — input polling, movement hooks, ascent/steer logic
- `src/flight_backend.h`, `src/xinput_proxy.def`

`tools/` holds the offline reverse-engineering scripts used to locate the
movement-component reflection table and verify the hook addresses against the
shipping executable; `RESEARCH_NOTES.md` documents how it was done. (These are
research artifacts and contain machine-specific paths.)

## Notes

- Single-player quality-of-life mod. Don't use it in any online context.
- A small log is written next to the game EXE (handy for reporting issues).

## License

MIT — see [LICENSE](LICENSE). You are free to use, modify, and redistribute it.
