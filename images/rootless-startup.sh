#!/bin/bash
source /opt/bash-utils/logger.sh

INFO "Starting Docker (rootless)"
/home/runner/bin/dockerd-rootless.sh --config-file /home/runner/.config/docker/daemon.json >> /dev/null 2>&1 &

# Wait processes to be running
entrypoint.sh
