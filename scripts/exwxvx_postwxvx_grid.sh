#!/usr/bin/env bash

set -xue

ulimit -s unlimited; ulimit -a;

# Load the shared YAML utility.
source "${USHwxvx}/yaml_utils.sh"
config_common="${exp_case_path}/configs/config_common.yaml"

# Read common configuration values.
platform=$(read_yaml "${config_common}" "platform")

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

# ---------------------------
# Plotting
# ---------------------------
# Plot result NetCDF files
ncdir="${DATA}/postwxvx_grid"
spatial_stats_root="${DATA}/run/stats"
basic_outdir="${DATA}/plots_grid_basic"
mkdir -p ${basic_outdir}
spatial_outdir="${DATA}/plots_grid_spatial_stats"
mkdir -p ${spatial_outdir}

cat > plot_config.yaml <<EOF
cartopy_ne_path: '${FIXwxvx}/data_${platform}/NaturalEarth'
ncdir: '${ncdir}'
spatial_stats_root: '${spatial_stats_root}'
basic_outdir: '${basic_outdir}'
spatial_outdir: '${spatial_outdir}'
EOF

python ${USHwxvx}/plot_wxvx.py plot_config.yaml
if [ $? -ne 0 ]; then
  err_exit "postwxvx_grid plot failed"
fi

# Copy result files/directories to COMOUT
cp -rp ${basic_outdir} ${COMOUT}/.
cp -rp ${spatial_outdir} ${COMOUT}/.
