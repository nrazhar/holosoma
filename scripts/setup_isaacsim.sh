# Exit on error, and print commands
set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Create overall workspace
source ${SCRIPT_DIR}/source_common.sh
ENV_ROOT=$CONDA_ROOT/envs/hssim
SENTINEL_FILE=${WORKSPACE_DIR}/.env_setup_finished_isaacsim

mkdir -p $WORKSPACE_DIR

if [[ ! -f $SENTINEL_FILE ]]; then
  # Install miniconda
  if [[ ! -d $CONDA_ROOT ]]; then
    mkdir -p $CONDA_ROOT
    curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o $CONDA_ROOT/miniconda.sh
    bash $CONDA_ROOT/miniconda.sh -b -u -p $CONDA_ROOT
    rm $CONDA_ROOT/miniconda.sh
  fi

  # Create the conda environment
  if [[ ! -d $ENV_ROOT ]]; then
    $CONDA_ROOT/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
    $CONDA_ROOT/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
    $CONDA_ROOT/bin/conda install -y mamba -c conda-forge -n base
    MAMBA_ROOT_PREFIX=$CONDA_ROOT $CONDA_ROOT/bin/mamba create -y -n hssim python=3.11 -c conda-forge --override-channels
  fi

  source $CONDA_ROOT/bin/activate hssim

  # Install ffmpeg for video encoding
  conda install -c conda-forge -y ffmpeg
  conda install -c conda-forge -y libiconv
  conda install -c conda-forge -y libglu

  # Below follows https://isaac-sim.github.io/IsaacLab/main/source/setup/installation/pip_installation.html
  # Install IsaacSim
  pip install --upgrade pip
  # Pinning triton version. It's a dep of a dep, but seeing issues with 3.4.0+
  pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128  
  # Install dependencies from PyPI first
  pip install pyperclip
  # Then install isaacsim from NVIDIA index only
  pip install "isaacsim[all,extscache]==5.1.0" --extra-index-url https://pypi.nvidia.com

  if [[ ! -d $WORKSPACE_DIR/IsaacLab ]]; then
    git clone https://github.com/isaac-sim/IsaacLab.git $WORKSPACE_DIR/IsaacLab
  fi
  sudo apt install -y cmake build-essential
  
  # Install CycloneDDS (required for Unitree SDK)
  if [[ ! -d $WORKSPACE_DIR/cyclonedds ]]; then
    git clone https://github.com/eclipse-cyclonedds/cyclonedds -b releases/0.10.x $WORKSPACE_DIR/cyclonedds
  fi
  
  if [[ ! -d $WORKSPACE_DIR/cyclonedds/install ]]; then
      cd $WORKSPACE_DIR/cyclonedds && mkdir -p build install && cd build
      cmake .. -DCMAKE_INSTALL_PREFIX=../install
      cmake --build . --target install
  fi
  export CYCLONEDDS_HOME="$WORKSPACE_DIR/cyclonedds/install"

  # Install Unitree Python SDK for sim2sim
  if [[ ! -d $WORKSPACE_DIR/unitree_sdk2_python ]]; then
    git clone https://github.com/unitreerobotics/unitree_sdk2_python.git $WORKSPACE_DIR/unitree_sdk2_python
  fi
  pip install -e $WORKSPACE_DIR/unitree_sdk2_python/

  
  cd $WORKSPACE_DIR/IsaacLab
  # work-around for egl_probe cmake max version issue
  export CMAKE_POLICY_VERSION_MINIMUM=3.5
  ./isaaclab.sh --install

 # Install Holosoma
  pip install -U pip
  pip install -e $ROOT_DIR/src/holosoma[unitree,booster]

  # Force upgrade wandb to override rl-games constraint
  pip install --upgrade 'wandb>=0.21.1'
  touch $SENTINEL_FILE
fi
