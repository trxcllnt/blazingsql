ARG CUDA_VERSION=11.2.2
ARG UBUNTU_VERSION=20.04
ARG INSTALL_PREFIX=/usr/local

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} as blazingsql-build
LABEL Description="blazingdb/blazingsql is the official BlazingDB environment for BlazingSQL on NIVIDA RAPIDS." Vendor="BlazingSQL" Version="0.4.0"

ARG INSTALL_PREFIX
ARG GCC_VERSION=9
ARG PYTHON_VERSION=3.8
ARG CMAKE_VERSION=3.20.2

SHELL ["/bin/bash", "-c"]

RUN export CUDA_HOME=/usr/local/cuda \
 && export PATH="$PATH:$CUDA_HOME/bin" \
 && export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CUDA_HOME/lib:$CUDA_HOME/lib64" \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
    apt-utils apt-transport-https software-properties-common \
 # Get the good git
 && add-apt-repository -y ppa:git-core/ppa \
 # Get the good Python
 && add-apt-repository -y ppa:deadsnakes/ppa \
 # Needed to install compatible gcc 9 toolchain
 && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
 && apt update --fix-missing \
 && apt install -y --no-install-recommends \
      git \
      curl \
      wget \
      libcurl4-openssl-dev libssl-dev \
      ninja-build \
      build-essential \
      protobuf-compiler \
      {gcc,g++}-${GCC_VERSION} \
      python{$PYTHON_VERSION,$PYTHON_VERSION-dev,$PYTHON_VERSION-distutils} \
      libboost-{regex,system,filesystem}-dev \
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
 && python get-pip.py --prefix="$INSTALL_PREFIX" \
 && rm get-pip.py \
 # Install cmake
 && wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz \
 && tar -xvzf cmake-${CMAKE_VERSION}.tar.gz && cd cmake-${CMAKE_VERSION} \
 && ./bootstrap --parallel=$(nproc) && make install -j \
 && cd - && rm -rf ./cmake-${CMAKE_VERSION} ./cmake-${CMAKE_VERSION}.tar.gz \
 # Install UCX
 && git clone --depth 1 --branch v1.9.x https://github.com/openucx/ucx.git /tmp/ucx \
 && curl -o /tmp/cuda-alloc-rcache.patch \
         -L https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/11ad7a3c1f25514df8064930f69c310be4fd55dc/recipe/cuda-alloc-rcache.patch \
 && cd /tmp/ucx && git apply /tmp/cuda-alloc-rcache.patch && rm /tmp/cuda-alloc-rcache.patch \
 && /tmp/ucx/autogen.sh && mkdir /tmp/ucx/build && cd /tmp/ucx/build \
 && ../contrib/configure-release --prefix="$INSTALL_PREFIX" --with-cuda="$CUDA_HOME" --enable-mt CPPFLAGS="-I/$CUDA_HOME/include" \
 && make -C /tmp/ucx/build -j install && cd /

ENV CC="/usr/bin/gcc"
ENV CXX="/usr/bin/g++"
ENV CUDA_HOME=/usr/local/cuda
ENV PYTHONDONTWRITEBYTECODE=true
ENV PATH="$PATH:$CUDA_HOME/bin:$INSTALL_PREFIX/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$INSTALL_PREFIX/lib/python3.8/dist-packages"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CUDA_HOME/lib:$CUDA_HOME/lib64:$INSTALL_PREFIX/lib"

# Build and install numpy, blazingsql-io, libarrow, blazingsql-engine, and libcudf from source
RUN pip install --upgrade numpy \
 && git clone --depth 1 --branch fea/rapids-cmake https://github.com/trxcllnt/blazingsql.git /repos/blazingsql \
 \
 && cmake -GNinja \
    -S /repos/blazingsql/io \
    -B /repos/blazingsql/io/build \
    -DGCS_SUPPORT=OFF -DS3_SUPPORT=OFF \
 && cmake --build /repos/blazingsql/io/build \
 && cmake --build /repos/blazingsql/io/build -j$(nproc) -v --target install \
 \
 && cmake -GNinja \
    -S /repos/blazingsql/engine \
    -B /repos/blazingsql/engine/build \
    -D DISABLE_DEPRECATION_WARNING=ON \
    -D BUILD_TESTS=OFF \
    -D BUILD_BENCHMARKS=OFF \
    -D S3_SUPPORT=OFF \
    -D GCS_SUPPORT=OFF \
    -D MYSQL_SUPPORT=OFF \
    -D SQLITE_SUPPORT=OFF \
    -D POSTGRESQL_SUPPORT=OFF \
 && cmake --build /repos/blazingsql/engine/build \
 && cmake --build /repos/blazingsql/engine/build -j$(nproc) -v --target install

