ARG PYTHON_VERSION=3.8
ARG CUDA_VERSION=11.2.2
ARG UBUNTU_VERSION=20.04

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} as blazingsql-build

ARG PYTHON_VERSION

ARG GCC_VERSION=9
ARG SCCACHE_VERSION=0.2.15

SHELL ["/bin/bash", "-c"]

RUN export CUDA_HOME=/usr/local/cuda \
 && export PATH="${PATH:+$PATH:}${CUDA_HOME}/bin" \
 && export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${CUDA_HOME}/lib:${CUDA_HOME}/lib64" \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
    wget gpg apt-utils apt-transport-https software-properties-common \
 # Get the good git
 && add-apt-repository -y ppa:git-core/ppa \
 # Get the good Python
 && add-apt-repository -y ppa:deadsnakes/ppa \
 # Needed to install compatible gcc 9 toolchain
 && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
 # Install kitware CMake apt sources
 && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
  | gpg --dearmor - \
  | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null \
 && bash -c 'echo -e "\
deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main\n\
" | tee /etc/apt/sources.list.d/kitware.list >/dev/null' \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
      git ninja-build \
      {gcc,g++}-${GCC_VERSION} \
      build-essential protobuf-compiler \
      libboost-{regex,system,filesystem}-dev \
      cmake curl libssl-dev libcurl4-openssl-dev zlib1g-dev \
      python{$PYTHON_VERSION,$PYTHON_VERSION-dev,$PYTHON_VERSION-distutils} \
      unzip automake autoconf libb2-dev libzstd-dev \
      libtool libibverbs-dev librdmacm-dev libnuma-dev libhwloc-dev \
 && bash -c "echo -e '\
deb http://archive.ubuntu.com/ubuntu/ xenial universe\n\
deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe\
'" >> /etc/apt/sources.list.d/xenial.list \
 && apt update -y || true && apt install -y libibcm-dev \
 && rm /etc/apt/sources.list.d/xenial.list \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && update-alternatives --remove-all cc     >/dev/null 2>&1 || true \
 && update-alternatives --remove-all c++    >/dev/null 2>&1 || true \
 && update-alternatives --remove-all gcc    >/dev/null 2>&1 || true \
 && update-alternatives --remove-all g++    >/dev/null 2>&1 || true \
 && update-alternatives --remove-all gcov   >/dev/null 2>&1 || true \
 && update-alternatives --remove-all python >/dev/null 2>&1 || true \
 && update-alternatives \
    --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 1 \
    --slave /usr/bin/cc cc /usr/bin/gcc-${GCC_VERSION} \
    --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} \
    --slave /usr/bin/c++ c++ /usr/bin/g++-${GCC_VERSION} \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-${GCC_VERSION} \
 && update-alternatives --set gcc /usr/bin/gcc-${GCC_VERSION} \
 && export CC="/usr/bin/gcc" \
 && export CXX="/usr/bin/g++" \
 && update-alternatives --install /usr/bin/python python $(realpath $(which python${PYTHON_VERSION})) 1 \
 && update-alternatives --set python $(realpath $(which python${PYTHON_VERSION})) \
 # Install pip
 && wget https://bootstrap.pypa.io/get-pip.py \
 && python get-pip.py --prefix=/usr/local \
 && rm get-pip.py \
 # Install sccache
 && curl -o /tmp/sccache.tar.gz \
         -L "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" \
 && tar -C /tmp -xvf /tmp/sccache.tar.gz \
 && mv "/tmp/sccache-v${SCCACHE_VERSION}-$(uname -m)-unknown-linux-musl/sccache" /usr/bin/sccache \
 && chmod +x /usr/bin/sccache \
 # Scripts to symlink/unlink sccache -> gcc because Cython doesn't support compiler launchers
 && bash -c 'echo -e "#!/bin/bash -e\n\
exec /usr/bin/sccache /usr/bin/gcc \$*" | tee /usr/bin/sccache-gcc >/dev/null' \
 && chmod +x /usr/bin/sccache-gcc \
 && bash -c 'echo -e "#!/bin/bash -e\n\
ln -s /usr/bin/sccache-gcc /usr/local/bin/gcc" | tee /usr/bin/link-sccache >/dev/null' \
 && chmod +x /usr/bin/link-sccache \
 && bash -c 'echo -e "#!/bin/bash -e\n\
rm /usr/local/bin/gcc >/dev/null 2>&1 || true" | tee /usr/bin/unlink-sccache >/dev/null' \
 && chmod +x /usr/bin/unlink-sccache \
 # Install UCX
 && git clone --depth 1 --branch v1.9.x https://github.com/openucx/ucx.git /opt/ucx \
 && cd  /opt/ucx \
 && curl -LO https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/11ad7a3c1f25514df8064930f69c310be4fd55dc/recipe/cuda-alloc-rcache.patch \
 && git apply cuda-alloc-rcache.patch \
 && sed -i 's/io_demo_LDADD =/io_demo_LDADD = $(CUDA_LDFLAGS)/' test/apps/iodemo/Makefile.am \
 && ./autogen.sh && mkdir build && cd build \
 && ../contrib/configure-release --prefix=/usr/local --with-cuda="$CUDA_HOME" --enable-mt CPPFLAGS="-I/$CUDA_HOME/include" \
 && make -j install \
 && cd / && rm -rf /opt/ucx

