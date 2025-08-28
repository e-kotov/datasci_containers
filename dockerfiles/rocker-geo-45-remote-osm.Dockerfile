FROM ghcr.io/rocker-org/geospatial:4.5 AS base

LABEL org.opencontainers.image.source="https://github.com/e-kotov/datasci_containers"

ARG NCPUS=-1
ENV NCPUS=${NCPUS}


# Update and install system dependencies
RUN apt-get -y update && apt-get -y install \
    atop \
    bashtop \
    fish \
    gh \
    git \
    glances \
    gnupg \
    htop \
    lfm \
    libzmq3-dev \
    # libsecret-1-dev is for keyring r package
    libsecret-1-dev \
    mc \
    micro \
    nano \
    ncdu \
    nmon \
    openssh-server \
    openssh-client \
    dialog \
    osmium-tool \
    p7zip-full \
    p7zip-rar \
    python3 \
    python3-pip \
    ranger \
    screen \
    # tmux \
    tree \
    xdg-utils \
    --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# Install R packages
RUN install2.r --error --skipmissing -n "$NCPUS" \
    usethis \
    devtools \
    httpgd \
    IRkernel \
    languageserver \
    pak \
    targets \
    remotes \
    renv \
    reticulate && \
    rm -rf /var/lib/apt/lists/* /tmp/downloaded_packages



ENV SHELL=/bin/bash


# setup slrum
# add SLURM support for GWDG HPC
RUN addgroup --system --gid 450 slurm
RUN adduser --system --uid 450 --gid 450 --home /var/lib/slurm slurm
# bind mounts for slurm commands to work from inside the container
# /var/run/munge,/run/munge,/usr/lib64/libmunge.so.2,/usr/lib64/libmunge.so.2.0.0,/usr/local/slurm,/opt/slurm
# see https://docs.hpc.gwdg.de/software_stacks/list_of_modules/apptainer/index.html


# Stage 2: Use prebuilt OSRM container to get the important binaries
FROM ghcr.io/project-osrm/osrm-backend:v5.27.1 AS osrm

# Final Stage: Create the combined container
FROM base AS final

# Copy only the necessary OSRM components
# COPY --from=osrm /usr/local/bin/osrm-extract /usr/local/bin/osrm-extract
# COPY --from=osrm /usr/local/bin/osrm-contract /usr/local/bin/osrm-contract
# COPY --from=osrm /usr/local/bin/osrm-partition /usr/local/bin/osrm-partition
# COPY --from=osrm /usr/local/bin/osrm-customize /usr/local/bin/osrm-customize
# COPY --from=osrm /usr/local/bin/osrm-routed /usr/local/bin/osrm-routed

# Optionally, copy the OSRM profiles (if you need to use default profiles)
COPY --from=osrm /opt /opt
COPY --from=osrm /usr/local /usr/local
# COPY --from=osrm /usr/lib/lua /usr/local


# Copy the Boost shared libraries that are needed
# Copy the specific Boost libraries required by OSRM
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_filesystem.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_program_options.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_thread.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_iostreams.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_date_time.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_regex.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_chrono.so.1.74.0 /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost_system.so.1.74.0 /usr/lib/x86_64-linux-gnu/

# (Optional) Copy other dependencies that may be needed for OSRM to run properly
COPY --from=osrm /usr/local/lib/libtbb.so.12 /usr/local/lib/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/liblua5.4.so.0 /usr/lib/x86_64-linux-gnu/

# Update library path to ensure copied libraries can be found
RUN ldconfig /usr/local/lib

# Install any additional dependencies for running OSRM on Ubuntu 22
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libexpat1 \
        libbz2-1.0 && \
    rm -rf /var/lib/apt/lists/*

# Install liblua for slurm
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        liblua5.3 && \
    rm -rf /var/lib/apt/lists/*
