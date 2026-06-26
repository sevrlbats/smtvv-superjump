"""Extract the PlayerMovementComponent reflected property table (name -> offset)
from the shipping exe, to find the real horizontal / air-control fields.

UHT-generated FFloatPropertyParams structs in .rdata begin with a pointer to the
property name and store the member byte-offset as an int32 at struct+0x24
(calibrated and verified against VelocityJump=0x248 / GravityJump=0x244).

Run: python extract_movement_fields.py
"""

import mmap
import struct
import sys

sys.path.insert(0, ".")
from verify_addresses import PE, EXE

STR_WIN_LO = 0x32c5000
STR_WIN_HI = 0x32c8000
# Initialized const data in this packed exe extends through the .bss raw region.
RDATA_LO, RDATA_HI = 0x600, 0x4033a00
OFFSET_DELTA = 0x24  # int32 Offset position within FFloatPropertyParams

KNOWN = {"VelocityJump": 0x248, "GravityJump": 0x244}
HORIZ_HINTS = ("speed", "move", "accel", "forward", "side", "horizon", "walk",
               "run", "dash", "ground", "air", "input", "interp", "ratio",
               "brake", "friction", "turn", "rot", "max", "velocity", "control")


def is_ident(b):
    return (48 <= b <= 57) or (65 <= b <= 90) or (97 <= b <= 122) or b == 0x5f


def main():
    with open(EXE, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        pe = PE(mm)

        def off_to_va(off):
            for name, vaddr, vsize, rawptr, rawsize, chars in pe.sections:
                if rawptr <= off < rawptr + rawsize:
                    return pe.image_base + vaddr + (off - rawptr), name
            return None, None

        # collect identifier strings in the movement cluster window
        uniq, seen = [], set()
        i = STR_WIN_LO
        while i < STR_WIN_HI:
            if is_ident(mm[i]) and (i == 0 or mm[i - 1] == 0):
                j = i
                while j < STR_WIN_HI and is_ident(mm[j]):
                    j += 1
                if mm[j] == 0:
                    s = mm[i:j].decode("latin1")
                    if 3 <= len(s) <= 48 and not s[0].isdigit() and s not in seen:
                        va, _ = off_to_va(i)
                        if va is not None:
                            seen.add(s)
                            uniq.append((s, va))
                i = j + 1
            else:
                i += 1

        def find_struct(name_va):
            pat = struct.pack("<Q", name_va)
            pos = mm.find(pat)
            while pos >= 0:
                if RDATA_LO <= pos < RDATA_HI:
                    return pos
                pos = mm.find(pat, pos + 1)
            return -1

        rows = []
        for s, va in uniq:
            p = find_struct(va)
            if p < 0:
                continue
            off = struct.unpack_from("<i", mm, p + OFFSET_DELTA)[0]
            if 0x40 <= off <= 0x600:
                rows.append((off, s))

        # sanity: known offsets must match
        bad = [(k, v) for k, v in KNOWN.items()
               if (v, k) not in [(o, n) for o, n in rows]]
        print("calibration check:", "OK" if not bad else f"FAILED {bad}")

        rows.sort()
        print(f"\n=== PlayerMovementComponent float fields (offset -> name) ===")
        for off, s in rows:
            hint = "   <-- candidate" if any(h in s.lower() for h in HORIZ_HINTS) else ""
            mark = "  [KNOWN]" if s in KNOWN else ""
            print(f"  0x{off:03x}  {s}{mark}{hint}")

        mm.close()


if __name__ == "__main__":
    main()