ENV CC="/usr/bin/gcc"
ENV CXX="/usr/bin/g++"
ENV CUDA_HOME=/usr/local/cuda
ENV PYTHONDONTWRITEBYTECODE=true
ENV PATH="${PATH:+$PATH:}${CUDA_HOME}/bin:/usr/local/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}/usr/local/lib/python${PYTHON_VERSION}/dist-packages"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${CUDA_HOME}/lib:${CUDA_HOME}/lib64:/usr/local/lib"

ARG SCCACHE_REGION
ARG SCCACHE_BUCKET
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG SCCACHE_CACHE_SIZE=100G
ARG SCCACHE_IDLE_TIMEOUT=32768

ARG PARALLEL_LEVEL=4
ARG CMAKE_CUDA_ARCHITECTURES=ALL

COPY . /opt/blazingsql

ARG CUDF_BRANCH=branch-21.08
ARG CUDF_GIT_REPO="https://github.com/rapidsai/cudf.git"

# Build and install libarrow and libcudf
RUN pip install --upgrade \
    "cython>=0.29,<0.30" \
    "nvtx>=0.2.1" \
    "numba>=0.53.1" \
    "fsspec>=0.6.0" \
    "fastavro>=0.22.9" \
    "transformers>=4.8" \
    "pandas>=1.0,<1.3.0dev0" \
    "cmake-setuptools>=0.1.3" \
    "cupy-cuda112>7.1.0,<10.0.0a0" \
    "git+https://github.com/dask/dask.git@main" \
    "git+https://github.com/dask/distributed.git@main" \
    "git+https://github.com/rapidsai/dask-cuda.git@branch-21.08" \
 \
 && export SCCACHE_REGION="${SCCACHE_REGION}" \
 && export SCCACHE_BUCKET="${SCCACHE_BUCKET}" \
 && export SCCACHE_IDLE_TIMEOUT="${SCCACHE_IDLE_TIMEOUT}" \
 && export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
 && export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
 && git clone --depth 1 --branch "$CUDF_BRANCH" "$CUDF_GIT_REPO" /opt/rapids/cudf \
 \
 && cmake \
    -S /opt/rapids/cudf/cpp \
    -B /opt/rapids/cudf/cpp/build \
    -D BUILD_TESTS=OFF \
    -D BUILD_BENCHMARKS=OFF \
    -D CUDF_ENABLE_ARROW_S3=OFF \
    -D CUDF_ENABLE_ARROW_PYTHON=ON \
    -D CUDF_ENABLE_ARROW_PARQUET=ON \
    -D DISABLE_DEPRECATION_WARNING=ON \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-}" \
 && cmake --build /opt/rapids/cudf/cpp/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install rmm
 && cd /opt/rapids/cudf/cpp/build/_deps/rmm-src/python \
 && link-sccache \
 && PARALLEL_LEVEL=${PARALLEL_LEVEL} python setup.py build_ext -j${PARALLEL_LEVEL} --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && unlink-sccache \
 \
 # Build and install pyarrow
 && cd /opt/rapids/cudf/cpp/build/_deps/arrow-src/python \
 && link-sccache \
 && env ARROW_HOME=/usr/local \
        PYARROW_WITH_S3=OFF \
        PYARROW_WITH_ORC=OFF \
        PYARROW_WITH_CUDA=ON \
        PYARROW_WITH_HDFS=OFF \
        PYARROW_WITH_FLIGHT=OFF \
        PYARROW_WITH_PLASMA=OFF \
        PYARROW_WITH_DATASET=ON \
        PYARROW_WITH_GANDIVA=OFF \
        PYARROW_WITH_PARQUET=ON \
        PYARROW_BUILD_TYPE=Release \
        PYARROW_CMAKE_GENERATOR=Ninja \
        PYARROW_PARALLEL=${PARALLEL_LEVEL} \
    python setup.py install --single-version-externally-managed --record=record.txt \
 && unlink-sccache \
 \
 # Build and install cudf
 && cp -R /opt/rapids/cudf/cpp/build/_deps/dlpack-src/include/dlpack /usr/local/include/dlpack \
 && ln -s /usr/local/include/dlpack /usr/include/dlpack \
 && ln -s /usr/local/include/libcudf /usr/include/libcudf \
 && cd /opt/rapids/cudf/python/cudf \
 && link-sccache \
 && PARALLEL_LEVEL=${PARALLEL_LEVEL} python setup.py build_ext -j${PARALLEL_LEVEL} --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && unlink-sccache \
 \
 # Build and install dask_cudf
 && cd /opt/rapids/cudf/python/dask_cudf \
 && link-sccache \
 && PARALLEL_LEVEL=${PARALLEL_LEVEL} python setup.py build_ext -j${PARALLEL_LEVEL} --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && unlink-sccache \
 \
 # Build and install blazingsql-io
 && cmake -GNinja \
    -S /opt/blazingsql/io \
    -B /opt/blazingsql/io/build \
    -D S3_SUPPORT=OFF \
    -D GCS_SUPPORT=OFF \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-}" \
 && cmake --build /opt/blazingsql/io/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install blazingsql-engine
 && cmake -GNinja \
    -S /opt/blazingsql/engine \
    -B /opt/blazingsql/engine/build \
    -D BUILD_TESTS=OFF \
    -D BUILD_BENCHMARKS=OFF \
    -D S3_SUPPORT=OFF \
    -D GCS_SUPPORT=OFF \
    -D MYSQL_SUPPORT=OFF \
    -D SQLITE_SUPPORT=OFF \
    -D POSTGRESQL_SUPPORT=OFF \
    -D DISABLE_DEPRECATION_WARNING=ON \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-}" \
 && cmake --build /opt/blazingsql/engine/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install pyblazing
 && cd /opt/blazingsql/pyblazing \
 && link-sccache \
 && PARALLEL_LEVEL=${PARALLEL_LEVEL} python setup.py build_ext --inplace -j${PARALLEL_LEVEL} \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && unlink-sccache


FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}
LABEL Description="blazingdb/blazingsql is the official BlazingDB environment for BlazingSQL on NIVIDA RAPIDS." Vendor="BlazingSQL" Version="0.4.0"

SHELL ["/bin/bash", "-c"]

ARG PYTHON_VERSION=3.8

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
    apt-utils apt-transport-https software-properties-common \
 # Get the good Python
 && add-apt-repository -y ppa:deadsnakes/ppa \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
      wget \
      curl libssl-dev \
      python{3.8,3.8-distutils} \
      libboost-{regex,system,filesystem}-dev \
      libb2-dev libzstd-dev libibverbs-dev librdmacm-dev libnuma-dev libhwloc-dev \
 && update-alternatives --remove-all python >/dev/null 2>&1 || true \
 # Set python${PYTHON_VERSION} as the default python
 && update-alternatives --install /usr/bin/python python $(realpath $(which python${PYTHON_VERSION})) 1 \
 && update-alternatives --set python $(realpath $(which python${PYTHON_VERSION})) \
 # Install pip
 && wget https://bootstrap.pypa.io/get-pip.py \
 && python get-pip.py --prefix=/usr/local \
 && rm get-pip.py \
 && add-apt-repository --remove -y ppa:deadsnakes/ppa \
 && apt remove -y \
    wget apt-utils apt-transport-https software-properties-common \
 # Clean up
 && apt autoremove -y && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=blazingsql-build /usr/local/lib /usr/local/lib
COPY --from=blazingsql-build /usr/local/include /usr/local/include

ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${PATH:+$PATH:}${CUDA_HOME}/bin:/usr/local/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}/usr/local/lib/python${PYTHON_VERSION}/dist-packages"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${CUDA_HOME}/lib:${CUDA_HOME}/lib64:/usr/local/lib"

WORKDIR /

CMD ["python"]
