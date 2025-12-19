FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update --fix-missing && apt-get -y upgrade

# Install build dependencies
RUN apt-get -y install git wget cmake xz-utils libz-dev build-essential pkg-config ca-certificates && rm -rf /var/lib/apt/lists/*

# Build openssl-3.4.0
RUN cd /tmp && wget -q https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz && tar xzf openssl-3.4.0.tar.gz && rm openssl-3.4.0.tar.gz
RUN cd /tmp/openssl-3.4.0 && ./config && make -j$(nproc) && make install_sw

# Rebuild cmake from source (as in upstream script)
RUN apt-get -y remove cmake || true && cd /tmp && wget -q https://cmake.org/files/v3.30/cmake-3.30.0.tar.gz && tar -xzf cmake-3.30.0.tar.gz \
    && cd cmake-3.30.0 && ./bootstrap && make -j$(nproc) && make install && rm -rf /tmp/cmake-3.30.0* \
    && rm -rf /var/lib/apt/lists/*

# Build libsrtp 2.6.0
RUN cd /tmp \
    && git clone https://github.com/cisco/libsrtp \
    && cd /tmp/libsrtp \
    && git checkout v2.6.0 \
    && PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig ./configure --enable-openssl \
    && make -j$(nproc) \
    && make install

# Install or unpack clang/llvm (use upstream packaged tarball)
RUN apt-get update && apt-get install -y \
    clang \
    lld \
    llvm \
    libc++-dev \
    libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

# Build lcov 1.15
RUN cd /tmp && git clone https://github.com/linux-test-project/lcov.git && cd /tmp/lcov && git checkout v1.15 && make install || true

# Build libmicrohttpd 0.9.73
RUN cd /tmp && wget -q https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.73.tar.gz && tar xzf libmicrohttpd-0.9.73.tar.gz && rm libmicrohttpd-0.9.73.tar.gz
RUN cd /tmp/libmicrohttpd-0.9.73 && ./configure --disable-https && make -j$(nproc) && make install

# Build opus 1.3.1
RUN cd /tmp && wget -q https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz && tar xzf opus-1.3.1.tar.gz && rm opus-1.3.1.tar.gz
RUN cd /tmp/opus-1.3.1 && ./configure && make -j$(nproc) && make install

# Minimal extra packages for build
RUN apt-get -y update && apt-get -y install python3 lsb-release ca-certificates && rm -rf /var/lib/apt/lists/*

ARG SMB_VERSION=2.4.0-617
WORKDIR /build
RUN git clone --branch ${SMB_VERSION} https://github.com/finos/SymphonyMediaBridge.git SMB

WORKDIR /build/SMB

# Disable googletest fetch/build (upstream fetch in CMake)
RUN sed -i '/ExternalProject_Add(googletest/,/)/s/^/#/' CMakeLists.txt || true
RUN sed -i '/add_subdirectory(${CMAKE_BINARY_DIR}\/googletest-src)/s/^/#/' CMakeLists.txt || true

# Build SMB with clang/clang++ and libc++ (project expects clang + libc++)
RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
      -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
      -DBUILD_SHARED_LIBS=ON \
      -DSMB_BUILD_TESTS=OFF \
      -DBUILD_TESTING=OFF && \
    make -j$(nproc)

FROM ubuntu:22.04 AS runtime
RUN apt-get -y update && apt-get -y install --no-install-recommends \
    libc++1 \
    libc++abi1 \
    ca-certificates \
    iptables \
    iputils-ping \
    libsrtp2-1 \
    libmicrohttpd12 \
    libopus0 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/SMB/build/smb /usr/local/bin/smb
COPY smb-config.json /config.json

EXPOSE 8080 8081
EXPOSE 10000/udp
EXPOSE 10006-26000/udp

ENTRYPOINT ["/usr/local/bin/smb", "/config.json"]
