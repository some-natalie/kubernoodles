#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///

"""
This script bumps the pinned UBI minor version in the container files.

It finds every Dockerfile in images/ built on a pinned registry.access.redhat.com
base image, asks the registry whether a newer minor of the same major has been
published, and rewrites the FROM line if so.

Source: https://registry.access.redhat.com (manifest probe, see latest_ubi_minor)
"""

import json
import re
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

IMAGES_DIR = REPO_ROOT / "images"

# The README table is generated from this script's hardcoded base image strings,
# so a FROM bump has to move it too or the README silently goes stale.
README_SCRIPT = REPO_ROOT / ".github/scripts/update-readme.py"

REGISTRY = "https://registry.access.redhat.com"

# ubi8/ubi9 publish a Docker manifest list, ubi10 publishes an OCI index — ask for both.
MANIFEST_ACCEPT = (
    "application/vnd.oci.image.index.v1+json,"
    "application/vnd.docker.distribution.manifest.list.v2+json"
)

# Both are built by this repo, so a minor missing either one is not usable yet.
REQUIRED_ARCHES = {"amd64", "arm64"}

# Runaway guard, not a real ceiling — RHEL has never shipped this many minors at once.
MAX_MINOR_LOOKAHEAD = 20

FROM_RE = re.compile(
    r"^(FROM\s+registry\.access\.redhat\.com/(?P<repo>\S+?):)(?P<major>\d+)\.(?P<minor>\d+)",
    re.MULTILINE,
)


def _manifest_arches(repo: str, tag: str) -> set[str] | None:
    """
    Return the set of linux architectures published for repo:tag.

    Returns None if the tag does not exist, which is how the probe below detects
    that it has run past the newest published minor.
    """
    req = urllib.request.Request(
        f"{REGISTRY}/v2/{repo}/manifests/{tag}",
        headers={"Accept": MANIFEST_ACCEPT, "User-Agent": "kubernoodles-updater"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            index = json.loads(resp.read())
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return None
        raise

    return {
        m["platform"]["architecture"]
        for m in index.get("manifests", [])
        if m.get("platform", {}).get("os") == "linux"
    }


def latest_ubi_minor(repo: str, major: int, minor: int) -> int:
    """
    Probe forward from the pinned minor and return the newest published one.

    Asks the registry for an exact tag and advances only on a hit, rather than
    listing tags and taking the max. /v2/<repo>/tags/list is capped at 100 tags
    and is not ordered newest-first — ubi9's first page stops at 9.2 while the
    pin is already 9.8, so a list-and-max approach downgrades the image. Probing
    also cannot cross a major boundary, ignores the timestamped and -source
    tags entirely, and compares integers so 9.9 -> 9.10 works.
    """
    for _ in range(MAX_MINOR_LOOKAHEAD):
        candidate = f"{major}.{minor + 1}"
        arches = _manifest_arches(repo, candidate)
        if arches is None:
            break
        missing = REQUIRED_ARCHES - arches
        if missing:
            print(
                f"  {repo}:{candidate} exists but is missing {sorted(missing)} — holding"
            )
            break
        minor += 1

    return minor


def update_base_image(path: Path) -> tuple[str, str] | None:
    """
    Bump the pinned UBI minor version on a Dockerfile's FROM line.

    Returns (old_version, new_version) if the file changed, else None. Files that
    are not based on a pinned registry.access.redhat.com image are skipped.
    """
    content = path.read_text()
    match = FROM_RE.search(content)
    if match is None:
        return None

    major, minor = int(match.group("major")), int(match.group("minor"))
    newest = latest_ubi_minor(match.group("repo"), major, minor)
    if newest == minor:
        return None

    path.write_text(FROM_RE.sub(rf"\g<1>{major}.{newest}", content, count=1))
    return f"{major}.{minor}", f"{major}.{newest}"


def update_readme_base_image(shortname: str, new_version: str) -> bool:
    """Move the hardcoded base image version for one image in update-readme.py."""
    content = README_SCRIPT.read_text()
    # The README uses the dash form (ubi9-init), the Dockerfile the slash form
    # (ubi9/ubi-init), so this cannot share a pattern with FROM_RE.
    pattern = re.compile(rf"(\[{re.escape(shortname)}-init:)\d+\.\d+(\])")
    if pattern.search(content) is None:
        return False

    README_SCRIPT.write_text(pattern.sub(rf"\g<1>{new_version}\g<2>", content))
    return True


def main() -> None:
    print("Probing registry.access.redhat.com for newer UBI minors...")
    any_changes = False

    for path in sorted(IMAGES_DIR.glob("*.Dockerfile")):
        rel_path = path.relative_to(REPO_ROOT)
        change = update_base_image(path)
        if change is None:
            continue  # not a pinned UBI image, or already current

        any_changes = True
        old, new = change
        print(f"  {rel_path}: base image  {old} -> {new}")
        if update_readme_base_image(path.stem, new):
            print(f"  update-readme.py: {path.stem}-init  {old} -> {new}")

    print()
    if any_changes:
        print(
            "Base images updated. Open a pull request and assign review to @some-natalie."
        )
    else:
        print("All UBI base images are on the newest published minor.")


if __name__ == "__main__":
    main()
