#!/usr/bin/env bash

set -euo pipefail

# ==============================================================
# Define installation directories
# ==============================================================

INSTALL_ROOT="$(pwd -P)"
INSTALLDIR="$INSTALL_ROOT/conda"

export CONDA_PKGS_DIRS="$INSTALLDIR/pkgs"
export CONDA_ENVS_PATH="$INSTALLDIR/envs"
export XDG_CACHE_HOME="$INSTALLDIR/cache"

WXVX_ENV="$CONDA_ENVS_PATH/wxvx"
PLOT_ENV="$CONDA_ENVS_PATH/plot"

echo "Installation root: $INSTALL_ROOT"
echo "Miniforge:         $INSTALLDIR"
echo "Package cache:     $CONDA_PKGS_DIRS"
echo "Environment path:  $CONDA_ENVS_PATH"

# ==============================================================
# Select environments to build
# ==============================================================

case "${1:-all}" in
    wxvx)
        ENVIRONMENTS=("wxvx")
        ;;
    plot)
        ENVIRONMENTS=("plot")
        ;;
    all)
        ENVIRONMENTS=("wxvx" "plot")
        ;;
    *)
        echo "Error: Invalid environment: $1" >&2
        echo "Usage: $0 [wxvx|plot]" >&2
        echo "  No argument: Build both environments" >&2
        exit 1
        ;;
esac

if (( $# > 1 )); then
    echo "Error: Too many arguments." >&2
    echo "Usage: $0 [wxvx|plot]" >&2
    exit 1
fi

# ==============================================================
# Detect architecture
# ==============================================================

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)
        ARCH="x86_64"
        ;;
    Linux-aarch64)
        ARCH="aarch64"
        ;;
    *)
        echo "Error: Unsupported operating system or architecture:"
        echo "       $(uname -s)-$(uname -m)"
        exit 1
        ;;
esac

echo "Architecture:      $ARCH"

# ==============================================================
# Install Miniforge locally
# ==============================================================

MINIFORGE_VERSION="26.1.1-3"
INSTALLER="Miniforge3-${MINIFORGE_VERSION}-Linux-${ARCH}.sh"

INSTALLER_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/${INSTALLER}"

if [[ -x "$INSTALLDIR/bin/conda" ]]; then
    echo "Found existing Miniforge installation: $INSTALLDIR"
else
    if [[ -e "$INSTALLDIR" ]]; then
        echo "Error: $INSTALLDIR exists but is not a valid Miniforge installation." >&2
        echo "Please inspect the directory before proceeding." >&2
        exit 1
    fi

    mkdir -p "$INSTALL_ROOT"

    echo "Downloading Miniforge ${MINIFORGE_VERSION}..."

    if command -v wget >/dev/null 2>&1; then
        wget -O "$INSTALL_ROOT/$INSTALLER" "$INSTALLER_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -fL "$INSTALLER_URL" -o "$INSTALL_ROOT/$INSTALLER"
    else
        echo "Error: Neither wget nor curl is available." >&2
        exit 1
    fi

    echo "Installing Miniforge into $INSTALLDIR..."

    bash "$INSTALL_ROOT/$INSTALLER" -bfp "$INSTALLDIR"

    rm -f "$INSTALL_ROOT/$INSTALLER"
fi

# ==============================================================
# Configure local Conda directories
# ==============================================================

mkdir -p "$CONDA_PKGS_DIRS"
mkdir -p "$CONDA_ENVS_PATH"
mkdir -p "$XDG_CACHE_HOME"

# Use a project-local Conda configuration.
export CONDARC="$INSTALL_ROOT/condarc"

cat > "$CONDARC" <<EOF
channels:
  - conda-forge

envs_dirs:
  - $CONDA_ENVS_PATH

pkgs_dirs:
  - $CONDA_PKGS_DIRS

register_envs: false
EOF

# ==============================================================
# Initialize Conda without conda init
# ==============================================================

source "$INSTALLDIR/etc/profile.d/conda.sh"

echo
echo "Conda version:"
conda --version

echo
echo "Effective Conda configuration:"
conda info

# ==============================================================
# Build selected Python environments
# ==============================================================

