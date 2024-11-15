FROM rocker/geospatial:4.4.2 AS base

# ENV CONDA_DIR=/opt/conda
# ENV PATH=/opt/conda/bin:$PATH
ENV NCPUS=${NCPUS:--1}

RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron.site
RUN echo "export PATH=${PATH}" >> /etc/profile


# Update and install system dependencies
RUN apt-get -y update && apt-get -y install \
    atop \
    bashtop \
    gh \
    git \
    glances \
    gnupg \
    htop \
    lfm \
    libzmq3-dev \
    mc \
    micro \
    nano \
    ncdu \
    nmon \
    openssh-server \
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


# Install Miniforge
# https://github.com/conda-forge/miniforge/releases
# ENV MINIFORGE_VERSION=24.9.2-0
# RUN echo "Installing Miniforge..." \
#     && curl -sSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" > installer.sh \
#     && /bin/bash installer.sh -u -b -p ${CONDA_DIR} \
#     && rm installer.sh \
#     && conda clean -afy \
#     && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
#     && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

# Initialize conda for all users and activate base environment
# RUN conda init bash && \
#     echo "source ${CONDA_DIR}/etc/profile.d/conda.sh" >> /etc/profile.d/conda.sh && \
#     echo "conda activate" >> /etc/profile.d/conda.sh

# Create a consistent path for site-packages
# RUN python_version=$(python -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')") && \
#     ln -s ${CONDA_DIR}/lib/$python_version/site-packages ${CONDA_DIR}/site-packages

# RUN mamba install -y -c conda-forge \
#     ipython \
#     jupyter \
#     jupyter-server-proxy \
#     jupyter-vscode-proxy \
#     jupyterhub-singleuser \
#     jupyterlab \
#     nbgitpuller \
#     radian \
#     retrolab
  
# RUN mamba install -y -c conda-forge \
#     cartopy \
#     datafusion \
#     dask \
#     folium \
#     fiona \
#     geopandas \
#     ibis-datafusion \
#     ibis-duckdb \
#     ibis-pandas \
#     ibis-polars \
#     lightgbm \
#     matplotlib \
#     networkx \
#     numpy=1.26.4 \
#     osmnx \
#     pandas \
#     polars \
#     pyarrow \
#     python-duckdb \
#     pysal \
#     rtree \
#     rasterio \
#     scipy \
#     shapely \
#     spacy \
#     scikit-learn \
#     scikit-mobility \
#     seaborn \
#     umap-learn \
#     xgboost


# RUN find ${CONDA_DIR} -follow -type f -name '*.a' -delete
# RUN find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

# RUN r -e "IRkernel::installspec(prefix='${CONDA_DIR}')"


# Install ark
# https://github.com/posit-dev/ark/releases
# ENV ARK_VERSION=0.1.151
# RUN curl -LO https://github.com/posit-dev/ark/releases/download/${ARK_VERSION}/ark-${ARK_VERSION}-linux-x64.zip && \
#     unzip -j ark-${ARK_VERSION}-linux-x64.zip ark && \
#     mv ark /usr/local/bin/ark && \
#     chmod +x /usr/local/bin/ark && \
#     rm ark-${ARK_VERSION}-linux-x64.zip && \
#     ark --install

# RUN curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz && \
#     tar -xf vscode_cli.tar.gz && \
#     mv code /usr/local/bin/code && \
#     chmod +x /usr/local/bin/code && \
#     rm vscode_cli.tar.gz

# ENV PATH=~/.local/bin:$PATH
ENV SHELL=/bin/bash
# RUN curl -f https://zed.dev/install.sh | sh



# setup slrum
RUN apt-get -y update && apt-get -y install slurm-wlm

RUN addgroup --system --gid 300 slurmadmin && \
    adduser --system --uid 300 --gid 300 --home /opt/slurm/slurm \
    --shell /bin/false slurmadmin

# Stage 2: Use prebuilt OSRM container to get the important binaries
FROM ghcr.io/project-osrm/osrm-backend:v5.27.1 AS osrm

# Final Stage: Create the combined container
FROM base AS final

# Copy only the necessary OSRM components
COPY --from=osrm /usr/local/bin/osrm-extract /usr/local/bin/osrm-extract
COPY --from=osrm /usr/local/bin/osrm-contract /usr/local/bin/osrm-contract
COPY --from=osrm /usr/local/bin/osrm-partition /usr/local/bin/osrm-partition
COPY --from=osrm /usr/local/bin/osrm-customize /usr/local/bin/osrm-customize
COPY --from=osrm /usr/local/bin/osrm-routed /usr/local/bin/osrm-routed

# Optionally, copy the OSRM profiles (if you need to use default profiles)
COPY --from=osrm /opt/ /opt/

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
