#!/bin/bash
source /opt/bash-utils/logger.sh

INFO "Starting Docker (rootless)"
/home/runner/bin/dockerd-rootless.sh -H tcp://0.0.0.0:2376 >> /dev/null 2>&1 &

# Wait processes to be running
entrypoint.sh
