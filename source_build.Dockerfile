ARG PYTHON_VERSION=3.8
ARG CUDA_VERSION=11.2.2
ARG UBUNTU_VERSION=20.04
ARG INSTALL_PREFIX=/usr/local

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} as blazingsql-build

ARG GCC_VERSION=9
ARG SCCACHE_VERSION=0.2.15

ARG PYTHON_VERSION
ARG INSTALL_PREFIX

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
 && python get-pip.py --prefix="${INSTALL_PREFIX}" \
 && rm get-pip.py \
 # Install sccache
 && curl -o /tmp/sccache.tar.gz \
         -L "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" \
 && tar -C /tmp -xvf /tmp/sccache.tar.gz \
 && mv "/tmp/sccache-v${SCCACHE_VERSION}-$(uname -m)-unknown-linux-musl/sccache" /usr/bin/sccache \
 && chmod +x /usr/bin/sccache \
 # Install UCX
 && git clone --depth 1 --branch v1.9.x https://github.com/openucx/ucx.git /tmp/ucx \
 && curl -o /tmp/cuda-alloc-rcache.patch \
         -L https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/11ad7a3c1f25514df8064930f69c310be4fd55dc/recipe/cuda-alloc-rcache.patch \
 && cd /tmp/ucx && git apply /tmp/cuda-alloc-rcache.patch && rm /tmp/cuda-alloc-rcache.patch \
 && /tmp/ucx/autogen.sh && mkdir /tmp/ucx/build && cd /tmp/ucx/build \
 && ../contrib/configure-release --prefix="${INSTALL_PREFIX}" --with-cuda="${CUDA_HOME}" --enable-mt CPPFLAGS="-I/${CUDA_HOME}/include" \
 && make -C /tmp/ucx/build -j install && cd /

ENV CC="/usr/bin/gcc"
ENV CXX="/usr/bin/g++"
ENV CUDA_HOME=/usr/local/cuda
ENV PYTHONDONTWRITEBYTECODE=true
ENV PATH="${PATH:+$PATH:}${CUDA_HOME}/bin:${INSTALL_PREFIX}/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}${INSTALL_PREFIX}/lib/python${PYTHON_VERSION}/dist-packages"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${CUDA_HOME}/lib:${CUDA_HOME}/lib64:${INSTALL_PREFIX}/lib"

ARG SCCACHE_REGION
ARG SCCACHE_BUCKET
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG SCCACHE_CACHE_SIZE=100G
ARG SCCACHE_IDLE_TIMEOUT=32768

ARG PARALLEL_LEVEL=4
ARG CMAKE_CUDA_ARCHITECTURES=ALL

COPY . /opt/blazingsql

