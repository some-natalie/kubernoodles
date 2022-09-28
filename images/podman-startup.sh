#!/bin/bash
source /usr/bin/logger.sh

logger.notice "Symlinking static cache assets"
ln -s /opt/statictoolcache/* /opt/hostedtoolcache && ls -l /opt/hostedtoolcache

# Wait processes to be running
entrypoint.sh
