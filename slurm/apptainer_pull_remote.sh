#!/bin/bash
#SBATCH --job-name=apptainer-from-remote
#SBATCH --partition=medium
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH -C scratch
#SBATCH --output=/usr/users/%u/job_logs/apptainer-from-remote.%j.txt

if [ $# -eq 0 ]; then
    echo "No definition file path provided. Exiting."
    exit 1
fi

# first argument is the path to save the resulting sif (singularity/apptainer container image) file
# for example: ~/scratch/containers/my_container.sif
SIF_FILE_PATH=$1

# second argument is the remote image name including protocol
# example 1 (Docker Hub path): docker://rocker/rstudio:4.4.0
# example 2 (GitHub Container Registry path): docker://ghcr.io/rocker/rstudio:4.4.0
REMOTE_IMAGE=$2

module purge
module load apptainer

apptainer pull "${SIF_FILE_PATH}" "${REMOTE_IMAGE}"

# Example usage:
# sbatch apptainer_pull_remote.sh ~/scratch/containers/my_container.sif docker://rocker/rstudio:4.4.0