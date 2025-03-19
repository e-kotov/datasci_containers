#!/bin/bash
#SBATCH --job-name=r-int-cg
#SBATCH --partition=jupyter
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --gpus=1
#SBATCH -C scratch
#SBATCH --output=/user/egor.kotov/%u/logs/interactive/r-int-cg.job.%j.txt


CONTAINER_IMAGE=${CONTAINER_IMAGE:-${HOME}/jupyterhub-gwdg/jupyter.sif}

# example use to run with custom image
# cd ~
# sbatch --export=CONTAINER_IMAGE="scratch/containers/datasci_containers_4.4.4_osm_tools_ollama.sif" jobs/r-interactive-container.slurm

export HPC_USER=$(whoami)

module purge
module load apptainer
module load cuda

# Inject custom environment variables into the container (even if not built with them)
export APPTAINERENV_PATH="${PATH}:${LSF_BINDIR}:/opt/sw/rev/23.12/linux-scientific7-haswell/gcc-11.4.0/nvhpc-23.9-xliktd/Linux_x86_64/23.9/compilers/bin/"
export APPTAINERENV_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/sw/rev/23.12/linux-scientific7-haswell/gcc-11.4.0/nvhpc-23.9-xliktd/Linux_x86_64/23.9/compilers/lib:/opt/sw/rev/23.12/linux-scientific7-haswell/gcc-11.4.0/nvhpc-23.9-xliktd/Linux_x86_64/23.9/cuda/lib64/"
export APPTAINERENV_CUDA_PATH="/opt/sw/rev/23.12/linux-scientific7-cascadelake/gcc-11.4.0/cuda-12.1.1-s77vqs"
export APPTAINERENV_CUDA_ROOT="/opt/sw/rev/23.12/linux-scientific7-cascadelake/gcc-11.4.0/cuda-12.1.1-s77vqs"

export RLIBS="/scratch-scc/users/${HPC_USER}/_sys/R/pkg/4.4"
if [[ ! -d  $RLIBS ]];then 
    mkdir -p $RLIBS
fi

export PYTHONLIBS="scratch/users/${HPC_USER}/_sys/python/3.10"
if [[ ! -d  $PYTHONLIBS ]];then 
    mkdir -p $PYTHONLIBS
fi

# Define the directory path
WORKDIR_PATH="/scratch-scc/users/${HPC_USER}/_sys/workdir/"

# Check if the directory exists
if [[ ! -d $WORKDIR_PATH ]]; then
    # Create the directory if it does not exist
    mkdir -p $WORKDIR_PATH
fi

# Create unique temporary directories
TMPDIR=$(mktemp -d /scratch-scc/users/${HPC_USER}/_sys/workdir/remote_rpy.XXXXXX)
mkdir -p ${TMPDIR}/run ${TMPDIR}/tmp
echo $PATH
export APPTAINER_PATH=${PATH}
# create run and tmp workdirs
# Consolidated bind mounts (moved from the apptainer exec call)
export APPTAINER_BIND="${TMPDIR}/run:/run,${TMPDIR}/tmp:/tmp,/scratch-scc:/scratch-scc,/local,/user,/projects,/home,/scratch,/mnt,/var/run/munge,/run/munge,/usr/lib64/libmunge.so.2,/usr/lib64/libmunge.so.2.0.0,/usr/local/slurm,/opt/slurm,/sw/viz/jupyterhub-nhr,/sw,/scratch,/scratch-scc,/usr/users,/home,/mnt/vast-nhr,/mnt/vast-orga,/mnt/vast-pools,/mnt/vast-standard,/opt/sw/container/jupyter,/home/uni08/rubsak,/usr/lib64/liblustreapi.so.1,/usr/lib64/liblnetconfig.so.4,/usr/lib64/libgdrapi.so.2"
# export APPTAINER_BIND="${TMPDIR}/run:/run,${TMPDIR}/tmp:/tmp,/scratch-scc:/scratch-scc,/usr/local/slurm:/usr/local/slurm,/opt/slurm/el8/24.11.1/install/lib/slurm:/opt/slurm/el8/24.11.1/install/lib/slurm"

# export APPTAINER_LD_LIBRARY_PATH=/opt/slurm/el8/24.11.1/install/lib/slurm:/usr/local/slurm/current/install/lib:$LD_LIBRARY_PATH

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
export APPTAINERENV_OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}

# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment
export APPTAINERENV_R_LIBS_USER=${RLIBS}
# export APPTAINERENV_PYTHONPATH=/opt/conda/site-packages:${PYTHONLIBS}

export HOSTNAME=$(hostname -s)

### check ports from 9100 to 9200
readonly SSHPORT=${SSHPORT:-$(python -c 'exec("""import socket
def next_free_port( port=9100, max_port=9200 ):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    while port <= max_port:
        try:
            sock.bind(("", port))
            sock.close()
            return(port)
        except:
            port += 1
    raise IOError("no free ports")
print(next_free_port())""")')}


cat 1>&2 <<END
Host: ${HOSTNAME}:${SSHPORT}

For SSH tunnel:

    ssh -N -L ${SSHPORT}:${SLURM_JOB_NODELIST}:${SSHPORT} login-mdc-u14190

To stop the job:

    scancel ${SLURM_JOB_ID}

END

SSHTMPDIR=$(mktemp -d $TMPDIR/tmp/remote_rpy_ssh.XXXXXX)

cat > ${SSHTMPDIR}/sshd_config <<EOL
Port ${SSHPORT}
HostKey ${HOME}/.ssh/id_ecdsa
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile ${HOME}/.ssh/authorized_keys
EOL

cat 1>&2 <<END

Here is the SSH config entry you should add to your ~/.ssh/config file:

Host ${HOSTNAME}_${SSHPORT}
  User ${HPC_USER}
  HostName ${HOSTNAME}
  Port ${SSHPORT}
  IdentityFile ~/.ssh/id_rsa
  ProxyJump ${HPC_USER}@login-mdc.hpc.gwdg.de

END

# Execute the container with Apptainer using the consolidated APPTAINER_BIND mounts.
apptainer exec --nv ${CONTAINER_IMAGE} /usr/sbin/sshd -D -f ${SSHTMPDIR}/sshd_config

printf 'sshd exited' 1>&2
