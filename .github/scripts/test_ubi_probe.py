#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///

"""
Self-check for ubi-probe.py.

Run directly (`uv run .github/scripts/test_ubi_probe.py`) or under pytest. The
registry is stubbed, so this never touches the network.
"""

import importlib.util
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "ubi-probe.py"

# The hyphen in the filename makes it un-importable by name.
_spec = importlib.util.spec_from_file_location("ubi_probe", SCRIPT)
uc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uc)

BOTH_ARCHES = {"amd64", "arm64", "s390x"}


def _stub_registry(published: dict[str, set[str]]):
    """Replace the registry lookup with a fixed tag -> arches mapping."""
    uc._manifest_arches = lambda repo, tag: published.get(f"{repo}:{tag}")


def test_probe_stops_at_first_gap():
    _stub_registry(
        {
            "ubi9/ubi-init:9.9": BOTH_ARCHES,
            "ubi9/ubi-init:9.10": BOTH_ARCHES,
            # 9.11 absent
        }
    )
    assert uc.latest_ubi_minor("ubi9/ubi-init", 9, 8) == 10


def test_probe_is_integer_not_lexical():
    """A string comparison would rank 9.9 above 9.10 and stop early."""
    _stub_registry({f"ubi9/ubi-init:9.{n}": BOTH_ARCHES for n in range(9, 13)})
    assert uc.latest_ubi_minor("ubi9/ubi-init", 9, 8) == 12


def test_probe_never_downgrades_or_crosses_major():
    """Nothing newer published: the pin stays exactly where it was."""
    _stub_registry({"ubi9/ubi-init:10.0": BOTH_ARCHES})
    assert uc.latest_ubi_minor("ubi9/ubi-init", 9, 8) == 8


def test_probe_holds_when_arch_missing():
    _stub_registry({"ubi9/ubi-init:9.9": {"amd64", "s390x"}})
    assert uc.latest_ubi_minor("ubi9/ubi-init", 9, 8) == 8


def test_eol_major_stays_quiet():
    """8.10 is the final RHEL 8 minor, so this must report no change forever."""
    _stub_registry({})
    assert uc.latest_ubi_minor("ubi8/ubi-init", 8, 10) == 10


def test_dockerfile_from_line_rewritten():
    _stub_registry({"ubi9/ubi-init:9.9": BOTH_ARCHES})
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ubi9.Dockerfile"
        path.write_text(
            "FROM registry.access.redhat.com/ubi9/ubi-init:9.8 AS build\n"
            "ARG RUNNER_VERSION=2.337.0\n"
            "FROM scratch AS final\n"
        )

        assert uc.update_base_image(path) == ("9.8", "9.9")
        lines = path.read_text().splitlines()
        assert lines[0] == "FROM registry.access.redhat.com/ubi9/ubi-init:9.9 AS build"
        # Unrelated lines must survive untouched.
        assert lines[1] == "ARG RUNNER_VERSION=2.337.0"
        assert lines[2] == "FROM scratch AS final"


def test_ubi10_top_level_repo_path():
    """ubi10 is published at ubi10-init, not ubi10/ubi-init."""
    _stub_registry({"ubi10-init:10.3": BOTH_ARCHES})
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ubi10.Dockerfile"
        path.write_text("FROM registry.access.redhat.com/ubi10-init:10.2 AS build\n")

        assert uc.update_base_image(path) == ("10.2", "10.3")
        assert "ubi10-init:10.3" in path.read_text()


def test_non_ubi_dockerfile_untouched():
    _stub_registry({})
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "wolfi.Dockerfile"
        original = "FROM cgr.dev/chainguard/wolfi-base:latest AS build\n"
        path.write_text(original)

        assert uc.update_base_image(path) is None
        assert path.read_text() == original


def test_readme_script_literal_rewritten():
    with tempfile.TemporaryDirectory() as tmp:
        stub = Path(tmp) / "update-readme.py"
        stub.write_text(
            '        "baseimage": "[ubi9-init:9.8](https://catalog.redhat.com/x/abc123)",\n'
            '        "baseimage": "[ubi8-init:8.10](https://catalog.redhat.com/y/def456)",\n'
        )
        uc.README_SCRIPT = stub

        assert uc.update_readme_base_image("ubi9", "9.9") is True
        result = stub.read_text()
        # Version moves, opaque catalog id does not.
        assert "[ubi9-init:9.9](https://catalog.redhat.com/x/abc123)" in result
        # Sibling entries are left alone.
        assert "[ubi8-init:8.10](https://catalog.redhat.com/y/def456)" in result


def test_readme_script_reports_miss():
    with tempfile.TemporaryDirectory() as tmp:
        stub = Path(tmp) / "update-readme.py"
        stub.write_text('"baseimage": "[wolfi-base:latest](https://example.com)",\n')
        uc.README_SCRIPT = stub

        assert uc.update_readme_base_image("ubi9", "9.9") is False


if __name__ == "__main__":
    for name, case in sorted(globals().items()):
        if name.startswith("test_"):
            case()
            print(f"ok  {name}")
    print("\nall checks passed")
