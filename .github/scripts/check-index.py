"""Check that index.json says what aqua reads it for.

The catalogue is what 'aqua g' searches: one file holding the name and description of
every package the registry has. It is written by ar2 and merged without a reader, so
this is where a file that would break searching is caught.
"""

import json
import sys


def main(path: str) -> int:
    with open(path, encoding="utf-8") as f:
        try:
            index = json.load(f)
        except json.JSONDecodeError as e:
            print(f"{path} isn't JSON: {e}", file=sys.stderr)
            return 1

    packages = index.get("packages") if isinstance(index, dict) else None
    if not isinstance(packages, list):
        print(f"{path} has no packages list", file=sys.stderr)
        return 1

    seen = set()
    failed = False
    for i, pkg in enumerate(packages):
        if not isinstance(pkg, dict):
            print(f"packages[{i}] isn't an object", file=sys.stderr)
            failed = True
            continue
        name = pkg.get("name")
        if not isinstance(name, str) or not name:
            print(f"packages[{i}] has no name", file=sys.stderr)
            failed = True
            continue
        # A package listed twice is shown twice, and the second entry is the one a
        # search would never explain.
        if name in seen:
            print(f"{name} is listed more than once", file=sys.stderr)
            failed = True
        seen.add(name)

    if failed:
        return 1
    print(f"{path}: {len(packages)} packages")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
