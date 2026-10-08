#!/usr/bin/env python3
"""Put the versions caller on the package branches that haven't got it.

A push workflow is read from the branch that was pushed, so the one asking for a branch's
list of versions to be written has to be on that branch. New branches get it from the
template; the branches that existed before it did get it from here.

One commit per branch, and only where the file isn't already what the template says. Once
every branch has it there is nothing for this to do, and it can go.
"""

import base64
import json
import os
import subprocess
import sys

REPO = os.environ.get("GITHUB_REPOSITORY", "aquaproj/aqua-registry-g2")
TOKEN = os.environ["GITHUB_TOKEN"]
BRANCH_TOKEN = os.environ.get("AR2_BRANCH_TOKEN", TOKEN)
DRY_RUN = os.environ.get("DRY_RUN", "false") == "true"
PATH = ".github/workflows/versions.yaml"
TEMPLATE = "template/" + PATH


class NotFound(Exception):
    """The API answered 404, which is what says a resource isn't there."""


def request(path, token=TOKEN, method="GET", body=None):
    """One API call, through gh, which is what holds the retries and the rate limiting."""
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


def file_on(ref, path):
    """What a ref holds at that path, and None when it holds nothing."""
    try:
        got = request(f"repos/{REPO}/contents/{path}?ref={ref}")
    except NotFound:
        return None
    return base64.b64decode(got["content"]).decode()


def branches():
    out, page = [], 1
    while True:
        got = request(f"repos/{REPO}/branches?per_page=100&page={page}")
        # The prefix, not a search: a branch whose name merely holds "pkg_" is the head
        # branch of a pull request.
        out += [b for b in got if b["name"].startswith("pkg_")]
        if len(got) < 100:
            return out
        page += 1


def put(branch, head, content):
    """Write the caller onto the branch, on a commit of its own."""
    commit = request(f"repos/{REPO}/git/commits/{head}")
    tree = request(
        f"repos/{REPO}/git/trees", token=BRANCH_TOKEN, method="POST",
        body={"base_tree": commit["tree"]["sha"], "tree": [
            {"path": PATH, "mode": "100644", "type": "blob", "content": content},
        ]},
    )
    message = (
        "ci: ask for the list of versions when this branch changes\n\n"
        "A push workflow is read from the branch that was pushed, so this has to be\n"
        "here. It holds nothing but the call: what it calls is on main, where it can be\n"
        "improved for every package at once."
    )
    new = request(
        f"repos/{REPO}/git/commits", token=BRANCH_TOKEN, method="POST",
        body={"message": message, "tree": tree["sha"], "parents": [head]},
    )
    request(
        f"repos/{REPO}/git/refs/heads/{branch}", token=BRANCH_TOKEN, method="PATCH",
        body={"sha": new["sha"]},
    )


def main():
    content = file_on("main", TEMPLATE)
    if content is None:
        raise SystemExit(f"main holds no {TEMPLATE}")
    written = 0
    for branch in branches():
        name = branch["name"]
        if file_on(name, PATH) == content:
            continue
        print(f"{name}: {PATH}")
        written += 1
        if DRY_RUN:
            continue
        put(name, branch["commit"]["sha"], content)
    print(f"{'would write' if DRY_RUN else 'wrote'} {written} branches")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"{'Would write' if DRY_RUN else 'Wrote'} {written} branches.\n")


if __name__ == "__main__":
    main()
