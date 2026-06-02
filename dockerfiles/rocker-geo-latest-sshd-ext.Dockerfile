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
    # ADD DROPBEAR - lightweight SSH server that works without root
    dropbear \
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


# Install system dependencies for Playwright/Chromium and R packages (renv/PPM)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # build tools
        cmake \
        make \
        g++ \
        # core system deps
        ca-certificates \
        curl \
        wget \
        git \
        # R / Geospatial / PPM dependencies
        default-jdk \
        gdal-bin \
        libabsl-dev \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libgdal-dev \
        libgeos-dev \
        libglpk-dev \
        libicu-dev \
        libnode-dev \
        libpng-dev \
        libproj-dev \
        libsqlite3-dev \
        libssl-dev \
        libudunits2-dev \
        libuv1-dev \
        libx11-dev \
        libxml2-dev \
        libzstd-dev \
        pandoc \
        xz-utils \
        zlib1g-dev \
        # Playwright / Chromium system dependencies (Ubuntu generic names)
        libasound2 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libexpat1 \
        libfontconfig1 \
        libgbm1 \
        libgcc-s1 \
        libgdk-pixbuf-2.0-0 \
        libglib2.0-0 \
        libgtk-3-0 \
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
        libxtst6 \
        # other utilities
        libbz2-1.0 \
        liblua5.3 && \
    rm -rf /var/lib/apt/lists/*

USER rstudio
