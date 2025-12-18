FROM ubuntu:20.04

ARG SMB_VERSION=2.1.0-266
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    iptables \
    iputils-ping \
    curl \
    libcap2-bin \
    libssl1.1 \
    libc++-dev \
    libc++abi-dev \
    libsrtp2-1 \
    libmicrohttpd12 \
    libopus0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L \
  https://github.com/finos/SymphonyMediaBridge/releases/download/${SMB_VERSION}/finos-rtc-smb_${SMB_VERSION}.deb \
  -o /tmp/smb.deb \
  && dpkg -i /tmp/smb.deb \
  && rm /tmp/smb.deb

COPY smb-config.json /config.json

EXPOSE 8081 8080
EXPOSE 10000/udp
EXPOSE 10006-26000/udp

ENTRYPOINT ["smb", "/config.json"]
