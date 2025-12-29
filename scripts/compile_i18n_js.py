#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
# SPDX-License-Identifier: GPL-3.0-or-later

import ast
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PO_ROOT = ROOT / "po"
OUTPUT = ROOT / "contents" / "ui" / "i18n.js"


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


def main():
    catalogs = {}
    for po_path in PO_ROOT.glob("*/org.kde.plasma.klippermonitor.po"):
        lang = po_path.parent.name
        entries = parse_po(po_path)
        cat = {}
        for entry in entries:
            msgid = entry["msgid"]
            if msgid == "":
                continue
            msgstr = entry.get("msgstr", {}).get(0, "")
            if msgstr == "":
                continue
            cat[msgid] = msgstr
        catalogs[lang] = cat

    js = [
        "// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com",
        "// SPDX-License-Identifier: GPL-3.0-or-later",
        "// Auto-generated from po/*.po",
        ".pragma library",
        "",
        "var catalogs = "
        + json.dumps(catalogs, ensure_ascii=False, indent=2, sort_keys=True)
        + ";",
        "",
        "function formatString(message, args) {",
        "  if (!args || args.length === 0) {",
        "    return message;",
        "  }",
        "  var result = message;",
        "  for (var i = 0; i < args.length; i++) {",
        "    var token = \"%\" + (i + 1);",
        "    result = result.split(token).join(args[i]);",
        "  }",
        "  return result;",
        "}",
        "",
        "function tr(locale, msgid, args) {",
        "  var lang = locale || \"\";",
        "  var catalog = catalogs[lang] || {};",
        "  var message = catalog[msgid] || msgid;",
        "  return formatString(message, args);",
        "}",
    ]

    OUTPUT.write_text("\\n".join(js) + "\\n", encoding="utf-8")
    print(f\"Wrote {OUTPUT}\")


if __name__ == "__main__":
    main()
