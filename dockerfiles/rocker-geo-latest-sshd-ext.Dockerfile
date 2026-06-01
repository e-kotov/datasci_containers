FROM ghcr.io/rocker-org/geospatial:latest

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


# Install any additional dependencies for liblua for slurm,
# and system dependencies for Playwright/Chromium (Ubuntu 24.04)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libexpat1 \
        libbz2-1.0 \
        liblua5.3 \
        libasound2t64 \
        libatk1.0-0t64 \
        libatk-bridge2.0-0t64 \
        libcairo2 \
        libcups2t64 \
        libdbus-1-3 \
        libfontconfig1 \
        libgbm1 \
        libgcc-s1 \
        libgdk-pixbuf-2.0-0 \
        libglib2.0-0t64 \
        libgtk-3-0t64 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libstdc++6 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxkbcommon0 \
        libxrandr2 \
        libxrender1 \
        libxshmfence1 \
        libxtst6 && \
    rm -rf /var/lib/apt/lists/*

# USER your_user_name
