#!/usr/bin/env python3
"""Generate the emoji dataset consumed by EmojiPicker.qml.

Driven by the Nix derivation in quickshell.nix:

  python3 gen-emoji.py <emoji-test.txt> <UnicodeData.txt> <Blocks.txt> \
    <en.xml> [<de.xml> ...] > emoji.json

Inputs:
  emoji-test.txt  : pkgs.unicode-emoji
  UnicodeData.txt : pkgs.unicode-character-database
  Blocks.txt      : pkgs.unicode-character-database
  *.xml           : pkgs.cldr-annotations (one per locale to mix into keywords)

Output JSON shape:
  {
    "groups": [{"name": "Smileys & Emotion", "icon": "😀"}, ...],
    "emojis": [{"c": "😀", "n": "grinning face", "k": "face|grin|...",
                "g": 0}, ...]
  }

Skips the "Component" group (skin tones, hair) and non-fully-qualified
sequences. Emoji order matches CLDR / Windows picker order.

The last group, "Unicode", holds the characters of SYMBOL_BLOCKS in code point
order. Its entries carry the code point as their first keyword ("U+2192").
Characters that also exist as emoji stay in it: the emoji entry appends U+FE0F,
the Unicode entry pastes the bare code point.
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

UNICODE_GROUP = {"name": "Unicode", "icon": "Ω"}
# Blocks.txt names. Blocks of scripts and specialist notations stay out.
SYMBOL_BLOCKS = {
    "Latin-1 Supplement",
    "Greek and Coptic",
    "General Punctuation",
    "Superscripts and Subscripts",
    "Currency Symbols",
    "Letterlike Symbols",
    "Number Forms",
    "Arrows",
    "Mathematical Operators",
    "Miscellaneous Technical",
    "Enclosed Alphanumerics",
    "Box Drawing",
    "Block Elements",
    "Geometric Shapes",
    "Miscellaneous Symbols",
    "Dingbats",
    "Miscellaneous Mathematical Symbols-A",
    "Supplemental Arrows-A",
    "Braille Patterns",
    "Supplemental Arrows-B",
    "Miscellaneous Mathematical Symbols-B",
    "Supplemental Mathematical Operators",
    "Miscellaneous Symbols and Arrows",
    "Supplemental Punctuation",
    "Playing Cards",
    "Geometric Shapes Extended",
    "Supplemental Arrows-C",
    "Chess Symbols",
    "Symbols for Legacy Computing",
}
# General categories without a visible glyph of their own:
# controls, format characters, separators and combining marks.
SKIP_CATEGORIES = {"Cc", "Cf", "Zs", "Zl", "Zp", "Mn", "Mc", "Me"}

# Sanity floors.
# Upstream reformat breaking EMOJI_LINE, or a CLDR path change emptying
# load_annotations, both yield valid JSON and a successful derivation.
# Floors sit far below real dataset size.
# They catch a broken parse, not upstream churn.
MIN_GROUPS = 8
MIN_EMOJIS = 1000
MIN_SYMBOLS = 1000
# CLDR annotates no skin-tone variant, so share sits well under half
# even when parsing is intact.
MIN_KEYWORD_SHARE = 0.25


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


def load_symbol_ranges(blocks_path: str) -> list[range]:
    """Code point ranges of SYMBOL_BLOCKS."""
    ranges: list[range] = []
    with open(blocks_path, encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            span, name = line.rstrip("\n").split("; ", 1)
            if name in SYMBOL_BLOCKS:
                first, last = span.split("..")
                ranges.append(range(int(first, 16), int(last, 16) + 1))
    return ranges


def load_symbols(
    unicode_data_path: str,
    blocks_path: str,
    keywords: dict[str, list[str]],
    group_index: int,
) -> list[dict]:
    """Dataset entries of SYMBOL_BLOCKS, in UnicodeData.txt order."""
    ranges = load_symbol_ranges(blocks_path)
    symbols: list[dict] = []
    with open(unicode_data_path, encoding="utf-8") as f:
        for line in f:
            cp_hex, name, category = line.split(";")[:3]
            cp = int(cp_hex, 16)
            if category in SKIP_CATEGORIES or not any(cp in r for r in ranges):
                continue
            char = chr(cp)
            tokens = [f"U+{cp_hex}", *keywords.get(char, [])]
            symbols.append(
                {"c": char, "n": name.lower(), "k": "|".join(tokens), "g": group_index}
            )
    return symbols


def validate(groups: list[dict], emojis: list[dict], symbols: list[dict]) -> None:
    """Exit non-zero on a silently empty or keyword-less dataset."""
    errors: list[str] = []

    if len(groups) < MIN_GROUPS:
        errors.append(
            f"{len(groups)} groups, expected >= {MIN_GROUPS}; group headers unparsed?"
        )
    if len(emojis) < MIN_EMOJIS:
        errors.append(
            f"{len(emojis)} emojis, expected >= {MIN_EMOJIS}; EMOJI_LINE regex stale?"
        )
    if len(symbols) < MIN_SYMBOLS:
        errors.append(
            f"{len(symbols)} symbols, expected >= {MIN_SYMBOLS}; "
            "SYMBOL_BLOCKS names or UnicodeData.txt format changed?"
        )

    iconless = [g["name"] for g in groups if not g["icon"]]
    if iconless:
        errors.append(f"groups matched no emoji: {', '.join(iconless)}")

    if emojis:
        share = sum(1 for e in emojis if e["k"]) / len(emojis)
        if share < MIN_KEYWORD_SHARE:
            errors.append(
                f"{share:.1%} of emojis carry keywords, "
                f"expected >= {MIN_KEYWORD_SHARE:.0%}; "
                "CLDR annotations path or schema changed?"
            )

    for err in errors:
        sys.stderr.write(f"gen-emoji: {err}\n")
    if errors:
        sys.exit(1)


def main() -> None:
    if len(sys.argv) < 5:
        sys.stderr.write(
            "usage: gen-emoji.py <emoji-test.txt> <UnicodeData.txt> <Blocks.txt> "
            "<annotations.xml> [<annotations.xml> ...]\n"
        )
        sys.exit(2)

    emoji_test_path, unicode_data_path, blocks_path = sys.argv[1:4]
    keywords = load_annotations(*sys.argv[4:])

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
            # Escape, not literal: U+FE0F renders invisible,
            # and an editor strips it unnoticed.
            stripped = char.replace("\ufe0f", "")
            tokens = keywords.get(stripped) or keywords.get(char) or []
            kw = "|".join(tokens)
            if not groups[current_index]["icon"]:
                groups[current_index]["icon"] = char
            emojis.append(
                {"c": char, "n": name, "k": kw, "g": current_index}
            )

    symbols = load_symbols(unicode_data_path, blocks_path, keywords, len(groups))
    groups.append(UNICODE_GROUP)

    validate(groups, emojis, symbols)

    json.dump(
        {"groups": groups, "emojis": emojis + symbols},
        sys.stdout,
        ensure_ascii=False,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