# Build and install blazingsql-io, libarrow, blazingsql-engine, and libcudf from source
RUN export SCCACHE_REGION="${SCCACHE_REGION}" \
 && export SCCACHE_BUCKET="${SCCACHE_BUCKET}" \
 && export SCCACHE_IDLE_TIMEOUT="${SCCACHE_IDLE_TIMEOUT}" \
 && export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
 && export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
 && pip install --upgrade numpy \
 \
 && cmake -GNinja \
    -S /opt/blazingsql/io \
    -B /opt/blazingsql/io/build \
    -D S3_SUPPORT=OFF \
    -D GCS_SUPPORT=OFF \
    -D CMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-}" \
 && cmake --build /opt/blazingsql/io/build -j${PARALLEL_LEVEL} -v --target install \
 \
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
    -D CMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
    -D CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-}" \
 && cmake --build /opt/blazingsql/engine/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install pyblazing, pyarrow, rmm, and cudf
 && export PYBLAZING_PYTHON_DIR=/opt/blazingsql/pyblazing \
 && cd "$PYBLAZING_PYTHON_DIR" && pip install --upgrade -r requirements_dev.txt --target "${INSTALL_PREFIX}/lib/python${PYTHON_VERSION}/dist-packages" \
 && cd "$PYBLAZING_PYTHON_DIR" && python setup.py build_ext --inplace -j${PARALLEL_LEVEL} \
 && cd "$PYBLAZING_PYTHON_DIR" && python setup.py install --single-version-externally-managed --record=record.txt \
 \
 && export RMM_PYTHON_DIR=/opt/blazingsql/engine/build/_deps/rmm-src/python \
 && cd "$RMM_PYTHON_DIR" && pip install --upgrade -r dev_requirements.txt --target "${INSTALL_PREFIX}/lib/python${PYTHON_VERSION}/dist-packages" \
 && cd "$RMM_PYTHON_DIR" && python setup.py build_ext --inplace -j${PARALLEL_LEVEL} \
 && cd "$RMM_PYTHON_DIR" && python setup.py install --single-version-externally-managed --record=record.txt \
 \
 && export ARROW_HOME="${INSTALL_PREFIX}" \
 && export PYARROW_WITH_S3=OFF \
 && export PYARROW_WITH_ORC=ON \
 && export PYARROW_WITH_CUDA=ON \
 && export PYARROW_WITH_HDFS=OFF \
 && export PYARROW_WITH_FLIGHT=OFF \
 && export PYARROW_WITH_PLASMA=OFF \
 && export PYARROW_WITH_DATASET=ON \
 && export PYARROW_WITH_GANDIVA=OFF \
 && export PYARROW_WITH_PARQUET=ON \
 && export PYARROW_BUILD_TYPE=Release \
 && export PYARROW_CMAKE_GENERATOR=Ninja \
 && export PYARROW_PARALLEL=${PARALLEL_LEVEL} \
 && export ARROW_PYTHON_DIR=/opt/blazingsql/io/build/_deps/arrow-src/python \
 && cd "$ARROW_PYTHON_DIR" && python setup.py build_ext --inplace -j${PARALLEL_LEVEL} \
 && cd "$ARROW_PYTHON_DIR" && python setup.py install --single-version-externally-managed --record=record.txt \
 \
 && cp -R /opt/blazingsql/engine/build/_deps/dlpack-src/include/dlpack "${INSTALL_PREFIX}/include/dlpack" \
 && ln -s "${INSTALL_PREFIX}/include/dlpack" /usr/include/dlpack \
 && ln -s "${INSTALL_PREFIX}/include/libcudf" /usr/include/libcudf \
 && export CUDF_PYTHON_DIR=/opt/blazingsql/engine/build/_deps/cudf-src/python/cudf \
 && cd "$CUDF_PYTHON_DIR" && pip install --upgrade -r requirements/cuda-11.2/dev_requirements.txt --target "${INSTALL_PREFIX}/lib/python${PYTHON_VERSION}/dist-packages" \
 && cd "$CUDF_PYTHON_DIR" && python setup.py build_ext --inplace -j${PARALLEL_LEVEL} \
 && cd "$CUDF_PYTHON_DIR" && python setup.py install --single-version-externally-managed --record=record.txt


FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}
LABEL Description="blazingdb/blazingsql is the official BlazingDB environment for BlazingSQL on NIVIDA RAPIDS." Vendor="BlazingSQL" Version="0.4.0"

SHELL ["/bin/bash", "-c"]

ARG INSTALL_PREFIX
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
 && apt autoremove -y && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && update-alternatives --remove-all python >/dev/null 2>&1 || true \
 # Set python${PYTHON_VERSION} as the default python
 && update-alternatives --install /usr/bin/python python $(realpath $(which python${PYTHON_VERSION})) 1 \
 && update-alternatives --set python $(realpath $(which python${PYTHON_VERSION})) \
 # Install pip
 && wget https://bootstrap.pypa.io/get-pip.py \
 && python get-pip.py --prefix="${INSTALL_PREFIX}" \
 && rm get-pip.py \
 && add-apt-repository --remove -y ppa:deadsnakes/ppa \
 && apt remove -y \
    wget apt-utils apt-transport-https software-properties-common \
 && apt autoremove -y && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=blazingsql-build /usr/local/lib /usr/local/lib
COPY --from=blazingsql-build /usr/local/include /usr/local/include

ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${PATH:+$PATH:}${CUDA_HOME}/bin:${INSTALL_PREFIX}/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}${INSTALL_PREFIX}/lib/python${PYTHON_VERSION}/dist-packages"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${CUDA_HOME}/lib:${CUDA_HOME}/lib64:${INSTALL_PREFIX}/lib"

WORKDIR /

CMD ["python"]
