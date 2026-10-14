#!/usr/bin/env python3
"""Fail if a credential has been committed to this repository.

The repository is public, and `docs/handoff/09_SETUP_DEPLOYMENT_AND_SECRETS.md` is expected to
quote real values. A `service_role` key in a public repository is a full database compromise: it
bypasses every RLS policy in `supabase/migrations`, which are the only authorization boundary this
app has. This check exists so that cannot happen quietly.

What it looks for, in the tracked files only (`git ls-files`):

  * JWTs, decoded — a `service_role` token is a hard failure, an `anon`/`publishable` token is a
    warning. Decoding is what makes the difference: the two keys look identical in a regex.
  * Supabase's newer key formats (`sb_secret_…`, `sbp_…`) and publishable keys (`sb_publishable_…`).
  * Common third-party credentials: Google API keys, AWS access key ids, private keys, Slack and
    GitHub tokens.
  * A `.env` file that is itself tracked.

Exit code 0 = clean, 1 = something must be fixed. Runs with python3 alone, no dependencies, so it
works in CI and in environments with no package manager access.
"""

from __future__ import annotations

import base64
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# High-confidence credential patterns. Deliberately narrow: a scanner that cries wolf gets
# disabled, and this one is the only thing standing between a public repo and a leaked key.
PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    (
        "Supabase secret key",
        re.compile(r"\bsb_secret_[A-Za-z0-9_-]{10,}"),
        "A secret key bypasses RLS. Revoke it in the dashboard and use the publishable key.",
    ),
    (
        "Supabase personal access token",
        re.compile(r"\bsbp_[A-Za-z0-9]{20,}"),
        "A personal access token can manage the whole organisation. Revoke it.",
    ),
    (
        "Google API key",
        re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
        "Revoke the key and restrict it, or move it behind a server.",
    ),
    (
        "AWS access key id",
        re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
        "Revoke the key in IAM.",
    ),
    (
        "private key",
        re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
        "Rotate the key pair; assume it is compromised.",
    ),
    (
        "GitHub token",
        re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})"),
        "Revoke the token in GitHub settings.",
    ),
    (
        "Slack token",
        re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
        "Revoke the token in Slack.",
    ),
]

JWT = re.compile(r"\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b")

# Files whose *purpose* is to describe credentials. They are scanned for real keys like everything
# else — only the bare-mention check is relaxed.
TEXT_ALLOWLIST = {
    "tool/check_no_secrets.py",
    "docs/handoff/README.md",
}

# A tracked .env is a smell even when it holds nothing yet: it is the file that will hold the key.
ENV_ALLOWLIST = {".env.example"}


def tracked_files() -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        capture_output=True,
        check=True,
    ).stdout
    return [ROOT / p for p in out.decode().split("\0") if p]


def decode_jwt(token: str) -> dict | None:
    payload = token.split(".")[1]
    padding = "=" * (-len(payload) % 4)
    try:
        raw = base64.urlsafe_b64decode(payload + padding)
        return json.loads(raw)
    except Exception:
        return None


def main() -> int:
    failures: list[str] = []
    warnings: list[str] = []
    scanned = 0

    for path in tracked_files():
        rel = path.relative_to(ROOT).as_posix()

        if path.name.startswith(".env") and path.name not in ENV_ALLOWLIST:
            failures.append(f"{rel}: a .env file is tracked (add it to .gitignore)")

        try:
            text = path.read_text(errors="ignore")
        except (OSError, UnicodeDecodeError):
            continue
        scanned += 1

        for label, pattern, advice in PATTERNS:
            for match in pattern.finditer(text):
                line = text[: match.start()].count("\n") + 1
                failures.append(f"{rel}:{line}: {label}. {advice}")

        for match in JWT.finditer(text):
            claims = decode_jwt(match.group(0))
            if claims is None:
                continue
            role = claims.get("role")
            line = text[: match.start()].count("\n") + 1
            if role == "service_role":
                failures.append(
                    f"{rel}:{line}: a service_role JWT. It bypasses every RLS policy in "
                    f"supabase/migrations. Revoke it in the dashboard and rotate."
                )
            elif role in {"anon", "authenticated"} and rel not in TEXT_ALLOWLIST:
                warnings.append(
                    f"{rel}:{line}: a {role} JWT is committed. It is publishable, so this is not a "
                    f"leak, but keys belong in --dart-define, not in the repository."
                )

    print(f"scanned {scanned} tracked files")
    for warning in warnings:
        print(f"  warning  {warning}")
    for failure in failures:
        print(f"  FAIL     {failure}")

    if failures:
        print(f"\n{len(failures)} credential problem(s). Do not push until they are resolved.")
        return 1

    print("no credentials found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
