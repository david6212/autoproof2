"""Every Hebrew string the app can show, with where it lives.

The app's text is not in one place — there is `AppStrings`, but most screens
still hold their own literals, so "read all the copy" means walking `lib/`.
This dumps them once so a proofreading pass reads text instead of code, and so
two passes months apart read the same list the same way.

    python tool/dump_he_strings.py            # summary + docs/wording/he-strings.json
    python tool/dump_he_strings.py --print    # also print them, grouped by file

Deliberately dumb about context: it reports every literal containing a Hebrew
letter, including the ones that are regexes or keys rather than copy. Deciding
which is which is the reader's job — the opposite mistake, a filter that hides
a real sentence, is the one that matters.
"""

import io
import json
import os
import re
import sys

HEBREW = "֐-׿"

# Dart string literals: single or double quoted, escapes respected, one line.
# Raw and triple-quoted strings are rare here and are caught by the same
# pattern's first line, which is enough to notice them.
LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")


def collect(root):
    rows = []
    for base, _dirs, files in os.walk(os.path.join(root, "lib")):
        for name in sorted(files):
            if not name.endswith(".dart"):
                continue
            path = os.path.join(base, name).replace("\\", "/")
            src = io.open(path, encoding="utf-8").read()
            for m in LITERAL.finditer(src):
                text = m.group(1) if m.group(1) is not None else (m.group(2) or "")
                if re.search("[" + HEBREW + "]", text):
                    rows.append(
                        {
                            "file": os.path.relpath(path, root).replace("\\", "/"),
                            "line": src[: m.start()].count("\n") + 1,
                            "text": text,
                        }
                    )
    return rows


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rows = collect(root)

    out_dir = os.path.join(root, "docs", "wording")
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out = os.path.join(out_dir, "he-strings.json")
    io.open(out, "w", encoding="utf-8", newline="\n").write(
        json.dumps(rows, ensure_ascii=False, indent=1)
    )

    print("%d Hebrew literals, %d distinct, in %d files"
          % (len(rows), len({r["text"] for r in rows}),
             len({r["file"] for r in rows})))
    print("written to docs/wording/he-strings.json")

    if "--print" in sys.argv:
        current = None
        for r in rows:
            if r["file"] != current:
                current = r["file"]
                print("\n=== " + current)
            print("%5d  %s" % (r["line"], r["text"]))


if __name__ == "__main__":
    main()
