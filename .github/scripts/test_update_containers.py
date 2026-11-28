#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///

"""Self-check for update-containers.py request authentication."""

import importlib.util
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parent / "update-containers.py"

_spec = importlib.util.spec_from_file_location("update_containers", SCRIPT)
uc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uc)


class _Response:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self):
        return b"{}"


def _capture_request(url: str, environ: dict[str, str]) -> uc.urllib.request.Request:
    captured = []

    def fake_urlopen(request):
        captured.append(request)
        return _Response()

    with patch.dict(uc.os.environ, environ, clear=True):
        with patch.object(uc.urllib.request, "urlopen", fake_urlopen):
            uc._fetch(url)

    return captured[0]


def test_github_api_uses_token():
    request = _capture_request(
        "https://api.github.com/repos/actions/runner/releases/latest",
        {"GITHUB_TOKEN": "test-token"},
    )
    assert request.get_header("Authorization") == "Bearer test-token"


def test_token_is_not_sent_to_other_hosts():
    request = _capture_request(
        "https://download.docker.com/linux/static/stable/x86_64/",
        {"GITHUB_TOKEN": "test-token"},
    )
    assert request.get_header("Authorization") is None


if __name__ == "__main__":
    for name, case in sorted(globals().items()):
        if name.startswith("test_"):
            case()
            print(f"ok  {name}")
    print("\nall checks passed")
