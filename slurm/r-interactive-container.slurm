#!/bin/bash
#SBATCH --job-name=r-int-c
#SBATCH --partition=jupyter
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=30G
#SBATCH -C scratch
#SBATCH --output=/user/egor.kotov/%u/logs/interactive/r-int-c.job.%j.txt


CONTAINER_IMAGE=${CONTAINER_IMAGE:-${HOME}/jupyterhub-gwdg/jupyter.sif}

# example use to run with custom image
# cd ~
# sbatch --export=CONTAINER_IMAGE="scratch/containers/datasci_containers_4.4.4_osm_tools_ollama.sif" jobs/r-interactive-container.slurm

export HPC_USER=$(whoami)

module purge
module load apptainer


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
export APPTAINER_BIND="${TMPDIR}/run:/run,${TMPDIR}/tmp:/tmp,/scratch-scc:/scratch-scc,/var/run/munge,/run/munge,/usr/lib64/libmunge.so.2,/usr/lib64/libmunge.so.2.0.0,/usr/local/slurm,/opt/slurm"
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

apptainer exec ${CONTAINER_IMAGE} \
    /usr/sbin/sshd -D -f ${SSHTMPDIR}/sshd_config


printf 'sshd exited' 1>&2
