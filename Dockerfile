# =========================
# 1️⃣ Build stage
# =========================
FROM ubuntu:24.04 AS builder

ARG SMB_VERSION=2.4.0-617
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    cmake \
    git \
    curl \
    pkg-config \
    libssl-dev \
    libsrtp2-dev \
    libopus-dev \
    libmicrohttpd-dev \
    libc++-dev \
    libc++abi-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -L \
  https://github.com/finos/SymphonyMediaBridge/archive/refs/tags/${SMB_VERSION}.tar.gz \
  | tar xz --strip-components=1

RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
    && make -j$(nproc)

# =========================
# 2️⃣ Runtime stage
# =========================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libssl3 \
    libsrtp2-1 \
    libopus0 \
    libmicrohttpd12 \
    libcap2-bin \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy smb binary
COPY --from=builder /build/build/smb /usr/local/bin/smb

# Allow realtime priority
RUN setcap CAP_SYS_NICE+ep /usr/local/bin/smb

WORKDIR /

# Empty default config
RUN echo "{}" > /config.json

EXPOSE 8080 8081
EXPOSE 10000/udp
EXPOSE 10006-26000/udp

ENTRYPOINT ["smb", "/config.json"]

