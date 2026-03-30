#!/usr/bin/env python3

"""
This script updates the dependencies inside the container files.

Sources:
  RUNNER_VERSION                 - https://github.com/actions/runner (GitHub releases)
  RUNNER_CONTAINER_HOOKS_VERSION - https://github.com/actions/runner-container-hooks (GitHub releases)
  DUMB_INIT_VERSION              - https://github.com/Yelp/dumb-init (GitHub releases)
  COMPOSE_VERSION                - https://github.com/docker/compose (GitHub releases, keeps v-prefix)
  DOCKER_VERSION                 - https://download.docker.com/linux/static/stable/x86_64/ (directory listing)
"""

import json
import re
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

DOCKERFILES = [
    "images/rootless-ubuntu-jammy.Dockerfile",
    "images/rootless-ubuntu-numbat.Dockerfile",
    "images/ubi10.Dockerfile",
    "images/ubi9.Dockerfile",
    "images/ubi8.Dockerfile",
    "images/wolfi.Dockerfile",
]


def _fetch(url: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "kubernoodles-updater",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return resp.read()


def _github_latest(repo: str) -> str:
    """Return the latest release tag_name for a GitHub repo (e.g. 'v2.333.0')."""
    data = json.loads(_fetch(f"https://api.github.com/repos/{repo}/releases/latest"))
    return data["tag_name"]


def _docker_latest() -> str:
    """Return the latest Docker CE version string (no v-prefix) from the static download index."""
    content = _fetch("https://download.docker.com/linux/static/stable/x86_64/").decode()
    versions = re.findall(r"docker-(\d+\.\d+\.\d+)\.tgz", content)
    if not versions:
        raise RuntimeError("No Docker versions found at download.docker.com")
    return max(versions, key=lambda v: tuple(int(x) for x in v.split(".")))


def get_latest_versions() -> dict[str, str]:
    """Fetch and return the latest version string for each tracked ARG."""
    return {
        # strip leading 'v' — Dockerfiles store bare semver for these three
        "RUNNER_VERSION": _github_latest("actions/runner").lstrip("v"),
        "RUNNER_CONTAINER_HOOKS_VERSION": _github_latest(
            "actions/runner-container-hooks"
        ).lstrip("v"),
        "DUMB_INIT_VERSION": _github_latest("Yelp/dumb-init").lstrip("v"),
        # COMPOSE_VERSION keeps the 'v' prefix (matches existing Dockerfile convention)
        "COMPOSE_VERSION": _github_latest("docker/compose"),
        "DOCKER_VERSION": _docker_latest(),
    }


def update_dockerfile(path: Path, latest: dict[str, str]) -> list[tuple[str, str, str]]:
    """
    Rewrite ARG version lines in a single Dockerfile.

    Only updates ARGs that are already present in the file; never adds new ones.
    Returns a list of (arg_name, old_version, new_version) for each change made.
    """
    content = path.read_text()
    changes: list[tuple[str, str, str]] = []

    for arg, new_version in latest.items():
        pattern = re.compile(rf"^(ARG {arg}=)(\S+)", re.MULTILINE)
        match = pattern.search(content)
        if match is None:
            continue  # ARG not present in this file — skip
        old_version = match.group(2)
        if old_version == new_version:
            continue  # already up to date
        content = pattern.sub(rf"\g<1>{new_version}", content)
        changes.append((arg, old_version, new_version))

    if changes:
        path.write_text(content)

    return changes


def main() -> None:
    print("Fetching latest versions...")
    latest = get_latest_versions()
    for arg, version in latest.items():
        print(f"  {arg}: {version}")

    print()
    any_changes = False

    for rel_path in DOCKERFILES:
        path = REPO_ROOT / rel_path
        if not path.exists():
            print(f"  SKIP {rel_path} (file not found)")
            continue

        changes = update_dockerfile(path, latest)
        if changes:
            any_changes = True
            for arg, old, new in changes:
                print(f"  {rel_path}: {arg}  {old} -> {new}")
        else:
            print(f"  {rel_path}: up to date")

    print()
    if any_changes:
        print(
            "Dockerfiles updated. Open a pull request and assign review to @some-natalie."
        )
    else:
        print("All dependencies are up to date. Close this issue.")


if __name__ == "__main__":
    main()
