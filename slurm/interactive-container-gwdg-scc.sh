#!/bin/bash
#SBATCH --job-name=dc
#SBATCH --partition=jupyter
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --output=%u/logs/interactive/vscode-dev.%j.txt
#SBATCH --nodelist=agq[001-012]

# Container image path
CONTAINER_IMAGE=/user/egor.kotov/u14190/containers/rbinder-451-sshd.sif

# Load apptainer
module purge
module load apptainer

# Get hostname
HOSTNAME=$(hostname -s)
echo "Running on host: ${HOSTNAME}"
scontrol show job $SLURM_JOB_ID

# Choose a unique port for this container (based on job ID to avoid conflicts)
CONTAINER_PORT=$((10000 + SLURM_JOB_ID % 10000))

# Create custom passwd file with bash as shell (Dropbear checks shell exists)
PASSWD_FILE="/tmp/passwd.u14190.$$"
getent passwd u14190 | sed 's|/bin/zsh|/bin/bash|' > ${PASSWD_FILE}
getent passwd root >> ${PASSWD_FILE}

# Start apptainer instance with custom passwd
apptainer instance start \
  --bind ${TMPDIR}:/tmp,/home,/user,/local,/mnt,/scratch \
  --bind $HOME/.vscode-server:$HOME/.vscode-server \
  --bind $HOME/.positron-server:$HOME/.positron-server \
  --bind $HOME/.zed_server:$HOME/.zed_server \
  --bind ${PASSWD_FILE}:/etc/passwd \
  ${CONTAINER_IMAGE} \
  devcontainer

echo "Container instance 'devcontainer' started on ${HOSTNAME}"
echo "Container port: ${CONTAINER_PORT}"
echo ""

# Generate Dropbear host keys (if they don't exist)
SSH_KEY_DIR="${HOME}/.ssh/dropbear-keys"
mkdir -p ${SSH_KEY_DIR}
chmod 700 ${SSH_KEY_DIR}

if [ ! -f ${SSH_KEY_DIR}/dropbear_rsa_host_key ]; then
  echo "Generating Dropbear host keys..."
  apptainer exec instance://devcontainer \
    dropbearkey -t rsa -f ${SSH_KEY_DIR}/dropbear_rsa_host_key
  apptainer exec instance://devcontainer \
    dropbearkey -t ecdsa -f ${SSH_KEY_DIR}/dropbear_ecdsa_host_key
fi

# Ensure authorized_keys exists and has correct permissions
mkdir -p ${HOME}/.ssh
chmod 700 ${HOME}/.ssh
touch ${HOME}/.ssh/authorized_keys
chmod 600 ${HOME}/.ssh/authorized_keys

# Start Dropbear SSH daemon inside the container
echo "Starting Dropbear SSH daemon in container..."
apptainer exec instance://devcontainer \
  dropbear \
  -F \
  -E \
  -p ${CONTAINER_PORT} \
  -r ${SSH_KEY_DIR}/dropbear_rsa_host_key \
  -r ${SSH_KEY_DIR}/dropbear_ecdsa_host_key \
  &

DROPBEAR_PID=$!
echo "Dropbear SSH daemon started with PID: ${DROPBEAR_PID}"
echo ""

# Wait for Dropbear to start
sleep 3

# Test if Dropbear is listening
if netstat -tln | grep -q ":${CONTAINER_PORT} "; then
  echo "✓ Dropbear SSH daemon is listening on port ${CONTAINER_PORT}"
else
  echo "✗ Warning: Dropbear might not be listening"
  echo "Check logs with: apptainer exec instance://devcontainer ps aux | grep dropbear"
fi

echo ""
echo "=========================================="
echo "✓ Container ready!"
echo ""
echo "To connect with Positron:"
echo "  1. In local terminal, run:"
echo "     ssh -L 2222:localhost:${CONTAINER_PORT} hpc-${HOSTNAME}"
echo ""
echo "  2. In Positron, connect to: container-local"
echo "     (or manually: localhost:2222, user: u14190)"
echo "=========================================="
echo ""

# Save the port for easy access
echo ${CONTAINER_PORT} > $HOME/.hpc-container-port-${HOSTNAME}

# Keep job alive
sleep infinity
