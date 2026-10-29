# Quick-start-guide

**Weather Verification (wxvx) for Unified Forecast System (UFS), including Global Workflow, EAGLE, and RRFS**

This repository provides scripts to install and configure [`wxvx`](https://github.com/NOAA-GSL/wxvx) for use with UFS applications, including Global Workflow and RRFS Workflow, on NOAA RDHPCS platforms.

## 1. Build and Installation

### Step 1. Clone the repository

Choose one of the following methods to clone the repository.

- SSH (if you have configured an SSH key for GitHub):

  ```bash
  git clone git@github.com:chan-hoo/wxvx4ufs.git
  ```

- HTTPS:

  ```bash
  git clone https://github.com/chan-hoo/wxvx4ufs.git
  ```

### Step 2. Run the installation script

```bash
cd wxvx4ufs/sorc
./build_wxvx4ufs.sh
```

## 2. Activate the wxvx Environment

After installation, activate the environment by sourcing the activation script:

```bash
source activate_wxvx.sh
```

### Deactivate the Environment

If the environment is active and Conda is initialized in your current shell:

```bash
conda deactivate
```

## 3. Configuration

The configuration YAML files and setup script are located in the `parm` directory:

```bash
cd wxvx4ufs/parm
```

The main configuration files are:

- `config_base.yaml`: Define the basic configuration parameters.
- `config_platform.yaml`: Define the platform-specific configuration parameters.

Before proceeding, review the `account`, `exp_case_name`, and `platform` parameters.

```bash
vim config_base.yaml
```

You can check the list of tasks selected by `task_list` from the available tasks under the `tasks` group.

Run the setup script to generate the experimental-case configuration and supporting directories:

```bash
./setup.py
```

By default, the script generates the `exp_cases` and `PTMP` directories under the `parm` directory.

## 4. Job Submission

### ecFlow option (`app.workflow_manager: ecflow`)

Load the module(s) for ecFlow.

- On Ursa / Derecho:

  ```bash
  module load ecflow/5.11.4
  ```

- On Hercules / Orion / Gaea-C6:

  ```bash
  cd ..
  module use modulefiles
  module load modules_[hercules/orion/gaea-c6]
  ```

Start the ecFlow server if necessary:

```bash
cd parm/exp_cases/[app.exp_case_name]/ecf
./start_server.sh
```

Begin the case-specific ecFlow suite:

```bash
./begin_suite.sh
```

Open the ecFlow GUI:

```bash
ecflow_ui &
```

Note that the ecFlow GUI does not work correctly on Gaea-C6.

Stop the ecFlow server once all workflow tasks are complete:

```bash
./stop_server.sh
```

### Manual submission of job cards (`app.workflow_manager: None`)

Navigate to the job cards directory for your experimental case:

```bash
cd exp_cases/[app.exp_case_name]/job_cards
```

Submit the desired task.

- Slurm (Ursa / Hercules / Orion / Gaea-C6):

  ```bash
  sbatch jwxvx_[task_name]
  ```

- PBS Pro (Derecho):

  ```bash
  qsub jwxvx_[task_name]
  ```

## 5. Results and Log Files

After the job completes, check the following directories for output files and execution logs:

- `com_dir`: Symlink to the directory containing the result files.
- `log_dir`: Symlink to the directory containing the log files.
- `tmp_dir`: Symlink to the directory containing the working directories.
