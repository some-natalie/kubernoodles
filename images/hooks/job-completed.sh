#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=runner/logger.bash
source logger.bash

log.debug "Running ARC Job Completed Hooks"

for hook in /etc/arc/hooks/job-completed.d/*; do
  log.debug "Running hook: $hook"
  "$hook" "$@"
done
