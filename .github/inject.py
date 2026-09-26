#!/usr/bin/env python3
"""Replace __LX_*__ placeholders in the checkout with values from repository secrets.
Every value is registered with ::add-mask:: first so it never appears in the build log."""
import os, pathlib, sys

KEYS = ["LX_ORIGIN", "LX_BUNDLE", "LX_TEAM", "LX_AUTH", "LX_ZHAO2", "LX_YAN", "LX_ZHAO", "LX_TITLE"]
values = {}
for k in KEYS:
    v = os.environ.get(k, "")
    if not v:
        sys.exit(f"missing secret {k}")
    print(f"::add-mask::{v}")
    values[f"__{k}__"] = v

root = pathlib.Path(".")
changed = 0
for p in root.rglob("*"):
    if not p.is_file() or ".git" in p.parts or "node_modules" in p.parts:
        continue
    try:
        s = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    t = s
    for ph, v in values.items():
        t = t.replace(ph, v)
    if t != s:
        p.write_text(t, encoding="utf-8")
        changed += 1
print(f"injected into {changed} files")
