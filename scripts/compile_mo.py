#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
# SPDX-License-Identifier: GPL-3.0-or-later

import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PO_ROOT = ROOT / "po"
LOCALE_ROOT = ROOT / "contents" / "locale"
DOMAIN = "plasma_applet_org.kde.plasma.klippermonitor"


def parse_po(path: Path):
    entries = []
    cur = None
    last_field = None
    last_idx = None

    def commit():
        nonlocal cur
        if not cur:
            return
        if cur.get("msgid") is None:
            cur = None
            return
        entries.append(cur)
        cur = None

    def new_entry():
        nonlocal cur
        if cur is not None:
            commit()
        cur = {"msgid": "", "msgid_plural": None, "msgstr": {}}

    def parse_quoted(s: str) -> str:
        s = s.strip()
        try:
            return ast.literal_eval(s)
        except Exception:
            return s.strip('"')

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            commit()
            last_field = None
            last_idx = None
            continue
        if line.startswith("#"):
            continue
        if line.startswith("msgid "):
            new_entry()
            cur["msgid"] = parse_quoted(line[5:].strip())
            last_field = "msgid"
            last_idx = None
            continue
        if line.startswith("msgid_plural "):
            if cur is None:
                new_entry()
            cur["msgid_plural"] = parse_quoted(line[len("msgid_plural ") :].strip())
            last_field = "msgid_plural"
            last_idx = None
            continue
        if line.startswith("msgstr["):
            if cur is None:
                new_entry()
            idx_end = line.find("]")
            idx = int(line[len("msgstr[") : idx_end])
            value = parse_quoted(line[idx_end + 1 :].strip())
            cur["msgstr"][idx] = value
            last_field = "msgstr"
            last_idx = idx
            continue
        if line.startswith("msgstr "):
            if cur is None:
                new_entry()
            value = parse_quoted(line[len("msgstr ") :].strip())
            cur["msgstr"][0] = value
            last_field = "msgstr"
            last_idx = 0
            continue
        if line.startswith('"'):
            if cur is None or last_field is None:
                continue
            value = parse_quoted(line)
            if last_field == "msgid":
                cur["msgid"] += value
            elif last_field == "msgid_plural":
                cur["msgid_plural"] = (cur["msgid_plural"] or "") + value
            elif last_field == "msgstr":
                cur["msgstr"][last_idx] = cur["msgstr"].get(last_idx, "") + value
            continue

    commit()
    return entries


def compile_mo(entries, out_path: Path):
    catalog = {}
    for entry in entries:
        msgid = entry["msgid"]
        msgid_plural = entry.get("msgid_plural")
        msgstrs = entry.get("msgstr") or {}
        if msgid_plural:
            msgid_key = msgid + "\0" + msgid_plural
            max_idx = max(msgstrs.keys()) if msgstrs else -1
            forms = [msgstrs.get(i, "") for i in range(max_idx + 1)]
            msgstr = "\0".join(forms)
        else:
            msgid_key = msgid
            msgstr = msgstrs.get(0, "")
        catalog[msgid_key] = msgstr

    catalog.setdefault("", "")

    ids = sorted(catalog.keys())
    strs = [catalog[i] for i in ids]

    ids_bytes = [s.encode("utf-8") for s in ids]
    strs_bytes = [s.encode("utf-8") for s in strs]

    n = len(ids_bytes)
    orig_tab_offset = 7 * 4
    trans_tab_offset = orig_tab_offset + n * 8
    hash_size = 0
    hash_offset = trans_tab_offset + n * 8

    orig_data = b""
    orig_offsets = []
    offset = hash_offset
    for b in ids_bytes:
        orig_offsets.append(offset)
        orig_data += b + b"\0"
        offset += len(b) + 1

    trans_data = b""
    trans_offsets = []
    offset = hash_offset + len(orig_data)
    for b in strs_bytes:
        trans_offsets.append(offset)
        trans_data += b + b"\0"
        offset += len(b) + 1

    import struct

    output = bytearray()
    output += struct.pack("<I", 0x950412DE)
    output += struct.pack("<I", 0)
    output += struct.pack("<I", n)
    output += struct.pack("<I", orig_tab_offset)
    output += struct.pack("<I", trans_tab_offset)
    output += struct.pack("<I", hash_size)
    output += struct.pack("<I", hash_offset)

    for i, b in enumerate(ids_bytes):
        output += struct.pack("<II", len(b), orig_offsets[i])
    for i, b in enumerate(strs_bytes):
        output += struct.pack("<II", len(b), trans_offsets[i])

    output += orig_data
    output += trans_data

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(output)


def main():
    for po_path in PO_ROOT.glob("*/org.kde.plasma.klippermonitor.po"):
        lang = po_path.parent.name
        entries = parse_po(po_path)
        mo_path = LOCALE_ROOT / lang / "LC_MESSAGES" / f"{DOMAIN}.mo"
        compile_mo(entries, mo_path)
        print(f"Wrote {mo_path}")


if __name__ == "__main__":
    main()
