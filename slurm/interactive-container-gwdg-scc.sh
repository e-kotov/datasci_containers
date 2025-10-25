#!/bin/bash
#SBATCH --job-name=dc
#SBATCH --partition=jupyter
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --output=/user/egor.kotov/%u/logs/interactive/dc.job.%j.txt

# Container image path
CONTAINER_IMAGE=/user/egor.kotov/u14190/containers/rbinder-451-sshd.sif

# Load apptainer
module purge
module load apptainer

export XDG_RUNTIME_DIR=""
export ftp_proxy=http://www-cache.gwdg.de:3128
export http_proxy=http://www-cache.gwdg.de:3128
export https_proxy=http://www-cache.gwdg.de:3128
export NO_PROXY=*.hlrn.de,jupyter.hpc.gwdg.de,jupyter.usr.hpc.gwdg.de,localhost,127.0.0.1
# Make sure these land inside the container as well
export APPTAINERENV_LC_ALL=en_US.UTF-8
export APPTAINERENV_http_proxy="$http_proxy"
export APPTAINERENV_https_proxy="$https_proxy"
export APPTAINERENV_ftp_proxy="$ftp_proxy"
export APPTAINERENV_NO_PROXY="$NO_PROXY"

export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
export MKL_NUM_THREADS="$SLURM_CPUS_PER_TASK"


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

unset WRITABLETMP
BIND="/home,/local,/mnt,/mnt/vast-orga,/opt/misc,/opt/slurm,/projects,/user_datastore_map,/pools,/run/munge,/scratch,/sw/viz/jupyterhub-nhr,/user,/usr/lib64/libmunge.so.2,/usr/lib64/libmunge.so.2.0.0,/usr/local/slurm,/var/run/dbus,/var/run/munge"
WRITABLETMP="--writable-tmpfs"

for fs in /sw /scratch /scratch-emmy /scratch-grete /scratch-scc /scratch1 /usr/users /home /mnt/vast-* /mnt/lustre-* /mnt/ceph-* ; do
    [[ -d "$fs" ]] && BIND+=",$fs"
done


apptainer instance start \
  --bind $BIND \
  --bind $HOME/.vscode-server:$HOME/.vscode-server \
  --bind $HOME/.positron-server:$HOME/.positron-server \
  --bind $HOME/.zed_server:$HOME/.zed_server \
  --bind ${PASSWD_FILE}:/etc/passwd \
  $WRITABLETMP \
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
