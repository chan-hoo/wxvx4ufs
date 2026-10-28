#!/usr/bin/env bash

set -xue

ulimit -s unlimited; ulimit -a;


# Copy input files to temporary working directory.
mkdir -p ${DATA}/run
cp -rp ${COMIN}/grid2grid_stats ${DATA}/run/stats

# Update configuration file with temporary working directory.
config_fn="config_postwxvx_grid.yaml"
cp -p "${exp_case_path}/configs/${config_fn}" "${DATA}/."
sed -i "s|{{ DATA }}|${DATA}|g" ${config_fn}

# Run wxvx.
export pgm="eagle-tools postwxvx"

. prep_step
time ${pgm} ${config_fn}
export err=$?; err_chk
if [[ $err != 0 ]]; then
  err_exit "eagle-tools: postwxvx_grid failed"
fi

# Copy result files/directories to COMOUT
mkdir -p ${DATA}/postwxvx_grid
mv -- *.nc ${DATA}/postwxvx_grid/
cp -rp ${DATA}/postwxvx_grid ${COMOUT}/.