# Build and install pyblazing, pyarrow, rmm, and cudf
RUN cd /repos/blazingsql/pyblazing \
 && pip install --upgrade -r requirements_dev.txt \
    --target "$INSTALL_PREFIX/lib/python3.8/dist-packages" \
 && env PARALLEL_LEVEL=$(nproc) \
    python setup.py build_ext -j$(nproc) --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && cd / && rm -rf /repos/blazingsql \
 \
 && git clone --depth 1 --branch branch-21.08 https://github.com/rapidsai/rmm.git /repos/rmm \
 && cd /repos/rmm/python \
 && pip install --upgrade -r dev_requirements.txt \
    --target "$INSTALL_PREFIX/lib/python3.8/dist-packages" \
 && env PARALLEL_LEVEL=$(nproc) \
    python setup.py build_ext -j$(nproc) --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && cd / && rm -rf /repos/rmm \
 \
 && git clone --depth 1 --branch apache-arrow-1.0.1 https://github.com/apache/arrow.git /repos/arrow \
 && cd /repos/arrow/python \
 && export ARROW_HOME="$INSTALL_PREFIX" \
 && env PARALLEL_LEVEL=$(nproc) \
        PYARROW_PARALLEL=$(nproc) \
        PYARROW_BUILD_TYPE=Release \
        PYARROW_CMAKE_GENERATOR=Ninja \
    python setup.py build_ext -j$(nproc) --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && cd / && rm -rf /repos/arrow \
 \
 && git clone --depth 1 --branch branch-21.08 https://github.com/rapidsai/cudf.git /repos/cudf \
 && cd /repos/cudf/python/cudf \
 && pip install --upgrade \
    -r requirements/cuda-11.2/dev_requirements.txt \
    --target "$INSTALL_PREFIX/lib/python3.8/dist-packages" \
 && env PARALLEL_LEVEL=$(nproc) \
    python setup.py build_ext -j$(nproc) --inplace \
 && python setup.py install --single-version-externally-managed --record=record.txt \
 && cd / && rm -rf /repos/cudf


FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}
LABEL Description="blazingdb/blazingsql is the official BlazingDB environment for BlazingSQL on NIVIDA RAPIDS." Vendor="BlazingSQL" Version="0.4.0"

SHELL ["/bin/bash", "-c"]

ARG INSTALL_PREFIX
ENV INSTALL_PREFIX="$INSTALL_PREFIX"

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
 # Set python3.8 as the default python
 && update-alternatives --install /usr/bin/python python $(realpath $(which python3.8)) 1 \
 && update-alternatives --set python $(realpath $(which python3.8)) \
 # Install pip
 && wget https://bootstrap.pypa.io/get-pip.py \
 && python get-pip.py --prefix="$INSTALL_PREFIX" \
 && rm get-pip.py \
 && add-apt-repository --remove -y ppa:deadsnakes/ppa \
 && apt remove -y \
    wget apt-utils apt-transport-https software-properties-common \
 && apt autoremove -y && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=blazingsql-build /usr/local/lib /usr/local/lib
COPY --from=blazingsql-build /usr/local/include /usr/local/include

ENV CUDA_HOME=/usr/local/cuda
ENV PATH="$PATH:$CUDA_HOME/bin:/usr/local/bin"
ENV PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$INSTALL_PREFIX/lib/python3.8/dist-packages"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CUDA_HOME/lib:$CUDA_HOME/lib64:$INSTALL_PREFIX/lib"

WORKDIR /

CMD ["python"]
