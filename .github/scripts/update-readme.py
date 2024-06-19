#!/usr/bin/env python3

"""
This script updates the date and CVE scan results in the README.md file.
"""

# Imports
import datetime
import json
import os


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
    cve_count = cve_count["vulnerabilities"]
    cve_count = len(cve_count)
    print(cve_count)
    return cve_count


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
        # del readme[
        #     readme.index("<!-- START_SECTION:table -->\n")
        #     + 1 : readme.index("<!-- END_SECTION:table -->\n")
        # ]

        # Make the new cve block
        # header = "| image name | base image | CVE count<br>(crit/high/med) | virtualization? | sudo? | notes |\n"
        # header += "|---|---|---|---|---|---|\n"

        wolfi_cves = get_cve_count("ghcr.io/some-natalie/kubernoodles/wolfi:latest")
        print(wolfi_cves)

    # Write the updated README.md file
    with open("README.md", "w") as f:
        f.writelines(readme)
        f.close()
