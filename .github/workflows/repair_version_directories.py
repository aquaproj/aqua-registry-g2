#!/usr/bin/env python3
"""Move the version directories written before a version was escaped.

A version directory is the version with every character outside [A-Za-z0-9.-] replaced
by an underscore and two hex digits, so WebAssembly/binaryen's version_133 is held at
versions/version_5f133. Directories written before that rule hold the tag as it is, and
nothing about the name says so: version_129 is a valid encoding of "version\\x129", so
re-escaping what it decodes to gives the same name back. aqua asking for version_133
looks for versions/version_5f133, finds nothing, and the package can't be installed from
the registry.

What tells them apart is upstream. A directory whose own name is a tag of the package's
repository is the tag written unescaped; one that isn't is an escaped name, whose tag is
what it decodes to. So the repair is: for a directory holding an underscore, ask the
repository whether a release or a tag is named exactly that, and if so move the file to
the escaped name.

The blobs are moved, not rewritten: the same object at the name it should have had, so
the checksums are the ones that were published.

This is for the files written before the rule. Nothing writes an unescaped directory any
more, so once it has run there is nothing for it to find and it can go.
"""

import base64
import json
import os
import re
import subprocess
import sys

REPO = os.environ.get("GITHUB_REPOSITORY", "aquaproj/aqua-registry-g2")
TOKEN = os.environ["GITHUB_TOKEN"]
BRANCH_TOKEN = os.environ.get("AR2_BRANCH_TOKEN", TOKEN)
DRY_RUN = os.environ.get("DRY_RUN", "false") == "true"
SAFE = re.compile(rb"[A-Za-z0-9.-]")


class NotFound(Exception):
    """The API answered 404, which is what says a resource isn't there."""


def request(path, token=TOKEN, method="GET", body=None):
    """One API call, through gh, which is what holds the retries and the rate limiting.

    The token is passed per call because two of them are used: the repository's own for
    reading, and the app that may push to a package branch for writing.
    """
    cmd = ["gh", "api", path]
    if method != "GET":
        cmd += ["-X", method]
    if body is not None:
        cmd += ["--input", "-"]
    out = subprocess.run(
        cmd, input=json.dumps(body) if body is not None else None,
        capture_output=True, text=True, env={**os.environ, "GH_TOKEN": token},
    )
    if out.returncode != 0:
        if "HTTP 404" in out.stderr or "Not Found" in out.stderr:
            raise NotFound(path)
        raise SystemExit(f"{' '.join(cmd)}\n{out.stderr}")
    return json.loads(out.stdout)


def exists(path):
    """Whether the resource is there, which is what a 404 says it isn't."""
    try:
        request(path)
        return True
    except NotFound:
        return False


def branches():
    out, page = [], 1
    while True:
        got = request(f"repos/{REPO}/branches?per_page=100&page={page}")
        out += [b for b in got if b["name"].startswith("pkg_")]
        if len(got) < 100:
            return out
        page += 1


def escape(name):
    """The name with every byte outside [A-Za-z0-9.-] written as an underscore and two
    hex digits, which is aqua's rule. Bytes rather than characters, so a version that
    isn't ASCII is escaped the same way aqua escapes it."""
    out = []
    for b in name.encode():
        out.append(chr(b) if SAFE.match(bytes([b])) else f"_{b:02x}")
    return "".join(out)


def repository_of(definition):
    """The repository a definition says the package is released from."""
    owner = re.search(r"^repo_owner:\s*(\S+)", definition, re.M)
    name = re.search(r"^repo_name:\s*(\S+)", definition, re.M)
    if not owner or not name:
        return None
    return owner.group(1), name.group(1)


def is_upstream_tag(repo, tag):
    """Whether the repository has a release or a tag named exactly this."""
    owner, name = repo
    quoted = tag.replace("/", "%2F")
    return exists(f"repos/{owner}/{name}/releases/tags/{quoted}") or exists(
        f"repos/{owner}/{name}/git/ref/tags/{quoted}"
    )


def repair(branch):
    """Move what this branch holds under an unescaped name. Returns how many moved."""
    head = branch["commit"]["sha"]
    tree = request(f"repos/{REPO}/git/trees/{head}?recursive=1")
    if tree.get("truncated"):
        print(f"{branch['name']}: the tree is truncated, skipping", file=sys.stderr)
        return 0
    definition_sha = ""
    files, dirs = {}, []
    for entry in tree["tree"]:
        path = entry["path"]
        if path == "registry.yaml":
            definition_sha = entry["sha"]
        if entry["type"] == "blob" and path.startswith("versions/"):
            files[path] = entry["sha"]
        if entry["type"] == "tree" and path.startswith("versions/") and path.count("/") == 1:
            dirs.append(path[len("versions/"):])

    # Only a directory holding something the rule escapes can be one written before it,
    # and the definition is read only for those: a branch with nothing to look at costs
    # the one request that listed it.
    suspect = [d for d in dirs if escape(d) != d]
    if not suspect or not definition_sha:
        return 0
    blob = request(f"repos/{REPO}/git/blobs/{definition_sha}")
    repo = repository_of(base64.b64decode(blob["content"]).decode())
    if repo is None:
        print(f"{branch['name']}: the definition names no repository, skipping", file=sys.stderr)
        return 0

    entries = []
    for d in suspect:
        if not is_upstream_tag(repo, d):
            continue
        for path, sha in files.items():
            if not path.startswith(f"versions/{d}/"):
                continue
            moved = f"versions/{escape(d)}/" + path[len(f"versions/{d}/"):]
            print(f"{branch['name']}: {path} -> {moved}")
            entries.append({"path": moved, "mode": "100644", "type": "blob", "sha": sha})
            # A null sha takes the old path out. The mode and the type go with it: the
            # API refuses an entry without a mode even when it only removes one.
            entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})
    if not entries or DRY_RUN:
        return len(entries) // 2

    commit = request(f"repos/{REPO}/git/commits/{head}")
    new_tree = request(
        f"repos/{REPO}/git/trees", token=BRANCH_TOKEN, method="POST",
        body={"base_tree": commit["tree"]["sha"], "tree": entries},
    )
    message = (
        "fix: escape the version directories written before the rule\n\n"
        "The same blobs, at the names they should have had, so the checksums are the\n"
        "ones that were published. aqua addresses a version by its escaped name, and\n"
        "nothing it asked for was at these."
    )
    new_commit = request(
        f"repos/{REPO}/git/commits", token=BRANCH_TOKEN, method="POST",
        body={"message": message, "tree": new_tree["sha"], "parents": [head]},
    )
    request(
        f"repos/{REPO}/git/refs/heads/{branch['name']}", token=BRANCH_TOKEN, method="PATCH",
        body={"sha": new_commit["sha"]},
    )
    return len(entries) // 2


def main():
    moved = 0
    for branch in branches():
        moved += repair(branch)
    print(f"{'would move' if DRY_RUN else 'moved'} {moved} files")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"{'Would move' if DRY_RUN else 'Moved'} {moved} files.\n")


if __name__ == "__main__":
    main()