for ENV_NAME in "${ENVIRONMENTS[@]}"; do

    echo
    echo "=============================================================="
    echo "Processing environment: $ENV_NAME"
    echo "=============================================================="

    ENV_FILE="$INSTALL_ROOT/${ENV_NAME}.yaml"
    ENV_PREFIX="$CONDA_ENVS_PATH/$ENV_NAME"

    # ----------------------------------------------------------
    # Check environment YAML
    # ----------------------------------------------------------

    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: Environment YAML not found: $ENV_FILE" >&2
        exit 1
    fi

    # ----------------------------------------------------------
    # Skip existing environments
    # ----------------------------------------------------------

    if [[ -x "$ENV_PREFIX/bin/python" ]]; then
        echo "Found existing environment: $ENV_PREFIX"
        echo "Skipping environment creation and verification."
        continue
    fi

    if [[ -e "$ENV_PREFIX" ]]; then
        echo "Error: $ENV_PREFIX exists but does not appear to be a valid Python environment." >&2
        echo "Please inspect the directory before proceeding." >&2
        exit 1
    fi

    # ----------------------------------------------------------
    # Create environment from YAML
    # ----------------------------------------------------------

    echo "Creating $ENV_NAME environment from:"
    echo "  $ENV_FILE"

    conda env create \
        --prefix "$ENV_PREFIX" \
        --file "$ENV_FILE"

    # ----------------------------------------------------------
    # Verify installation
    # ----------------------------------------------------------

    echo
    echo "Verifying $ENV_NAME environment..."

    conda run --prefix "$ENV_PREFIX" python --version
    conda run --prefix "$ENV_PREFIX" python -m pip --version

    if [[ "$ENV_NAME" == "wxvx" ]]; then
        conda run --prefix "$ENV_PREFIX" wxvx --version
    fi

    conda run --prefix "$ENV_PREFIX" uw --version

    echo
    echo "Installed packages in $ENV_NAME:"
    conda list --prefix "$ENV_PREFIX"

    echo
    echo "Environment completed successfully: $ENV_PREFIX"

done

# ==============================================================
# Create activation scripts
# ==============================================================

cat > "$INSTALL_ROOT/activate_wxvx.sh" <<EOF
#!/usr/bin/env bash

# Activate the locally installed wxvx environment.
# Source this script; do not execute it.

_CONDA_ROOT="$INSTALLDIR"
_WXVX_ENV="\$_CONDA_ROOT/envs/wxvx"

if [[ ! -f "\$_CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
    echo "Error: Local Miniforge installation not found: \$_CONDA_ROOT" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ ! -d "\$_WXVX_ENV" ]]; then
    echo "Error: wxvx environment not found: \$_WXVX_ENV" >&2
    return 1 2>/dev/null || exit 1
fi

source "\$_CONDA_ROOT/etc/profile.d/conda.sh"
conda activate "\$_WXVX_ENV"

conda list | grep -E 'wxvx|met2go|uwtools|eagle-tools'
EOF

cat > "$INSTALL_ROOT/activate_plot.sh" <<EOF
#!/usr/bin/env bash

# Activate the locally installed plot environment.
# Source this script; do not execute it.

_CONDA_ROOT="$INSTALLDIR"
_PLOT_ENV="\$_CONDA_ROOT/envs/plot"

if [[ ! -f "\$_CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
    echo "Error: Local Miniforge installation not found: \$_CONDA_ROOT" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ ! -d "\$_PLOT_ENV" ]]; then
    echo "Error: plot environment not found: \$_PLOT_ENV" >&2
    return 1 2>/dev/null || exit 1
fi

source "\$_CONDA_ROOT/etc/profile.d/conda.sh"
conda activate "\$_PLOT_ENV"

conda list | grep -E 'cartopy|matplotlib|numpy|pandas|uwtools|eagle-tools'
EOF

chmod +x "$INSTALL_ROOT/activate_wxvx.sh"
chmod +x "$INSTALL_ROOT/activate_plot.sh"

echo
echo "=============================================================="
echo "Build process completed successfully."
echo "=============================================================="

echo "Miniforge:          $INSTALLDIR"
echo "wxvx environment:   $WXVX_ENV"
echo "plot environment:   $PLOT_ENV"
echo "Package cache:      $CONDA_PKGS_DIRS"
echo "Conda config:       $CONDARC"
echo
echo "Activation scripts:"
echo "  source ./activate_wxvx.sh"
echo "  source ./activate_plot.sh"
