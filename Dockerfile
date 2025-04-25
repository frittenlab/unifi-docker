FROM golang:1.22-bullseye as permset
WORKDIR /src
RUN git clone https://github.com/jacobalberty/permset.git /src && \
    mkdir -p /out && \
    go build -ldflags "-X main.chownDir=/unifi" -o /out/permset

FROM ubuntu:22.04 AS base

# arm64-specific stage
FROM base AS build-arm64
COPY docker-build-arm64.sh /usr/local/bin/docker-build.sh 

# amd64-specific stage
FROM base AS build-amd64
COPY docker-build-amd64.sh /usr/local/bin/docker-build.sh 

FROM build-${TARGETARCH} AS build

ARG DEBIAN_FRONTEND=noninteractive

ARG PKGURL=https://dl.ui.com/unifi/9.1.119/unifi_sysvinit_all.deb

ENV BASEDIR=/usr/lib/unifi \
    DATADIR=/unifi/data \
    LOGDIR=/unifi/log \
    CERTDIR=/unifi/cert \
    RUNDIR=/unifi/run \
    ORUNDIR=/var/run/unifi \
    ODATADIR=/var/lib/unifi \
    OLOGDIR=/var/log/unifi \
    CERTNAME=cert.pem \
    CERT_PRIVATE_NAME=privkey.pem \
    CERT_IS_CHAIN=false \
    GOSU_VERSION=1.10 \
    BIND_PRIV=true \
    RUNAS_UID0=true \
    UNIFI_GID=999 \
    UNIFI_UID=999

RUN set -eux; \
	apt-get update; \
	apt-get install -y gosu; \
	rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/unifi \
     /usr/local/unifi/init.d \
     /usr/unifi/init.d \
     /usr/local/docker
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-healthcheck.sh /usr/local/bin/
COPY functions /usr/unifi/functions
COPY import_cert /usr/unifi/init.d/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/unifi/init.d/import_cert \
 && chmod +x /usr/local/bin/docker-healthcheck.sh \
 && chmod +x /usr/local/bin/docker-build.sh 

RUN set -ex \
 && mkdir -p /usr/share/man/man1/ \
 && groupadd -r unifi -g $UNIFI_GID \
 && useradd --no-log-init -r -u $UNIFI_UID -g $UNIFI_GID unifi \
 && /usr/local/bin/docker-build.sh "${PKGURL}"

COPY --from=permset /out/permset /usr/local/bin/permset
RUN chown 0.0 /usr/local/bin/permset && \
    chmod +s /usr/local/bin/permset

RUN mkdir -p /unifi && chown unifi:unifi -R /unifi

VOLUME ["/unifi", "${RUNDIR}"]

EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp 10001/udp

WORKDIR /unifi

HEALTHCHECK --start-period=5m CMD /usr/local/bin/docker-healthcheck.sh || exit 1

# execute controller using JSVC like original debian package does
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["unifi"]
