ARG UBUNTU_VER=24.04

FROM ubuntu:${UBUNTU_VER} AS builder

ARG OPENVPN_VERSION="2.6.12"

WORKDIR /

RUN set -eu \
    && apt-get update && \
    apt-get install -y \
    curl \
    unzip \
    build-essential \
    autoconf \
    libgnutls28-dev \
    libgnutls28-dev \
    liblzo2-dev \
    libpam0g-dev \
    libtool \
    libssl-dev \
    net-tools \
    pkg-config \
    libnl-genl-3-dev \
    libcap-ng-dev \
    liblz4-dev

RUN curl -L https://github.com/OpenVPN/openvpn/archive/v${OPENVPN_VERSION}.zip -o openvpn.zip && \
    unzip openvpn.zip && \
    mv openvpn-${OPENVPN_VERSION} openvpn

COPY openvpn-v${OPENVPN_VERSION}-aws.patch openvpn

RUN cd openvpn && \
    patch -p1 < openvpn-v${OPENVPN_VERSION}-aws.patch && \
    autoreconf -i -v -f && \
    ./configure && \
    make

FROM golang:1.23 AS gobuilder

COPY server.go .

RUN CGO_ENABLED=0 go build server.go

FROM ubuntu:${UBUNTU_VER}

ENV TZ="America/Sao_Paulo"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y \
    dnsutils \
    liblzo2-dev \
    libnl-genl-3-200 \
    liblz4-1 \
    libcap-ng0 \
    openssl \
    net-tools \
    iproute2 iputils-ping iptables curl

COPY --from=builder /openvpn/src/openvpn/openvpn /openvpn
COPY --from=gobuilder /go/server /server
COPY entrypoint.sh /

COPY update-resolv-conf /etc/openvpn/scripts/

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
