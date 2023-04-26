#!/bin/bash
source /usr/bin/logger.sh

# Wait processes to be running
cd /actions-runner && ./run.sh
