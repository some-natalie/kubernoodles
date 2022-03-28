#!/bin/bash
source /opt/bash-utils/logger.sh

if [ -e "/.env" ]; then
  echo "Adding custom environment variables" 1>&2
  source /.env
fi

if [ -z "${GITHUB_URL}" ]; then
  echo "Working with public GitHub" 1>&2
  GITHUB_URL="https://github.com/"
else
  length=${#GITHUB_URL}
  last_char=${GITHUB_URL:length-1:1}

  [[ $last_char != "/" ]] && GITHUB_URL="$GITHUB_URL/"; :
  echo "Github endpoint URL ${GITHUB_URL}"
fi

if [ -z "${RUNNER_NAME}" ]; then
  echo "RUNNER_NAME must be set" 1>&2
  exit 1
fi

if [ -n "${RUNNER_ORG}" ] && [ -n "${RUNNER_REPO}" ] && [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="${RUNNER_ORG}/${RUNNER_REPO}"
elif [ -n "${RUNNER_ORG}" ]; then
  ATTACH="${RUNNER_ORG}"
elif [ -n "${RUNNER_REPO}" ]; then
  ATTACH="${RUNNER_REPO}"
elif [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="enterprises/${RUNNER_ENTERPRISE}"
else
  echo "At least one of RUNNER_ORG or RUNNER_REPO or RUNNER_ENTERPRISE must be set" 1>&2
  exit 1
fi

if [ -n "${RUNNER_WORKDIR}" ]; then
  WORKDIR_ARG="--work ${RUNNER_WORKDIR}"
fi

if [ -n "${RUNNER_LABELS}" ]; then
  LABEL_ARG="--labels ${RUNNER_LABELS}"
fi

if [ -z "${RUNNER_TOKEN}" ]; then
  echo "RUNNER_TOKEN must be set" 1>&2
  exit 1
fi

if [ -z "${RUNNER_REPO}" ] && [ -n "${RUNNER_ORG}" ] && [ -n "${RUNNER_GROUP}" ];then
  RUNNER_GROUP_ARG="--runnergroup ${RUNNER_GROUP}"
fi

# Hack due to https://github.com/summerwind/actions-runner-controller/issues/252#issuecomment-758338483
if [ ! -d /runner ]; then
  echo "/runner should be an emptyDir mount. Please fix the pod spec." 1>&2
  exit 1
fi

sudo chown -R runner:docker /runner
mv /runnertmp/* /runner/

cd /runner || exit 2
./config.sh --unattended --replace --name "${RUNNER_NAME}" --url "${GITHUB_URL}${ATTACH}" --token "${RUNNER_TOKEN}" ${RUNNER_GROUP_ARG} ${LABEL_ARG} ${WORKDIR_ARG}
mkdir ./externals
# Hack due to the DinD volumes
mv ./externalstmp/* ./externals/

unset RUNNER_NAME RUNNER_REPO RUNNER_TOKEN
exec ./bin/runsvc.sh
