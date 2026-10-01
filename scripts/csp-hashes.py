#!/usr/bin/env python3
"""Print the Content-Security-Policy hashes of a page's inline scripts and styles.

    scripts/csp-hashes.py PAGE
    scripts/csp-hashes.py --check HEADERS PAGE

With --check, exit 1 unless every hash appears in the Content-Security-Policy
line of the _headers file.
"""

import argparse
import base64
import hashlib
import re
import sys
from pathlib import Path

INLINE = re.compile(r"<(script|style)(\s[^>]*)?>(.*?)</\1>", re.S | re.I)
DIRECTIVE = {"script": "script-src", "style": "style-src"}


def page_hashes(page):
    found = []
    for tag, attrs, body in INLINE.findall(page.read_text(encoding="utf-8")):
        if attrs and re.search(r"\bsrc\s*=", attrs, re.I):
            continue
        digest = hashlib.sha256(body.encode("utf-8")).digest()
        found.append((DIRECTIVE[tag.lower()], f"'sha256-{base64.b64encode(digest).decode()}'"))
    return found


def header_policy(headers):
    for line in headers.read_text(encoding="utf-8").splitlines():
        name, _, value = line.strip().partition(":")
        if name.lower() == "content-security-policy":
            policy = {}
            for part in value.split(";"):
                tokens = part.split()
                if tokens:
                    policy[tokens[0].lower()] = tokens[1:]
            return policy
    sys.exit(f"{headers}: no Content-Security-Policy line")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", metavar="HEADERS", type=Path)
    parser.add_argument("page", type=Path)
    args = parser.parse_args()

    hashes = page_hashes(args.page)
    if not args.check:
        for directive, source in hashes:
            print(directive, source)
        return

    policy = header_policy(args.check)
    missing = [(d, s) for d, s in hashes if s not in policy.get(d, [])]
    for directive, source in missing:
        print(f"missing from {directive}: {source}", file=sys.stderr)
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
