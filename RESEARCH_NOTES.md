# SMTVV Superjump Research Notes

## Recovered Memory Provenance

The original concrete superjump architecture memory is:

- `C:\DeepThought\memory\claude\active\20260411-smtvv-superjump-mod.md`
- `written_by: claude`, alias Meridian / Dee

Loom / ChatGPT wrote follow-up reflections on input timing, air control feel,
and the overclock gravity bug.

## Important Recovered Facts

- SMTV:V uses a custom movement stack, not UE `CharacterMovementComponent`.
- Player chain:
  - `ProjectPlayerController_C`
  - `Pla603_C`
  - `PlayerMovementComponent`
- `PlayerMovementComponent.velocityJump` is a reflected float that visibly
  affects jump height when read at jump initiation.
- Useful air-control fields from the old working mod:
  - `VelocityMaxFallen`
  - `InputInterpSpeed`
  - `ForwardMovementRatio`
- Better aerial feel came mainly from turn authority and latching until landing.
- The working input path used the game's `ProcessEvent` timing instead of
  faster polling.
- Do not directly arm positive/reverse `gravityJump` from raw B/JUMP input.
  Require an airborne state plus held jump, and always restore/normalize
  gravity to a negative baseline.

## Current Executable Reflection Strings

The installed executable contains a unique reflected movement table. Offline
string scan found one copy of the key property/function names:

- `VelocityMaxFallen`
- `ForwardMovementRatio`
- `InputInterpSpeed`
- `GravityJump`
- `VelocityJump`
- `CanJump`
- `Jump`
- `JumpTakeOff`
- `SetParamJump`

The first `VelocityJump` string is at file offset `0x32c5c28`; nearby strings
form the contiguous `PlayerMovementComponent` property/function table. This is
evidence that the UE reflection surface is available, and the next runtime task
is to locate the live `PlayerMovementComponent` instance through a UE hook
rather than scanning all writable memory for `1550.0f`.

Likely reflected property offsets decoded from nearby property descriptors:

- `VelocityMaxFallen`: `0x160`
- `ForwardMovementRatio`: `0x1a8`
- `InputInterpSpeed`: `0x1bc`
- `GravityJump`: `0x244`
- `VelocityJump`: `0x248`

## Verification against the shipping exe (2026-06-25)

Offline check via `verify_addresses.py` against
`Project/Binaries/Win64/SMT5V-Win64-Shipping.exe`:

- Image base `0x140000000`; the exe imports `xinput1_3.dll` (proxy mechanism OK).
- All reflection strings present at the documented offsets (`VelocityJump` at
  file `0x32c5c28`); the property offsets above are confirmed.
- The 8 hardcoded "slot" VAs hold valid code pointers in a clean 16-byte
  `(funcptr, nameptr)` table.

**Key correction.** That table is UE4's native-function *registration array*
(`FNameNativePtrPair Funcs[]`). UE reads it ONCE, at class registration during
startup, copying the pointers into each heap `UFunction`. Overwriting its
function pointers after the proxy initializes (~1s post-launch) changes data
nothing reads anymore. **The old slot-overwrite test build could never have
captured anything** — that was the stall, and there was never a log to show it.

The funcptrs in the array point at the real exec thunks. Dumped offline:

- "#2" set is **fully pre-decrypted** (clean prologues, inline-hookable):
  `CanJump#2` `0x140d104c0`, `IsJumping#2` `0x140cb4860`, `Jump#2` `0x140d10710`,
  `JumpTakeOff#2` `0x140d10740`.
- "#1" set is mostly Denuvo-virtualized (E9 jmp into the packed region); only
  `CanJump#1` is clean (and it has a RIP-relative insn in its prologue, so it
  needs displacement relocation if ever hooked). The #1/#2 split is almost
  certainly two pawn movement classes (e.g. Pla601 vs Pla603).

## Current Runtime Strategy (implemented)

The build now **inline-detours the four clean #2 exec thunks** (14-byte absolute
jmp + trampoline; entry bytes are re-checked at install time and the hook is
skipped on mismatch, so a game patch degrades to "no flight" not a crash). At
the thunk entry `rcx` = the live `PlayerMovementComponent`.

1. `xinput1_3.dll` proxy forwards XInput and latches B / SPACE as the jump input.
2. The detours capture the component (`LooksLikePlayerMovement` filter), read the
   `IsJumping` result as the authoritative airborne flag, and boost
   `velocityJump` in the `Jump`/`JumpTakeOff` detours so the take-off leap is
   high enough to start flight.
3. A worker thread (~125 Hz) applies flight only when the component was seen in
   the last 300 ms (guards against freed pointers): while airborne AND jump held
   it reverses `gravityJump` (`+|orig|`) to ascend; otherwise it normalizes
   `gravityJump` to a negative baseline (never left positive). Air-control fields
   are latched while airborne and restored on landing.
4. `F8` toggles the whole feature in-game for safe A/B testing.

**Open empirical questions for the first in-game log** (`read_log.bat`):
- Do the #2 detours fire, i.e. is the field player the #2 movement class? (If the
  log shows no `baseline captured`, the player is the #1 class — add a relocating
  hook on `CanJump#1`.)
- Is `IsJumping` polled per-frame (so it works as the airborne signal)?
- Real magnitudes/signs of `gravityJump`/`velocityJump` to tune the tunables in
  `flight_backend.cpp` (`kAscendMul`, `kTakeoffBoostMul`, ...).
