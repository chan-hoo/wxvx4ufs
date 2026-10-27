#!/usr/bin/env bash

set -e

# ------------------------------------------------------------
# ecFlow server configuration
# ------------------------------------------------------------

if [ -z "${ECF_HOST:-}" ]; then
    export ECF_HOST=$(hostname)
fi

if [ -z "${ECF_PORT:-}" ]; then
    export ECF_PORT=$(( $(id -u) + 1500 ))
fi

export ECF_HOME="{{ exp_case_path }}/ecf"
export ECF_SUITE="{{ exp_case_name }}"

echo "ECF_HOME:  ${ECF_HOME}"
echo "ECF_PORT:  ${ECF_PORT}"
echo "ECF_HOST:  ${ECF_HOST}"
echo "ECF_SUITE: ${ECF_SUITE}"

# ------------------------------------------------------------
# Check whether the suite exists on the specified server
# ------------------------------------------------------------

if ecflow_client \
        --port="${ECF_PORT}" \
        --host="${ECF_HOST}" \
        --get_state="/${ECF_SUITE}" >/dev/null 2>&1; then

    echo "Suite /${ECF_SUITE} exists. Deleting..."

    ecflow_client \
        --port="${ECF_PORT}" \
        --host="${ECF_HOST}" \
        --delete=force yes "/${ECF_SUITE}"

else
    echo "Suite /${ECF_SUITE} does NOT exist. Skipping delete."
fi

# ------------------------------------------------------------
# Load the suite definition
# ------------------------------------------------------------

echo "Loading ${ECF_SUITE}.def ..."

ecflow_client \
    --port="${ECF_PORT}" \
    --host="${ECF_HOST}" \
    --load="${ECF_HOME}/${ECF_SUITE}.def"

echo "Suite definition loaded successfully."

# ------------------------------------------------------------
# Begin the suite
# ------------------------------------------------------------

echo "Beginning suite ${ECF_SUITE} ..."

ecflow_client \
    --port="${ECF_PORT}" \
    --host="${ECF_HOST}" \
    --begin="${ECF_SUITE}"

echo "Suite ${ECF_SUITE} started successfully."
