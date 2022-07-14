#!/bin/bash
source /usr/bin/logger.sh

function wait_for_process () {
    local max_time_wait=30
    local process_name="$1"
    local waited_sec=0
    while ! pgrep "$process_name" >/dev/null && ((waited_sec < max_time_wait)); do
        logger.notice "Process $process_name is not running yet. Retrying in 2 seconds"
        logger.notice "Waited $waited_sec seconds of $max_time_wait seconds"
        sleep 2
        ((waited_sec=waited_sec+2))
        if ((waited_sec >= max_time_wait)); then
            {
              sudo "$process_name" &
            } || {
              return 1
            }
        fi
    done
    return 0
}

dump() {
  local path=${1:?missing required <path> argument}
  shift
  printf -- "%s\n---\n" "${*//\{path\}/"$path"}" 1>&2
  cat "$path" 1>&2
  printf -- '---\n' 1>&2
}

for config in /etc/docker/daemon.json /etc/supervisor/conf.d/dockerd.conf; do
  dump "$config" 'Using {path} with the following content:'
done

logger.debug "Starting supervisor"
sudo /usr/bin/supervisord -n >> /dev/null 2>&1 &

logger.debug "Waiting for processes to be running"
processes=(dockerd)

for process in "${processes[@]}"; do
    sleep 10
    wait_for_process "$process"
    if [ $? -ne 0 ]; then
        logger.error "$process is not running after max time"
        dump /var/log/dockerd.err.log 'Dumping {path} to aid investigation'
        exit 1
    else
        logger.debug "$process is running"
    fi
done

if [ -n "${MTU}" ]; then
  sudo ifconfig docker0 mtu ${MTU} up
fi

# Wait processes to be running
entrypoint.sh
