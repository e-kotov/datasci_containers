FROM rocker/geospatial:4.3.2


# based on this tutorial https://jupyterhub-image.guide/rocker.html
# Install conda here, to match what repo2docker does
ENV CONDA_DIR=/srv/conda
# ENV CONDA_DIR=/opt/conda

# Add our conda environment to PATH, so python, mamba and other tools are found in $PATH
ENV PATH ${CONDA_DIR}/bin:${PATH}
ENV NCPUS=${NCPUS:--1}

# RStudio doesn't actually inherit the ENV set in Dockerfiles, so we
# have to explicitly set it in Renviron.site
RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron.site

# The terminal inside RStudio doesn't read from Renviron.site, but does read
# from /etc/profile - so we rexport here.
RUN echo "export PATH=${PATH}" >> /etc/profile

RUN apt -y update

RUN apt -y upgrade

RUN apt -y install micro nano htop glances ncdu mc lfm ranger tree libzmq3-dev p7zip-full p7zip-rar gnupg osmium-tool --no-install-recommends

# Install a specific version of Miniforge in ${CONDA_DIR}
# Pick latest version from https://github.com/conda-forge/miniforge/releases
ENV MINIFORGE_VERSION=23.3.1-1
RUN echo "Installing Miniforge..." \
    # && curl -sSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge-${MINIFORGE_VERSION}-Linux-$(uname -m).sh" > installer.sh \
    # && curl -sSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge-${MINIFORGE_VERSION}-Linux-x86_64.sh" > installer.sh \
    && curl -sSL "https://github.com/conda-forge/miniforge/releases/download/23.11.0-0/Miniforge3-23.11.0-0-Linux-x86_64.sh" > installer.sh \
    && /bin/bash installer.sh -u -b -p ${CONDA_DIR} \
    && rm installer.sh \
    && conda clean -afy \
    # After installing the packages, we cleanup some unnecessary files
    # to try reduce image size - see https://jcristharif.com/conda-docker-tips.html
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

RUN mamba install -y -c conda-forge jupyterhub-singleuser jupyter-rsession-proxy nbgitpuller jupyterlab retrolab numpy pandas polars dask pyarrow umap-learn python-duckdb scipy scikit-learn matplotlib seaborn jupyter ipython spacy networkx xgboost lightgbm catboost geopandas fiona shapely pyproj rtree rasterio cartopy folium osmnx scikit-mobility pysal

RUN pip3 install --upgrade jscatter
RUN pip3 install --upgrade "elyra[all]"

RUN find ${CONDA_DIR} -follow -type f -name '*.a' -delete
RUN find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

RUN install2.r --error --skipmissing --skipinstalled -n "$NCPUS" pacman languageserver reticulate IRkernel renv remotes

# RUN R --quiet -e 'remotes::install_github("IRkernel/IRkernel@*release")'
# RUN R --quiet -e 'IRkernel::installspec(user = FALSE)'

RUN install2.r --skipinstalled IRkernel
RUN r -e "IRkernel::installspec(prefix='${CONDA_DIR}')"


RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /tmp/downloaded_packages

## Strip binary installed lybraries from RSPM
## https://github.com/rocker-org/rocker-versioned2/issues/340
RUN strip /usr/local/lib/R/site-library/*/libs/*.so

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

RUN cargo install csvlens

RUN git clone https://github.com/dabreegster/odjitter && cd odjitter && cargo build --release && cp ./target/release/odjitter /usr/local/bin/ && cd .. && rm -rf odjitter

# Explicitly specify working directory, so Jupyter knows where to start
WORKDIR /home/rstudio

ENV SHELL=/bin/bash

