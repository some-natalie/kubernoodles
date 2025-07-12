#!/usr/bin/env python3

"""
This script updates the date and CVE scan results in the README.md file.
"""

# Imports
from collections import Counter
import datetime
import json
import os

# Constants
image_list = [
    {
        "shortname": "ubi8",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/ubi8:latest",
        "baseimage": "[ubi8-init:8.10](https://catalog.redhat.com/software/containers/ubi8-init/5c6aea74dd19c77a158f0892)",
        "architectures": "x86_64<br>arm64",
        "virtualization": ":x:",
        "sudo": ":x:",
        "notes": "n/a",
    },
    {
        "shortname": "ubi9",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/ubi9:latest",
        "baseimage": "[ubi9-init:9.6](https://catalog.redhat.com/software/containers/ubi9-init/6183297540a2d8e95c82e8bd)",
        "architectures": "x86_64<br>arm64",
        "virtualization": ":x:",
        "sudo": ":x:",
        "notes": "n/a",
    },
    {
        "shortname": "ubi10",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/ubi10:latest",
        "baseimage": "[ubi10-init:10.0](https://catalog.redhat.com/software/containers/ubi10-init/66f2aabb701371ba5f56497a?image=686bd755edf0de590015a72d&container-tabs=overview)",
        "architectures": "x86_64<br>arm64",
        "virtualization": ":x:",
        "sudo": ":x:",
        "notes": "n/a",
    },
    {
        "shortname": "rootless-ubuntu-jammy",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/rootless-ubuntu-jammy:latest",
        "baseimage": "[ubuntu:jammy](https://hub.docker.com/_/ubuntu) (22.04 LTS)",
        "architectures": "x86_64<br>arm64",
        "virtualization": "rootless Docker-in-Docker",
        "sudo": ":x:",
        "notes": "[common rootless problems](docs/tips-and-tricks.md#rootless-images)",
    },
    {
        "shortname": "rootless-ubuntu-numbat",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/rootless-ubuntu-numbat:latest",
        "baseimage": "[ubuntu:numbat](https://hub.docker.com/_/ubuntu) (24.04 LTS)",
        "architectures": "x86_64<br>arm64",
        "virtualization": "rootless Docker-in-Docker",
        "sudo": ":x:",
        "notes": "[common rootless problems](docs/tips-and-tricks.md#rootless-images)",
    },
    {
        "shortname": "wolfi:latest",
        "fulltag": "ghcr.io/some-natalie/kubernoodles/wolfi:latest",
        "baseimage": "[wolfi-base:latest](https://images.chainguard.dev/directory/image/wolfi-base/versions)",
        "architectures": "x86_64<br>arm64",
        "virtualization": ":x:",
        "sudo": ":x:",
        "notes": "n/a",
    },
]


# Get the date
def get_date():
    date = datetime.datetime.now()
    date = date.strftime("%d %B %Y")
    return date


# Get the CVE count by image (full tag, eg "ghcr.io/some-natalie/kubernoodles/wolfi:latest")
def get_cve_count(image):
    # Get the CVE count
    cve_count = os.popen("grype -o json " + image).read()
    cve_count = json.loads(cve_count)
    severities = [match["vulnerability"]["severity"] for match in cve_count["matches"]]
    criticals = Counter(severities)["Critical"]
    highs = Counter(severities)["High"]
    lowers = (
        Counter(severities)["Medium"]
        + Counter(severities)["Low"]
        + Counter(severities)["Negligible"]
        + Counter(severities)["Unknown"]
    )
    return criticals, highs, lowers


# do the thing
if __name__ == "__main__":
    # Get the date
    date = get_date()

    # Open the README.md file
    with open("README.md", "r") as f:
        readme = f.readlines()
        f.close()

        # Delete the old date block
        del readme[
            readme.index("<!-- START_SECTION:date -->\n")
            + 1 : readme.index("<!-- END_SECTION:date -->\n")
        ]

        # Make the new date block
        date_block = [
            "> [!NOTE]\n> CVE count was done on "
            + date
            + " with the latest versions of [grype](https://github.com/anchore/grype) and runner image tags."
        ]

        # Insert the new date block
        readme.insert(
            readme.index("<!-- START_SECTION:date -->\n") + 1,
            "\n".join(date_block) + "\n",
        )

        # Delete the old cve block
        del readme[
            readme.index("<!-- START_SECTION:table -->\n")
            + 1 : readme.index("<!-- END_SECTION:table -->\n")
        ]

        # Make the new cve block
        header = "| image name | base image | CVE count<br>(crit/high/med+below) | archs | virtualization? | sudo? | notes |\n"
        header += "|---|---|---|---|---|---|---|\n"
        for i in image_list:
            cve_count = get_cve_count(i["fulltag"])
            cve_block = (
                "| "
                + i["shortname"]
                + " | "
                + i["baseimage"]
                + " | "
                + str(cve_count[0])
                + "/"
                + str(cve_count[1])
                + "/"
                + str(cve_count[2])
                + " | "
                + i["architectures"]
                + " | "
                + i["virtualization"]
                + " | "
                + i["sudo"]
                + " | "
                + i["notes"]
                + " |\n"
            )
            header += cve_block

        # Insert the new cve block
        readme.insert(
            readme.index("<!-- START_SECTION:table -->\n") + 1,
            header,
        )

    # Write the updated README.md file
    with open("README.md", "w") as f:
        f.writelines(readme)
        f.close()
