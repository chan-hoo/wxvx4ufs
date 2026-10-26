#!/usr/bin/env bash

set -xue

ulimit -s unlimited; ulimit -a;

# Load the shared YAML utility.
source "${USHwxvx}/yaml_utils.sh"
config_common="${exp_case_path}/configs/config_common.yaml"

# Read common configuration values.
platform=$(read_yaml "${config_common}" "platform")
run_type=$(read_yaml "${config_common}" "run_type")
workflow_type=$(read_yaml "${config_common}" "workflow_type")

# Copy input files to temporary working directory.
if [[ "${run_type}" == "ctest" ]]; then
  # EAGLE workflow case
  if [[ "${workflow_type}" == "eagle" ]]; then
    # Forecast output
    cp -rp "${FIXwxvx}/data_${platform}/ctest/${workflow_type}/inference_output" ${DATA}/.
    # Reference datasets
    mkdir -p ${DATA}/data
    cp -rp "${FIXwxvx}/data_${platform}/ctest/${workflow_type}/prewxvx/data/hrrr.zarr" ${DATA}/data/.
    cp -rp "${FIXwxvx}/data_${platform}/ctest/${workflow_type}/prewxvx/data/gfs.zarr" ${DATA}/data/.
    # Target grid
    cp -p "${FIXwxvx}/data_${platform}/ctest/${workflow_type}/prewxvx/target_grid/global_one_degree.nc" ${DATA}/data/.
  fi
fi


# Update configuration file with temporary working directory.
config_fn="config_prewxvx.yaml"
cp -p "${exp_case_path}/configs/${config_fn}" "${DATA}/."
sed -i "s|{{ DATA }}|${DATA}|g" ${config_fn}

# Run wxvx.
export pgm="eagle-tools prewxvx"

. prep_step
time ${pgm} ${config_fn}
export err=$?; err_chk
if [[ $err != 0 ]]; then
  err_exit "eagle-tools: prewxvx failed"
fi

# Copy result files/directories to COMOUT
cp -rp ${DATA}/post_prewxvx ${COMOUT}/.
