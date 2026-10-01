"""Delete the branches named after a package.

Every package is held on a branch named after its id now. The branch named after the package
is what it was carried over from, and nothing reads it -- but what a package branch holds was
downloaded, hashed and opened on six machines to get there, so each one is checked before it
goes rather than deleted because of what its name looks like.

A branch goes when either is true:

- the package it names is in names.json, which is what says the package is held somewhere;
  'ar2 identify' is what put it there, carrying this branch's history over as the new
  branch's parent.
- it holds no definition and no version, which is a branch a run created and whose first
  pull request never merged. There is nothing on it to lose.

Anything else is reported and left alone.
"""

import json
import os
import subprocess
import sys

REPO = os.environ["GITHUB_REPOSITORY"]
DRY_RUN = os.environ.get("DRY_RUN", "true") == "true"
BRANCH_PREFIX = "pkg_"


def gh(*args: str) -> str:
    out = subprocess.run(["gh", *args], capture_output=True, text=True, check=False)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip())
    return out.stdout


def decode(encoded: str) -> str:
    """Read the package name out of a branch name.

    Every character outside [A-Za-z0-9.-] was written as an underscore and two hex digits.
    """
    out, i = [], 0
    while i < len(encoded):
        c = encoded[i]
        if c != "_":
            out.append(c)
            i += 1
            continue
        out.append(chr(int(encoded[i + 1:i + 3], 16)))
        i += 3
    return "".join(out)


def holds_anything(branch: str) -> bool:
    """Whether the branch holds a definition or a version, rather than the template alone."""
    tree = json.loads(gh("api", f"repos/{REPO}/git/trees/{branch}?recursive=1"))
    for entry in tree["tree"]:
        path = entry["path"]
        if path == "registry.yaml" or path.startswith("versions/"):
            return True
    return False


def main() -> int:
    # The table says which packages are held and where. A branch whose package is in it has
    # been carried over.
    with open("names.json", encoding="utf-8") as f:
        held = set(json.load(f)["ids"])

    refs = gh("api", "--paginate", f"repos/{REPO}/git/matching-refs/heads/{BRANCH_PREFIX}",
              "--jq", ".[].ref").split()
    deleted = kept = 0
    for ref in refs:
        branch = ref.removeprefix("refs/heads/")
        suffix = branch.removeprefix(BRANCH_PREFIX)
        if suffix.isdigit():
            # Named after an id: this is where the packages are.
            continue
        pkg = decode(suffix)
        if pkg in held:
            why = "carried over"
        elif not holds_anything(branch):
            why = "holds nothing but the template"
        else:
            print(f"keep   {branch}\t{pkg}\tnot carried over, and it holds something")
            kept += 1
            continue
        print(f"delete {branch}\t{pkg}\t{why}")
        deleted += 1
        if DRY_RUN:
            continue
        gh("api", "--method", "DELETE", f"repos/{REPO}/git/refs/heads/{branch}")

    verb = "to delete" if DRY_RUN else "deleted"
    print(f"\n{deleted} {verb}, {kept} left alone")
    # A branch left alone is something to look at: it was never carried over and it holds
    # what somebody generated.
    return 1 if kept else 0


if __name__ == "__main__":
    sys.exit(main())
