#!/usr/bin/env python3
"""Stand-in check for test/privacy_test.dart.

No Flutter SDK is available in this environment, so `flutter test` cannot run.
This script replicates the test's assertions in Python to confirm the expected
strings actually occur in the migrations (i.e. the expectations are not typos),
and that the negative assertions really are absent.

It is NOT a substitute for running the real suite -- it only proves the
expectations are self-consistent with the SQL on disk.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(".")
MIGRATIONS = {
    "001_initial_schema.sql": "supabase/migrations/001_initial_schema.sql",
    "002_indexes_and_triggers.sql": "supabase/migrations/002_indexes_and_triggers.sql",
    "003_auth_helpers.sql": "supabase/migrations/003_auth_helpers.sql",
    "005_storage.sql": "supabase/migrations/005_storage.sql",
}


def normalize(sql: str) -> str:
    """Must match _normalize() in test/privacy_test.dart."""
    return re.sub(r"\s+", " ", sql).lower()


def strip_comments(src: str) -> str:
    return re.sub(r"//[^\n]*", "", src)


def dart_string_literals(expr: str):
    """Collect Dart string literals in source order.

    Scans quote-by-quote rather than regex-matching each quote kind, so a `"`
    that appears *inside* a '...' literal is treated as content, not as the
    start of a separate literal.
    """
    out = []
    i = 0
    n = len(expr)
    while i < n:
        ch = expr[i]
        if ch in ("'", '"'):
            j = i + 1
            buf = []
            while j < n:
                if expr[j] == "\\":
                    buf.append(expr[j + 1] if j + 1 < n else "")
                    j += 2
                    continue
                if expr[j] == ch:
                    break
                buf.append(expr[j])
                j += 1
            out.append((i, "".join(buf)))
            i = j + 1
        else:
            i += 1
    return out


def main() -> int:
    sql = {}
    for name, path in MIGRATIONS.items():
        p = pathlib.Path(path)
        if not p.exists():
            print(f"FAIL missing migration {path}")
            return 1
        sql[name] = normalize(p.read_text())

    test_path = pathlib.Path("test/privacy_test.dart")
    src = strip_comments(test_path.read_text())

    # Every contains(...) call, flagged as negative when wrapped in isNot(...).
    calls = []
    for m in re.finditer(r"contains\(", src):
        before = src[max(0, m.start() - 12):m.start()]
        # Grab the balanced argument.
        i = m.end()
        depth = 1
        while i < len(src) and depth:
            if src[i] == "(":
                depth += 1
            elif src[i] == ")":
                depth -= 1
            i += 1
        calls.append((before.endswith("isNot("), src[m.end():i - 1]))

    checked = 0
    failures = []
    for negative, expr in calls:
        literals = dart_string_literals(expr)
        if not literals:
            continue
        fragment = "".join(t for _, t in literals)
        if not fragment.strip():
            continue

        hits = [name for name, body in sql.items() if fragment in body]

        if negative:
            if hits:
                failures.append(f"NEGATIVE assertion violated: {fragment!r} found in {hits}")
            else:
                checked += 1
        else:
            if hits:
                checked += 1
                print(f"  ok  {fragment[:72]!r} -> {', '.join(hits)}")
            else:
                failures.append(f"EXPECTED fragment not found in ANY migration: {fragment!r}")

    print()
    print(f"assertions checked: {checked}, failures: {len(failures)}")
    for f in failures:
        print(f"  {f}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
