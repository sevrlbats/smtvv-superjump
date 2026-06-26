"""Offline verification of the hardcoded reflection addresses used by
flight_backend.cpp against the current shipping executable.

Checks, with no game running:
  1. PE image base matches kPreferredImageBase (0x140000000).
  2. The game actually imports xinput1_3.dll (the proxy delivery mechanism).
  3. The PlayerMovementComponent reflection strings exist and where.
  4. What each hardcoded native-function slot VA actually contains on disk
     (is it a code pointer into .text, i.e. a real func-ptr slot, or not?).

Run with system python:  python verify_addresses.py
"""

import mmap
import struct
import sys

EXE = r"C:\Program Files (x86)\Steam\steamapps\common\SMT5V\Project\Binaries\Win64\SMT5V-Win64-Shipping.exe"

PREFERRED_BASE = 0x140000000

# Native function-pointer slot VAs hooked by flight_backend.cpp
SLOTS = [
    ("CanJump#1",      0x1432c59c0),
    ("IsJumping#1",    0x1432c5a80),
    ("Jump#1",         0x1432c5a90),
    ("JumpTakeOff#1",  0x1432c5aa0),
    ("CanJump#2",      0x1432c7a58),
    ("IsJumping#2",    0x1432c7b18),
    ("Jump#2",         0x1432c7b28),
    ("JumpTakeOff#2",  0x1432c7b38),
]

# Reflected property offsets the code reads off the captured component pointer.
PROP_OFFSETS = {
    "VelocityMaxFallen": 0x160,
    "ForwardMovementRatio": 0x1a8,
    "InputInterpSpeed": 0x1bc,
    "GravityJump": 0x244,
    "VelocityJump": 0x248,
}

STRINGS = [
    b"VelocityMaxFallen\x00",
    b"ForwardMovementRatio\x00",
    b"InputInterpSpeed\x00",
    b"GravityJump\x00",
    b"VelocityJump\x00",
    b"CanJump\x00",
    b"IsJumping\x00",
    b"Jump\x00",
    b"JumpTakeOff\x00",
    b"SetParamJump\x00",
    b"PlayerMovementComponent\x00",
]


class PE:
    def __init__(self, mm):
        self.mm = mm
        e_lfanew = struct.unpack_from("<I", mm, 0x3C)[0]
        assert mm[e_lfanew:e_lfanew + 4] == b"PE\x00\x00", "not a PE"
        coff = e_lfanew + 4
        self.num_sections = struct.unpack_from("<H", mm, coff + 2)[0]
        opt_size = struct.unpack_from("<H", mm, coff + 16)[0]
        opt = coff + 20
        magic = struct.unpack_from("<H", mm, opt)[0]
        assert magic == 0x20B, f"expected PE32+ (0x20B), got {magic:#x}"
        self.image_base = struct.unpack_from("<Q", mm, opt + 24)[0]
        # DataDirectory[1] = import table (RVA, size)
        # PE32+: data dirs start at opt + 112
        self.import_rva, self.import_size = struct.unpack_from("<II", mm, opt + 112 + 8)
        self.sections = []
        sec = opt + opt_size
        for i in range(self.num_sections):
            off = sec + i * 40
            name = mm[off:off + 8].rstrip(b"\x00").decode("latin1")
            vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", mm, off + 8)
            chars = struct.unpack_from("<I", mm, off + 36)[0]
            self.sections.append((name, vaddr, vsize, rawptr, rawsize, chars))

    def section_of_rva(self, rva):
        for s in self.sections:
            name, vaddr, vsize, rawptr, rawsize, chars = s
            span = max(vsize, rawsize)
            if vaddr <= rva < vaddr + span:
                return s
        return None

    def rva_to_off(self, rva):
        s = self.section_of_rva(rva)
        if not s:
            return None
        _, vaddr, _, rawptr, _, _ = s
        return rawptr + (rva - vaddr)

    def va_to_off(self, va):
        return self.rva_to_off(va - self.image_base)

    def is_code_va(self, va):
        rva = va - self.image_base
        s = self.section_of_rva(rva)
        if not s:
            return False
        # IMAGE_SCN_MEM_EXECUTE = 0x20000000
        return bool(s[5] & 0x20000000)


