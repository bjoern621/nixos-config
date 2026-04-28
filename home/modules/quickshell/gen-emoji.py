#!/usr/bin/env python3
"""Generate the emoji dataset consumed by EmojiPicker.qml.

Driven by the Nix derivation in quickshell.nix:

  python3 gen-emoji.py <emoji-test.txt> <en.xml> [<de.xml> ...] > emoji.json

Inputs:
  emoji-test.txt  : pkgs.unicode-emoji
  *.xml           : pkgs.cldr-annotations (one per locale to mix into keywords)

Output JSON shape:
  {
    "groups": [{"name": "Smileys & Emotion", "icon": "😀"}, ...],
    "emojis": [{"c": "😀", "n": "grinning face", "k": "face|grin|...",
                "g": 0}, ...]
  }

Skips the "Component" group (skin tones, hair) and non-fully-qualified
sequences. Emoji order matches CLDR / Windows picker order.
"""
from __future__ import annotations

import json
import re
import sys
from xml.etree import ElementTree as ET

EMOJI_LINE = re.compile(
    r"^[0-9A-F ]+;\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.*)$"
)
SKIP_GROUPS = {"Component"}


def load_annotations(*xml_paths: str) -> dict[str, list[str]]:
    """cp -> de-duplicated list of keyword tokens, lower-cased."""
    out: dict[str, list[str]] = {}
    for path in xml_paths:
        tree = ET.parse(path)
        for ann in tree.findall(".//annotation"):
            cp = ann.get("cp")
            if cp is None or ann.get("type") == "tts":
                continue
            text = (ann.text or "").strip()
            if not text:
                continue
            tokens = [t.strip().lower() for t in text.split("|")]
            tokens = [t for t in tokens if t]
            bucket = out.setdefault(cp, [])
            for t in tokens:
                if t not in bucket:
                    bucket.append(t)
    return out


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "usage: gen-emoji.py <emoji-test.txt> <annotations.xml> "
            "[<annotations.xml> ...]\n"
        )
        sys.exit(2)

    emoji_test_path = sys.argv[1]
    keywords = load_annotations(*sys.argv[2:])

    groups: list[dict] = []
    emojis: list[dict] = []
    current_group: str | None = None
    current_index = -1

    with open(emoji_test_path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("# group:"):
                current_group = line.split(":", 1)[1].strip()
                if current_group in SKIP_GROUPS:
                    current_index = -1
                else:
                    current_index = len(groups)
                    groups.append({"name": current_group, "icon": ""})
                continue
            if not line or line.startswith("#"):
                continue
            if current_index < 0:
                continue
            m = EMOJI_LINE.match(line)
            if not m:
                continue
            char, name = m.group(1), m.group(2)
            # CLDR annotations strip U+FE0F variation selectors.
            stripped = char.replace("️", "")
            tokens = keywords.get(stripped) or keywords.get(char) or []
            kw = "|".join(tokens)
            if not groups[current_index]["icon"]:
                groups[current_index]["icon"] = char
            emojis.append(
                {"c": char, "n": name, "k": kw, "g": current_index}
            )

    json.dump(
        {"groups": groups, "emojis": emojis},
        sys.stdout,
        ensure_ascii=False,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