def main():
    with open(EXE, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        pe = PE(mm)

        print(f"=== PE ===")
        print(f"image_base = {pe.image_base:#x}  (code assumes {PREFERRED_BASE:#x})  "
              f"{'OK' if pe.image_base == PREFERRED_BASE else 'MISMATCH'}")
        print("sections:")
        for name, vaddr, vsize, rawptr, rawsize, chars in pe.sections:
            exec_flag = "X" if chars & 0x20000000 else " "
            write_flag = "W" if chars & 0x80000000 else " "
            print(f"  {name:8} VA={pe.image_base + vaddr:#013x} "
                  f"vsize={vsize:#010x} raw@={rawptr:#010x} [{exec_flag}{write_flag}]")

        print(f"\n=== imports (does the game import xinput1_3.dll?) ===")
        found_xinput = []
        off = pe.rva_to_off(pe.import_rva)
        if off is not None:
            i = 0
            while True:
                entry = off + i * 20
                name_rva = struct.unpack_from("<I", mm, entry + 12)[0]
                if name_rva == 0:
                    break
                noff = pe.rva_to_off(name_rva)
                end = mm.find(b"\x00", noff)
                dll = mm[noff:end].decode("latin1")
                if "xinput" in dll.lower():
                    found_xinput.append(dll)
                i += 1
        print("  xinput imports:", found_xinput or "NONE FOUND")

        print(f"\n=== reflection strings ===")
        first_velocityjump_off = None
        for s in STRINGS:
            label = s.rstrip(b"\x00").decode()
            pos = mm.find(s)
            if pos < 0:
                print(f"  {label:24} NOT FOUND")
                continue
            count = 0
            p = pos
            while p >= 0:
                count += 1
                p = mm.find(s, p + 1)
            # report file offset and the RVA if it lands in a section
            sec = None
            for nm, vaddr, vsize, rawptr, rawsize, chars in pe.sections:
                if rawptr <= pos < rawptr + rawsize:
                    sec = (nm, vaddr, rawptr)
                    break
            rva_txt = ""
            if sec:
                nm, vaddr, rawptr = sec
                rva = vaddr + (pos - rawptr)
                rva_txt = f" VA={pe.image_base + rva:#013x} ({nm})"
            print(f"  {label:24} file@={pos:#010x} count={count}{rva_txt}")
            if s == b"VelocityJump\x00":
                first_velocityjump_off = pos

        print(f"\n  (RESEARCH_NOTES claims first VelocityJump file@=0x32c5c28; "
              f"got {first_velocityjump_off:#x})" if first_velocityjump_off else "")

        print(f"\n=== native function-pointer slots ===")
        for name, va in SLOTS:
            o = pe.va_to_off(va)
            if o is None:
                print(f"  {name:14} VA={va:#013x}  -> not in any section")
                continue
            raw = mm[o:o + 8]
            val = struct.unpack("<Q", raw)[0]
            tag = "CODE-PTR" if pe.is_code_va(val) else (
                "image-ptr" if pe.image_base <= val < pe.image_base + 0x20000000 else "non-ptr")
            print(f"  {name:14} VA={va:#013x} file@={o:#010x} -> {val:#018x} [{tag}]")

        # Hex dump around the first slot to inspect the descriptor row layout
        base_va = SLOTS[0][1] - 0x40
        o = pe.va_to_off(base_va)
        if o is not None:
            print(f"\n=== hexdump around {SLOTS[0][0]} slot (VA {base_va:#x}) ===")
            for row in range(12):
                roff = o + row * 16
                rva_va = base_va + row * 16
                chunk = mm[roff:roff + 16]
                hexs = " ".join(f"{b:02x}" for b in chunk)
                asci = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
                print(f"  {rva_va:#013x}  {hexs}  {asci}")

        mm.close()


if __name__ == "__main__":
    main()
